;Each time we use RS, E it is replaced by its pin number
RS BIT P1.2
E  BIT P1.3
lcd_port EQU P2


LCD_INIT		EQU 38H
LCD_DISPLAY_CURSOR 	EQU 0EH
LCD_CLEAR 		EQU 01H 


ORG 0

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

JMP $

; Is a routine that write a command on the LCD
; To use it you have to move the command code first to lcd_port register "mov lcd_port, #CMD" before calling it
LCD_CMD:
	CLR RS		;RS = 0 for writing COMMANDS on lcd
	SETB E		;E = 1 to start sending signal to lcd
	ACALL DELAY	;There must be delay between SET E and CLR E
	CLR E
	RET
	
; Is a routine that character on the LCD
; To use it you have to move the character first to lcd_port register "mov lcd_port, #'a' " before calling it
LCD_DISPLAY_CHAR:
	SETB RS		;RS = 1 for writing DATA on lcd
	SETB E		;E = 1 to start sending signal to lcd
	ACALL DELAY	;There must be delay between SET E and CLR E		
	CLR E
	RET



LCD_DISPLAY_STRING:
	
	MOV DPTR, #STRING_HELLO	;MOVE address of String to DPTR
REPEAT_STRING:
	CLR A			;clear A
	MOVC A, @A+DPTR 	;A <- data on address( A + DPTR )
	MOV lcd_port, A		
	ACALL LCD_DISPLAY_CHAR
	INC DPTR		;INC DPTR to get next character in the string
	JNZ CONTINUE_STRING 	;jump if character not equal 0
	RET
CONTINUE_STRING:
	JMP REPEAT_STRING
DELAY:
    	MOV R0, #3
Y:	MOV R1, #255
	DJNZ R1, $
	DJNZ R0, Y

	RET


;Store string on address 300H
ORG 300H
STRING_HELLO:	DB	"HELLO" ,0 ;STRING AND NULL

END