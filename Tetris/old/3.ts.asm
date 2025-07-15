; vim:syntax=pic18

;;;;;;;;;;;;;;;;;;;;; ;;;;;;;;;;;;;;;;;;;; ;;;;;;;;;;;;;;;;;;;; ;;;;;;;;;;;;;;;;;;;;
;
; make i2c to 16x8 matrix
;
;;;;;;;;;;;;;;;;;;;;; ;;;;;;;;;;;;;;;;;;;; ;;;;;;;;;;;;;;;;;;;; ;;;;;;;;;;;;;;;;;;;;

; check A: rows
;  b:
;   8A=C0  - all low
;   93=80  - all output

;  a:
;   89=C3  - ff
;   scan 92


; 89 LATA 
; 8A LATB
;
; 92 TRISA
; 93 TRISB
;
; FD - off   1101
; f5 - on    0101
;  A:         low=Dis R   rrcc.ccrr
;                         1100.0011 c3
; FE 1110    0    row 5+
; FD 1101    1    row 7+
; FB 1011    2        x ?
; F7 0111    3    col 3-

; EF 1110    4        x ?
; DF 1101    5    col 5-
; BF 1011    6    row 3+
; 7F 0111    7    row 6+
;
;  B:         hi=Dis R
; BE 1110    0       x 
; BD 1101    1        x
; BB 1011    2        x
; B7 0111    3       x 

; 9F 1110    4  
; AF 1101    5  
;-
; BF 1011    6
; 7F 0111    7
;
;
	list	w=0, n=9999, p=18F2320
	radix	hex
	errorlevel -1302
	errorlevel -302
	errorlevel -1301

#define _i2c_if		PIR1, SSPIF
DEBUG=1
VBANK0=0x000
VBANK1=0x100
	cblock	VBANK0
		Debugv
		DebugW
		m_bits
 		HV_wait0
 		HV_wait1
 		HV_wait2
		timr1R
		timr1
		tmp1
		SR_ROW
		last_main_b0
	endc
VBANK0=last_main_b0

#define	_Main_on	m_bits, 4

SER_Start=0x700
#DEFINE _SerOut	LATB, 6		; To   RS232
#DEFINE _SerIn	PORTB, 7	; from RS232
MON_Start=0x400
I2CS_Start=0x800

BootCode=1
#include "Appl.inc"
#include "Hardware.inc"
#include "asmdef18.inc"
#include "Serial.asm"
#include "Monitor_18f2320.asm"
;#include "i2c_slave.asm"
PrintW=K_SEM_PutC

	org	0x0000
	bra	init
	bra	init
	fill	0xffff,4
	org	0x0008
    	;bra    high_interrupt       ; go to start of high priority interrupt code
	return;retfie
	fill	0xffff,6
	org	0x0010
    	;bra    low_interrupt       ; go to start of high priority interrupt code
	return;retfie

MRETURN	org	0x0012
K_Return return

init	org	0x0014
	L_init				; local chip init, macro in *.hw
	bsf	_SerOut
	clrf	HV_wait0
	clrf	HV_wait1
	clrf	HV_wait2
	clrf	SR_ROW
	bsf	SR_ROW, 0


	#ifdef	K_MON_Init
	rcall	K_MON_Init
	#endif ;K_MON_Init

		 ;76543210
	movlw	b'11000001'	; on, 8bit, 0=int osc, na
	movwf	T0CON		; 3: psa on, /4

		 ;76pp3210
	movlw	b'00000001'	; TMR1CS1 TMR1CS0 T1CKPS1 T1CKPS0 T1OSCEN  T1SYNC RD16 TMR1ON
	movwf	T1CON		; 16bit, ps=8, int src, on   = ( @4mhz) 10^6 / 65536 = 15hz
	; not used...


	movlw	0x01
	movwf	timr1
	movlw	0x10
	movwf	timr1R



	;rcall	DISP_Init

	BANKSEL	VBANK1

	clrf	INTCON
	waitMS	.150
	movlw	'R'
	rcall	PrintW
	movlw	'e'
	rcall	PrintW
	movlw	's'
	rcall	PrintW
	movlw	'e'
	rcall	PrintW
	movlw	't'
	rcall	PrintW
	rcall	K_PrintNl

	bsf	_Main_on

	bcf	_DEBUG
	;rcall	I2CS_Init

	; INIT I2C 166

	;TRISC<4:3> input
	;movwf	SSPCON1		; C6
	;movwf	SSPCON2		; C5
	;movwf	SSPSTAT		; C7
	;movwf	SSPBUF		; C9
	;movwf	SSPSR
	;movwf	SSPADD		; C8


#define ROW_IRQ	INTCON, TMR0IF

	rcall	Mon_xT
	rcall	Mon_xJ

main
	SER_Input


	;btfsc	_i2c_if
	;rcall	I2CS_irq		; I2C - service

	;btfsc	ROW_IRQ
	;rcall	sMain
	;bra	main

sMain	bcf	ROW_IRQ		; ---| slow loop ( each 65536cy) |---
	decfsz	timr1, f
	bra	main
 
	btfss	_Main_on
	bra	main

	rcall	MaY_next				; TODO clear SR / turn off X


	movlw	0xf0
	movwf	timr1
	bra	main

	org	0x0200
MZ_line	MZ_LINE		; Macro to install MA_y scancodes
	wait_for_it			; install wait code


