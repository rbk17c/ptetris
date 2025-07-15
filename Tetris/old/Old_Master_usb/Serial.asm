	NOLIST
; vim:syntax=pic
; Serial code

; Manual:
;
; #DEFINE _SerOut	PORTA,3         ; To RS232
; #DEFINE _SerIn	PORTA,4         ; To RS232
;
; speed:
; 1 Mhz / 115200 = 8.680555 uS ( inst )
; 1 byte=10      =86.805555 uS ( inst )

#ifndef SER_Start
SER_Start=0
#endif

	NOLIST
SER_Input MACRO ; {
	btfsc   _SerIn
	rcall	K_SEM_GetC
	ENDM ; }

#IF SER_Start == 0 ; {
K_SEM_PutC=K_Return
K_SEM_GetC=K_Return
#ELSE ; } {
	ORG SER_Start
	LIST
#IFNDEF _SerOut ; {
	#DEFINE _SerOut	PORTA,3         ; To RS232
#ENDIF ; }

#IFNDEF _SerIn ; {
	#DEFINE _SerIn	PORTA,4         ; To RS232
#ENDIF ; }

;----------------------------------------------------------------------------*
K_SEM_PutC ; uses W
;----------------------------------------------------------------------------*
;
; startbit			
	bcf	_SerOut		; 0		; mark
	rcall	sleep7

; bit0
	btfsc	WREG, 0
	bsf	_SerOut		; 0 + 9 = 9	; ( 8.68) mark
	rcall	sleep5

; bit1
	btfsc	WREG, 1
	bsf	_SerOut
	btfss	WREG, 1		; 9 + 8 = 17	; (17.36) mark
	bcf	_SerOut
	rcall	sleep5
; bit2
	btfsc	WREG, 2
	bsf	_SerOut
	btfss	WREG, 2		;17 + 9 = 26	; (26.04) mark
	bcf	_SerOut
	rcall	sleep5
; bit3
	btfsc	WREG, 3
	bsf	_SerOut
	btfss	WREG, 3		;26 + 9 = 35	; (34.72) mark
	bcf	_SerOut
	rcall	sleep4
; bit4
	btfsc	WREG, 4
	bsf	_SerOut
	btfss	WREG, 4		;35 + 8 = 43	; (43.40) mark
	bcf	_SerOut
	rcall	sleep5
; bit5
	btfsc	WREG, 5
	bsf	_SerOut
	btfss	WREG, 5		;43 + 9 = 52	; (52.08) mark
	bcf	_SerOut
	rcall	sleep5
; bit6
	btfsc	WREG, 6
	bsf	_SerOut
	btfss	WREG, 6		;52 + 9 = 61	; (60.76) mark
	bcf	_SerOut
	rcall	sleep4
; bit7
	btfsc	WREG, 7
	bsf	_SerOut
	btfss	WREG, 7		;61 + 8 = 69	; (69.44) mark
	bcf	_SerOut
	rcall	sleep6
	
; stop
	bsf	_SerOut		;69 + 9 = 78	; (78.12) mark
	rcall	sleep4
 
sleep7	nop			;
sleep6	nop
sleep5	nop			;78 + 7 = 85    ; (86.80) mark
sleep4	return			; all done
sleep8	bra	sleep6

;----------------------------------------------------------------------------*
SerIn				; ~528 cy
;----------------------------------------------------------------------------*
; mainloop=5	
; at best, we get called within 1, worst  6
; call				3	- 8
;			bit	;     s   0   1   2   3   4   5   6   7   e
;			TIMING	;	9 + 8 + 9 + 9 + 8 + 9 + 9 + 8 + 9 + (9)  = 87 cy= 87uS
;
			; cy - 2 - 8	; this is the middle of s
	clrw				; 4		; mark S
	rcall	sleep6


	btfsc	_SerIn	;		;  4 + 9 = 13	; mark (0)
	bsf	WREG, 0
	rcall	sleep7

	btfsc	_SerIn	;		; 13 + 9 = 22	; mark
	bsf	WREG, 1			
	rcall	sleep6

	btfsc	_SerIn	;		; 22 + 8 = 30	; mark
	bsf	WREG, 2
	rcall	sleep7

	btfsc	_SerIn	;		; 30 + 9 = 39	; mark
	bsf	WREG, 3
	rcall	sleep7

	btfsc	_SerIn	;		; 39 + 9 = 48	; mark
	bsf	WREG, 4
	rcall	sleep6

	btfsc	_SerIn	;		; 48 + 8 = 56	; mark
	bsf	WREG, 5
	rcall	sleep7

	btfsc	_SerIn	;		; 56 + 9 = 65	; mark
	bsf	WREG, 6
	rcall	sleep7

	btfsc	_SerIn	;		; 65 + 9 = 74	; mark (7)
	bsf	WREG, 7
					; end TODO check?

	;clrf	Error_count		; disable sleep, for a time
	;decf	Error_count, f		; disable sleep, for a time

	return

; SerIn_process=SerOut
; 
; #ifdef K_Input
; SerIn_process=K_Input
; #endif
; 
; #ifdef M_Input
; SerIn_process=M_Input
; #endif
; 
; 	bra	SerIn_process
; 
#endif ; } SER_START
	LIST
