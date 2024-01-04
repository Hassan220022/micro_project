; Each time we use RS, E, it is replaced by its pin number
RS      BIT P1.2
E       BIT P1.3
lcd_port        EQU P2

; Store string on address 300H
ORG 300H
STRING_screen:  DB " TEMP =", 0 ; Updated label for temperature display

LCD_INIT                EQU 38H
LCD_DISPLAY_CURSOR      EQU 0EH
LCD_CLEAR               EQU 01H

ORG 0
JMP Main

ORG 001BH
JMP TIM1_ISR

; Timer delay function
TIMER_DELAY20MS:
    MOV TMOD, #01H      ; Set Timer 0 in mode 1 (16-bit mode with auto-reload)
    MOV TH0, #0B8H      ; Load higher 8 bits in TH0
    MOV TL0, #000H      ; Load lower 8 bits in TL0
    SETB TR0            ; Start Timer 0

WAIT_LOOP:
    JNB TF0, WAIT_LOOP  ; Wait until TF0 flag is set
    CLR TR0            ; Stop Timer 0
    CLR TF0            ; Clear TF0 flag
    RET                ; Return from the function

LCD_CMD:
    CLR RS             ; RS = 0 for writing COMMANDS on LCD
    SETB E             ; E = 1 to start sending signal to LCD
    ACALL DELAY        ; There must be a delay between SET E and CLR E
    CLR E
    RET

LCD_DISPLAY_CHAR:
    SETB RS            ; RS = 1 for writing DATA on LCD
    SETB E             ; E = 1 to start sending signal to LCD
    ACALL DELAY        ; There must be a delay between SET E and CLR E
    CLR E
    RET

LCD_DISPLAY_STRING:
    MOV DPTR, #STRING_screen  ; MOVE address of String to DPTR

REPEAT_STRING:
    CLR A                   ; clear A
    MOVC A, @A+DPTR         ; A <- data on address( A + DPTR )
    MOV lcd_port, A
    ACALL LCD_DISPLAY_CHAR
    INC DPTR                ; INC DPTR to get the next character in the string
    JNZ CONTINUE_STRING     ; Jump if the character is not equal to 0
    RET
CONTINUE_STRING:
    JMP REPEAT_STRING

DELAY:
    MOV R7, #3
Y:  MOV R4, #255
    DJNZ R4, $
    DJNZ R7, Y
    RET

TIMER_DELAY30US:
    MOV TMOD, #01H      ; Set Timer 0 in mode 1 (16-bit mode with auto-reload)
    MOV TH0, #0FFH      ; Load higher 8 bits in TH0
    MOV TL0, #0D5H      ; Load lower 8 bits in TL0
    SETB TR0            ; Start Timer 0

WAIT_LOOP2:
    JNB TF0, WAIT_LOOP2  ; Wait until TF0 flag is set
    CLR TR0            ; Stop Timer 0
    CLR TF0            ; Clear TF0 flag
    RET                ; Return from the function

CONVERT_AND_DISPLAY:
    MOV R6, #10          ; R6 is a divisor to extract digits
    MOV R5, A            ; Move the received value to A
    MOV R7, #0           ; Initialize a counter for the number of digits

CONVERT_LOOP:
    MOV A, R5           ; Move the value of R5 to A
    DIV AB              ; Divide A by B, quotient in A, remainder in B
    PUSH ACC            ; Push the remainder onto the stack
    INC R7              ; Increment the digit counter
    ; MOV R5, A           ; Update R5 with the quotient

DISPLAY_LOOP:
    POP ACC             ; Pop the top digit from the stack
    ADD A, #30H         ; Convert remainder to ASCII
    JZ SKIP_ZERO        ; Skip if the character is '0'
    MOV lcd_port, A     ; Display the ASCII character
    ACALL LCD_DISPLAY_CHAR
SKIP_ZERO:
    DJNZ R7, DISPLAY_LOOP ; Continue until all digits have been displayed
    RET


REQUEST:
    CLR P1.0            ; DHT11 = 0 (set to a low pin)
    CALL TIMER_DELAY20MS ; Wait for 20ms
    SETB P1.0            ; DHT11 = 1 (set to a high pin)
    RET                 ; Return from the function

RESPONSE:
    JB P1.0, $  ; Wait while DHT11 is high
    JNB P1.0, $  ; Wait while DHT11 is low
    JB P1.0, $  ; Wait while DHT11 is high
    RET

Receive_data:
    MOV R1, #0  ; Initialize loop counter q to 0
    MOV R2, #0  ; Initialize c to 0