SwitchCaseX4
	rlncf	WREG, w	; w * 2
SwitchCaseX2
	rlncf	WREG, w	; w * 2
SwitchCase
	rlncf	WREG, w	; w * 2
	addwf	TOSL, f
	movlw	0
	addwfc	TOSH, f
	addwfc	TOSU, f	; for >64K bytes memory
	return	; "returns" to where TOS points now...

Blink	return



;+++++++++++++++++++++++++++++++++++++++++++++++
;  display
;+++++++++++++++++++++++++++++++++++++++++++++++

	cblock	0x0080
		Display0:0x40
		Display1:0x40
	endc

	cblock	VBANK0
		SR_dat
		i2c_dat1:2
		tmp2
		last_disp_b0
	endc
VBANK0=last_disp_b0

;char_A: de 0x18, 0x3C, 0x66, 0x7E, 0x66, 0x66, 0x66, 0x00
;	|+...XX...+|
;	|+..XXXX..+|
;	|+.XX..XX.+|
;	|+.XXXXXX.+|
;	|+.XX..XX.+|
;	|+.XX..XX.+|
;	|+.XX..XX.+|
;	|+........+|

;char_B: de 0x7C, 0x66, 0x66, 0x7C, 0x66, 0x66, 0x7C, 0x00
;	|+.XXXXX..+|
;	|+.XX..XX.+|
;	|+.XX..XX.+|
;	|+.XXXXX..+|
;	|+.XX..XX.+|
;	|+.XX..XX.+|
;	|+.XXXXX..+|
;	|+........+|
Mon_xJ	; copy AB...

	LFSR	0, Display0-1


	;clrf	TBLPTRU
	movlw	high(char_A)
	movwf	TBLPTRH
	movlw	low(char_A)
	movwf	TBLPTRL

	movlw	0x08
	movwf	tmp1
xJ_loop
	TBLRD*+
	movf	TABLAT, w
	movwf	i2c_dat1+0
	movwf	i2c_dat1+1

	rcall	Add_to_FSR

	decfsz	tmp1, f
	bra	xJ_loop

	LFSR	0, Display0
	rcall	MaX_Update

	movlw	high(MZ_line)
	movwf	TBLPTRH
	return

Add_to_FSR
	DAT_MAT
	return

Mon_xj
Mon_xt
MaY_next				; TODO clear SR / turn off X
	incf	SR_ROW, f	
	movf	SR_ROW, w	; addlw low(MZ_line), unless 
	andlw	0x07
	movwf	TBLPTRL		; low(MZ_line) is 0

	TBLRD*
; *** shift register ***
	bcfl	_SR_load	; load down
	movlw	0x08		; 8 bits
	movwf	tmp1
SR_l01	bcfl	_SR_clk		; CLK down

	rlcf	TABLAT, f	
	btfsc	_C
	bsfl	_SR_dat		; set or clr dat
	btfss	_C		; keeps noise down
	bcfl	_SR_dat

	bsfl	_SR_clk		; CLK up
	decfsz	tmp1, f
	bra	SR_l01

	bsfl	_SR_load	; load up


;MaX_Update
        movf    POSTINC0, w
        xorwf   LATA, w
        andlw   MAT_MASK_A
        xorwf   LATA, f

        movf    POSTINC0, w
        xorwf   LATB, w
        andlw   MAT_MASK_B
        xorwf   LATB, f

        movf    POSTINC0, w
        xorwf   LATC, w
        andlw   MAT_MASK_C
        xorwf   LATC, f

        movlw	0x96
	cpfsgt	FSR0L
	return
; reset SR:
	LFSR	0, Display0
	setf	SR_ROW
	
	return



Mon_xT
	movlw	HIGH(SR_ROW)
	movwf	KV_MON_atH, BANKED
	movlw	LOW (SR_ROW)
	movwf	KV_MON_atL, BANKED

_LINE=b'0000000000000001'
	movlw	low(_LINE)
	movwf	i2c_dat1
	movlw	high(_LINE)
	movwf	i2c_dat1+1
	rcall	Mon_xi

MaY_init
	movlw	high(MZ_line)
	movwf	TBLPTRH
	setf	SR_ROW

	bra	MaY_next



Mon_xi	rlcf	i2c_dat1, w	; just load _C from low
	rlcf	i2c_dat1+1, F	; rotate high, using low _C
	rlcf	i2c_dat1, F	; rotate low, final
	;+bra	Mon_xI
	

Mon_xI
	LFSR	0, Display0-1
	rcall	Add_to_FSR
	LFSR	0, Display0

MaX_Update
        movf    POSTINC0, w
        xorwf   LATA, w
        andlw   MAT_MASK_A
        xorwf   LATA, f

        movf    POSTINC0, w
        xorwf   LATB, w
        andlw   MAT_MASK_B
        xorwf   LATB, f

        movf    POSTINC0, w
        xorwf   LATC, w
        andlw   MAT_MASK_C
        xorwf   LATC, f

	return




;DISP_Init
;	LFSR	0, Display0
;	movlw	0x80
;	movwf	Disp_line
;
;dis_i1	clrf	POSTINC0
;	decfsz	Disp_line, f
;	bra	dis_i1
;
;	movlw	0x80
;	movwf	Display0
;
;	;clrf	Disp_line	 ; is already 0: 
;
;	return
;

	org	0x0f00
#include "abc.asm"




	END
