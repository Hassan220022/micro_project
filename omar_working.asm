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
    
    
; Timer delay function for approximately 30 microseconds
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
    
    
    ; Microcontroller send request function
REQUEST:
    CLR P1.0            ; DHT11 = 0 (set to low pin)
    CALL TIMER_DELAY20MS ; Wait for 20ms
    SETB P1.0            ; DHT11 = 1 (set to high pin)

    RET                 ; Return from the function	
    
    
; Receive response from DHT11 function
RESPONSE:
    JB P1.0,$  ; Wait while DHT11 is high
    JNB P1.0,$  ; Wait while DHT11 is low
    JB P1.0,$  ; Wait while DHT11 is high

    RET 


Receive_data:
    MOV R1, #0 ; Initialize loop counter q to 0
    MOV R2, #0 ; Initialize c to 0

ReceiveLoop:
   ; JB P1.0, $
    JNB P1.0, $ ; Wait for DHT11 to become high (start of bit)

    ; Delay for 30us
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
    ;JB P1.0, $ ; Wait for DHT11 to become low (end of bit)
    CJNE R1, #8, ReceiveLoop ; If q is not equal to 8, repeat the loop
    ;JB P1.0, $ ; Wait for DHT11 to become low (end of bit)

    MOV A, R2 ; Load c into the accumulator
    RET ; Return with the result in the accumulator
    
    
BITCALL:    
    
        SETB EA
    CALL Request ; Send start pulse
    CALL Response ; Receive response

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
    
    MOV A, R3   ; Move the value of R3 to accumulator A
    ANL A, #01   ; Perform bitwise AND with 1 to check the least significant bit
    JZ Even      ; Jump to Even if the result is zero (LSB is 0)
    MOV A, R2
    RR A
    ; Odd case code here
    JMP EndI     ; Skip the Even case code
    Even:
   ; Even case code here
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
    RET



Main:
    CALL BITCALL


PWM:

    MOV TMOD, #00010000B	;Run Timer 1 one 16-bit mode
    SETB ET1
    SETB EA
    
    CLR P1.1

    MOV TH1, #0FFH
    MOV TL1, #0FEH

    SETB TR1		;Run timer	

    JMP $


TIM1_ISR:
   CALL BITCALL
   
   
   
   

   MOV A, R5   ; Move the value of R5 to the accumulator A
   CJNE A, #25, NotEqual   ; Compare A with the immediate value 25, jump to NotGreaterThan if not equal
   ; Code to execute if R5 is greater than 25
   CALL TIM1_ISR_LOW
   RETI
   NotEqual:
   JNC NotGreaterThan
   CALL TIM1_ISR_LOW
   RETI
   NotGreaterThan:
   ; Code to execute if R5 is not greater than 25
   CALL TIM1_ISR_HIGH
   RETI
   
    
    
    
    
TIM1_ISR_HIGH:
	
    CLR TR1		;STOP timer 1 from counting
    CLR TF1		;CLEAR timer overflow flag
	
    ;JB P1.1, LOW_LEVEL
    MOV TH1, #0H
    MOV TL1, #0H
    SETB P1.1

	
    SETB TR1
    RET
	
	
;LOW_LEVEL:
    ;MOV TH1, #0FEH
    ;MOV TL1, #32H
    ;CLR P1.1


    ;SETB TR1
    ;RET

TIM1_ISR_LOW:
	
    CLR TR1		;STOP timer 1 from counting
    CLR TF1		;CLEAR timer overflow flag
	
    JB P1.1, LOW_LEVEL2
    MOV TH1, #0FEH
    MOV TL1, #32H
    SETB P1.1

	
    SETB TR1
    RET
	
	
LOW_LEVEL2:
    MOV TH1, #00H
    MOV TL1, #99H
    CLR P1.1


    SETB TR1
    RET

    ; End of program
    SJMP $
    END