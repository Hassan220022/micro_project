; Each time we use RS, E, it is replaced by its pin number
RS      BIT P1.2
E       BIT P1.3
lcd_port EQU P2

; Store string on address 300H
ORG 300H
STRING_screen:  DB " TEMP =", 0 ; Updated label for temperature display

LCD_INIT                EQU 38H
LCD_DISPLAY_CURSOR      EQU 0EH
LCD_CLEAR               EQU 01H






;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;lcd functions 



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
    MOV R0, #3
Y:  MOV R4, #255
    DJNZ R4, $
    DJNZ R0, Y
    RET

CONVERT_AND_DISPLAY:
    MOV A, R5            ; Move the received value to A
    ANL A, #0F0H         ; Mask lower 4 bits to get the first character
    SWAP A               ; Swap nibbles to bring the first character to lower 4 bits
    ADD A, #30H          ; Convert to ASCII
    MOV lcd_port, A      ; Display the ASCII character
    ACALL LCD_DISPLAY_CHAR

    MOV A, R5            ; Move the received value to A again
    ANL A, #0FH          ; Mask upper 4 bits to get the second character
    ADD A, #30H          ; Convert to ASCII
    MOV lcd_port, A      ; Display the ASCII character
    ACALL LCD_DISPLAY_CHAR
    RET
    
LCD:
    CLR RS
    CLR E
    MOV lcd_port, #0

    MOV lcd_port, #LCD_INIT
    CALL LCD_CMD

    MOV lcd_port, #LCD_DISPLAY_CURSOR
    CALL LCD_CMD

    MOV lcd_port, #LCD_CLEAR
    CALL LCD_CMD

    MOV lcd_port, #'a'
    CALL LCD_DISPLAY_CHAR


    CALL LCD_DISPLAY_STRING
    CALL CONVERT_AND_DISPLAY

    RET

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;



