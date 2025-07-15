	NOLIST
; vim:syntax=pic
; Serial code

; Manual:
;
; #DEFINE _SerOut	PORTA,3         ; To RS232
; #DEFINE _SerIn	PORTA,4         ; To RS232
;
; speed 4 mhz:
; 1 Mhz / 115200 = 8.680555 inst ( 8.68 uS )
; 1 byte=10      =86.805555 uS ( inst )

; speed 8 mhz
; 2 Mhz / 115200 = 17,36 inst   ( 8.68 uS)
;

#ifndef SER_Start
SER_Start=0
#endif

	NOLIST
SER_Input MACRO ; {
	btfss   _SerIn
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
; 2 Mhz / 115200 = 17,36 inst   ( 8.68 uS)
; startbit			
	bcf	_SerOut		; 0		; mark
	rcall	sleep16

; bit0
	btfsc	WREG, 0
	bsf	_SerOut		; 00 + 17 	; ( 8.68 - 8.5 = +.18 uS) 
	rcall	sleep14

; bit1
	btfsc	WREG, 1
	bsf	_SerOut
	btfss	WREG, 1
	bcf	_SerOut		; 17 + 18 = 35	; (17.36 - 17.5 = -.14 uS)
	rcall	sleep13
; bit2
	btfsc	WREG, 2
	bsf	_SerOut
	btfss	WREG, 2
	bcf	_SerOut		; 35 + 17 = 52	; (26.04 - 26.0 = +.04 uS)
	rcall	sleep13
; bit3
	btfsc	WREG, 3
	bsf	_SerOut
	btfss	WREG, 3
	bcf	_SerOut		; 52 + 17 = 69	; (34.72 - 34.5 = +.22 uS)
	rcall	sleep14
; bit4
	btfsc	WREG, 4
	bsf	_SerOut
	btfss	WREG, 4
	bcf	_SerOut		; 69 + 18 = 87	; (43.40 - 43.5 = + .10 uS)
	rcall	sleep13
; bit5
	btfsc	WREG, 5
	bsf	_SerOut
	btfss	WREG, 5
	bcf	_SerOut		; 87 + 17 = 104	; (52.08 - 52.0 = + .08 uS)
	rcall	sleep14
; bit6
	btfsc	WREG, 6
	bsf	_SerOut
	btfss	WREG, 6
	bcf	_SerOut		; 104 + 18 = 122 ; (60.76 - 62.0 = -.24 uS )
	rcall	sleep13
; bit7
	btfsc	WREG, 7
	bsf	_SerOut
	btfss	WREG, 7
	bcf	_SerOut		; 122 + 17 = 139 ; (69.44 - 69.5 = -.06 uS )
	rcall	sleep16
	
; stop
	bsf	_SerOut		; 139 + 17 = 156 ; (78.13 - 78.0 = +.13 uS)
	bra	sleep15

sleep17	nop
sleep16	nop
sleep15	nop
sleep14	nop
sleep13	nop
sleep12	rcall	sleep4
sleep7	rcall	sleep4
sleep4	return			; all done




;----------------------------------------------------------------------------*
K_SEM_GetC ; uses W
;----------------------------------------------------------------------------*
; mainloop=5	
; at best, we get called within 1, worst  6
; call				3	- 8
;			bit	;     s   0   1   2   3   4   5   6   7   e
;			TIMING	;	9 + 8 + 9 + 9 + 8 + 9 + 9 + 8 + 9 + (9)  = 87 cy= 87uS
;					; cy - 2 - 8	; this is the middle of s
; timeing 8 mhz:

; 2 Mhz / 115200 = 17,36 inst   ( 8.68 uS)

;	nr	bit	perfect 8mhz 	sum	time	offset	cy float
;	0	S	4.34	18	9.00	4.50	-0.16 	8.68
;	1	0	13.02	17	26.00	13.00	0.02  	26.04
;	2	1	21.70	17	43.00	21.50	0.20  	43.40
;	3	2	30.38	18	61.00	30.50	-0.12 	60.76
;	4	3	39.06	17	78.00	39.00	0.06  	78.13
;	5	4	47.74	17	95.00	47.50	0.24  	95.49
;	6	5	56.42	18	113.00	56.50	-0.08 	112.85
;	7	6	65.10	17	130.00	65.00	0.10  	130.21
;	8	7	73.78	18	148.00	74.00	-0.22 	147.57
;	9	E	82.47	17	165.00	82.50	-0.03 	164.93
;	10	P	91.15	17	182.00	91.00	0.15  	182.29

	

	; btfss + call...		; 3 cy


	clrw				;
	rcall	sleep14			; no need to read start bit

	btfsc	_SerIn	;		; 3 + 19  = 26
	bsf	WREG, 0
	rcall	sleep16

	btfsc	_SerIn
	bsf	WREG, 1			; 26 + 17 = 43		
	rcall	sleep17

	btfsc	_SerIn
	bsf	WREG, 2			; 43 + 18 = 61
	rcall	sleep16

	btfsc	_SerIn
	bsf	WREG, 3			; 61 + 17 = 78
	rcall	sleep16

	btfsc	_SerIn
	bsf	WREG, 4			; 78 + 17 = 95
	rcall	sleep16

	btfsc	_SerIn
	bsf	WREG, 5			; 95 + 18 = 113
	rcall	sleep16

	btfsc	_SerIn
	bsf	WREG, 6			; 113 + 17 = 130
	rcall	sleep17

	btfsc	_SerIn
	bsf	WREG, 7			; 130 + 17 = 148

	bra	M_Input
; 
#endif ; } SER_START
	LIST