ReceiveLoop:
    JNB P1.0, $ ; Wait for DHT11 to become high (start of bit)
    CALL TIMER_DELAY30US
    JB P1.0, HighPulse ; If DHT11 is still high, jump to HighPulse

    ; If DHT11 is low, it's a logic LOW
    MOV A, R2 ; Load c into the accumulator
    RL A ; Rotate the bits left (c << 1)
    MOV R2, A ; Store the result back in c
    JMP NextBit ; Jump to NextBit

HighPulse:
    MOV A, R2 ; Load c into the accumulator
    RL A ; Rotate the bits left (c << 1) before ORing
    ORL A, #001H ; OR the result with hexadecimal value 0x01
    MOV R2, A ; Store the result back in c

NextBit:
    INC R1 ; Increment q
    CJNE R1, #8, ReceiveLoop ; If q is not equal to 8, repeat the loop

    MOV A, R2 ; Load c into the accumulator
    RET ; Return with the result in the accumulator

BITCALL:
    SETB EA
    CALL REQUEST ; Send a start pulse
    CALL RESPONSE ; Receive response

    ; Store first eight bits in I_RH
    CALL Receive_data
    MOV R3, A

    ; Store next eight bits in D_RH
    JB P1.0, $
    CALL Receive_data
    MOV R4, A

    ; Store next eight bits in I_Temp
    JB P1.0, $
    CALL Receive_data
    MOV A, R3   ; Move the value of R3 to the accumulator A
    ANL A, #01   ; Perform bitwise AND with 1 to check the least significant bit
    JZ Even      ; Jump to Even if the result is zero (LSB is 0)
    MOV A, R2
    RR A
    JMP EndI     ; Skip the Even case code

Even:
    MOV A, R2
    RR A
    RR A

EndI:
    MOV R5, A

    ; Store next eight bits in D_Temp
    JB P1.0, $
    CALL Receive_data
    MOV R6, A

    ; Store next eight bits in CheckSum
    JB P1.0, $
    CALL Receive_data
    MOV R7, A

    ; Debug: Print received values to LCD
    MOV lcd_port, #LCD_CLEAR
    CALL LCD_CMD

    ; Display temperature label
    MOV DPTR, #STRING_screen
    CALL LCD_DISPLAY_STRING

    ; Display temperature value
    MOV A, R5   ; Move the received value to A
    CALL CONVERT_AND_DISPLAY
    ; Repeat the CONVERT_AND_DISPLAY for R6, R7, or any other received data

    RET

Main:
    ; Initialize LCD
    MOV lcd_port, #LCD_INIT
    ACALL LCD_CMD
    MOV lcd_port, #LCD_DISPLAY_CURSOR
    ACALL LCD_CMD
    MOV lcd_port, #LCD_CLEAR
    ACALL LCD_CMD

    ; Main loop
MAIN_LOOP:
    ; Request data from DHT11 sensor
    ACALL BITCALL

    ; Display temperature label
    MOV DPTR, #STRING_screen
    ACALL LCD_DISPLAY_STRING

    ; Display temperature value
    MOV A, R5   ; Move the received value to A
    ACALL CONVERT_AND_DISPLAY

    ; Delay before next update
    ACALL TIMER_DELAY20MS

    ; Repeat the loop
    SJMP MAIN_LOOP

PWM:
    MOV TMOD, #00010000B ; Run Timer 1 in 16-bit mode
    SETB ET1
    SETB EA
    CLR P1.1
    MOV TH1, #0FFH
    MOV TL1, #0FEH
    SETB TR1            ; Run timer
    JMP $

TIM1_ISR:
    CALL BITCALL
    MOV A, R5
    CJNE A, #25, NotEqual ; Compare A with the immediate value 25
    CALL TIM1_ISR_LOW
    RETI
NotEqual:
    JNC NotGreaterThan
    CALL TIM1_ISR_LOW
    RETI
NotGreaterThan:
    CALL TIM1_ISR_HIGH
    RETI

TIM1_ISR_HIGH:
    CLR TR1             ; STOP timer 1 from counting
    CLR TF1             ; CLEAR timer overflow flag
    JB P1.1, LOW_LEVEL2
    MOV TH1, #0H
    MOV TL1, #0H
    SETB P1.1
    SETB TR1
    RET

LOW_LEVEL2:
    MOV TH1, #0FEH
    MOV TL1, #32H
    CLR P1.1
    SETB TR1
    RET

TIM1_ISR_LOW:
    CLR TR1             ; STOP timer 1 from counting
    CLR TF1             ; CLEAR timer overflow flag
    JB P1.1, LOW_LEVEL2
    MOV TH1, #0FEH
    MOV TL1, #32H
    SETB P1.1
    SETB TR1
    RET

SJMP $

END
