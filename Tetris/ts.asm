; vim:syntax=pic18

;;;;;;;;;;;;;;;;;;;;; ;;;;;;;;;;;;;;;;;;;; ;;;;;;;;;;;;;;;;;;;; ;;;;;;;;;;;;;;;;;;;;
;
; make i2c to 16x8 matrix
;
;;;;;;;;;;;;;;;;;;;;; ;;;;;;;;;;;;;;;;;;;; ;;;;;;;;;;;;;;;;;;;; ;;;;;;;;;;;;;;;;;;;;
;
;	TODO:
; DONE- * change MaX_update to rr
; DONE- * Change MaX_ MAT_... to do TLB * 3 
; 
; Done- * better MaX_clear
; * move stuff to Add_to_Display...
; 
; * use irq
; *  with on/off..
; 
; * I2C_slave
;
; * Blink	return
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
		timr1
		tmp1
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
DEBUG_I2CS=1
#include "Appl.inc"
#include "Hardware.inc"
#include "asmdef18.inc"
#include "Serial.asm"
#include "Monitor_18f2320.asm"
#include "i2c_slave.asm"
#define ROW_IRQ	INTCON, TMR0IF
PrintW=K_SEM_PutC

	org	0x0000
	bra	init
	bra	init
	fill	0xffff,4
	org	0x0008
	bcf	ROW_IRQ
	nop	;btgl	_RC3
	rcall	MaY_next
	retfie	FAST
	;fill	0xffff,2
	org	0x0010
	;bra	low_interrupt	; go to start of high priority interrupt code
	retfie

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
	movwf	T0CON		; 3: psa on, /8 each ~2000 cy ( 256*8 )

		 ;76pp3210
	movlw	b'00000001'	; TMR1CS1 TMR1CS0 T1CKPS1 T1CKPS0 T1OSCEN  T1SYNC RD16 TMR1ON
	movwf	T1CON		; 16bit, ps=8, int src, on   = ( @4mhz) 10^6 / 65536 = 15hz
	; not used...


	movlw	0x01
	movwf	timr1

	BANKSEL	VBANK1
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

	bcf	_Main_on
	bsf	_DEBUG

	;rcall	I2CS_Init
	; INIT I2C 166
	;TRISC<4:3> input
	;movwf	SSPCON1		; C6
	;movwf	SSPCON2		; C5
	;movwf	SSPSTAT		; C7
	;movwf	SSPBUF		; C9
	;movwf	SSPSR
	;movwf	SSPADD		; C8

	rcall	DISP_Init


		 ;76543210
	movlw	b'10100000'	; GIE,  TMR0IE
	btfss	_Main_on
	movlw	b'00100000'	; GIE,  TMR0IE
	movwf	INTCON

	rcall	I2CS_reboot

main
	btfsc	_i2c_if
	call	I2CS_irq		; I2C - service
	;SER_Input
	;btgl	_RC4

	btfsc   _SerIn
	bra	main
	bcf	INTCON, GIE
	rcall	K_SEM_GetC

	btfsc	_Main_on
	bsf	INTCON, GIE
	bra	main

;sMain	bcf	ROW_IRQ		; ---| mid loop ( each 2000cy) |---
;	btfss	_Main_on
;	bra	MaY_next
;	return


	

	org	0x0200
MY_line	MY_LINE		; Macro to install MA_y scancodes
	wait_for_it	; install wait code


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




;+++++++++++++++++++++++++++++++++++++++++++++++
;	display
;+++++++++++++++++++++++++++++++++++++++++++++++
	cblock	0x0080
		Display0:0x10
		;Display1:0x20
	endc
	cblock	VBANK0
		SR_dat
		i2c_dat1:2
		SR_ROW
		A_pos
		B_pos
		P_pos
		last_disp_b0
	endc
VBANK0=last_disp_b0

DISP_Init
Mon_xT
	movlw	HIGH(SR_ROW)
	movwf	KV_MON_atH, BANKED
	movlw	LOW (SR_ROW)
	movwf	KV_MON_atL, BANKED

	rcall	Load_Demo_Display
	LFSR	0, Display0
	movlw	high(MY_line)
	movwf	TBLPTRH
	setf	SR_ROW

	movlw	0x01
	rcall	SR_setW

	return;bra	MaX_Update

;++++++++++++++++++++++++++++++++
;	shift register 
;++++++++++++++++++++++++++++++++
SR_setW	movwf	SR_dat
SR_set	bcfl	_SR_load	; load down
	movlw	0x08		; 8 bits
	movwf	tmp1
SR_l01	bcfl	_SR_clk		; CLK down

	rlcf	SR_dat, f	
	btfsc	_C
	bsfl	_SR_dat		; set or clr dat
	btfss	_C		; keeps noise down
	bcfl	_SR_dat

	bsfl	_SR_clk		; CLK up
	decfsz	tmp1, f
	bra	SR_l01

	bsfl	_SR_load	; load up

	bcfl	_SR_dat
	return



Mon_xj	return
Mon_xJ	; Clear display
	movlw	.24		; clear displat
	movwf	tmp1
	LFSR	0, Display0

Xj1	CLRF	POSTINC0
	decfsz	tmp1, f
	bra	Xj1
	return


Mon_xI
Load_Demo_Display
	movlw	high(char_A)
	movwf	TBLPTRH
	movlw	low(char_A)
	movwf	A_pos
	
	movlw	low(char_B)
	movwf	B_pos

	clrf	P_pos

	movlw	0x08
	movwf	tmp1

Sab_l01
	movlw	high(char_A)
	movwf	TBLPTRH
; a
	movf	A_pos, w
	movwf	TBLPTRL
	TBLRD*
	movf	TABLAT, w
	movwf	i2c_dat1+1
	incf	A_pos, f
; b
	movf	B_pos, w
	movwf	TBLPTRL
	TBLRD*
	movf	TABLAT, w
	movwf	i2c_dat1+0
	incf	B_pos, f
; - ab loaded

;
; most of this needs to go to Add_to_Display...
;
	LFSR	0, Display0
	movlw	high(MY_line)		; map to right line * 3
	movwf	TBLPTRH
	movlw	low (MY_line)		; find offset
	addwf	P_pos, w		; for the curent line ( P_pos)
	movwf	TBLPTRL
	incf	P_pos, f
	TBLRD*
	movf	TABLAT, w
	addwf	FSR0L, f		; add offset...
	rcall	Add_to_Display

	decfsz	tmp1, f
	bra	Sab_l01
	return



Add_to_Display





Add_to_FSR
	DAT_MAT		; moves i2c_dat1 into 3 FSR0s
	return





Mon_xi	rlcf	i2c_dat1, w	; just load _C from low
	rlcf	i2c_dat1+1, F	; rotate high, using low _C
	rlcf	i2c_dat1, F	; rotate low, final
	;+bra	Mon_xI
	

Mon_xt
IRQ_disp		; 30-33 cy + rcall + return
MaY_next		; update_y - ver3 ( fast... )			; TODO clear SR / turn off X

MaX_clear
	movf	LATA, w
	andlw	MAT_MASK_A
	xorwf	LATA, f
	movf	LATB, w
	andlw	MAT_MASK_B
	xorwf	LATB, f
	movf	LATC, w
	andlw	MAT_MASK_C
	xorwf	LATC, f

; Advance Y
	bcfl	_SR_load	; load down
	bcfl	_SR_clk		; CLK down

	incf	SR_ROW, f
	btfss	SR_ROW, 3	; SR >7?
	bra	SR_null		; shift a zero

SR_reset
	bsfl	_SR_dat		; Shift a one
	clrf	SR_ROW
	LFSR	0, Display0

SR_null	bsfl	_SR_clk		; CLK up
	bcfl	_SR_dat		; DAT to off
	bsfl	_SR_load	; load up

MaX_Update
	movf	POSTINC0, w
	xorwf	LATA, w
	andlw	MAT_MASK_A
	xorwf	LATA, f

	movf	POSTINC0, w
	xorwf	LATB, w
	andlw	MAT_MASK_B
	xorwf	LATB, f
	
	movf	POSTINC0, w
	xorwf	LATC, w
	andlw	MAT_MASK_C
	xorwf	LATC, f

	return
 
rMon_go
	btg	_Main_on

	movlw	b'10100000'	; GIE,  TMR0IE
	btfss	_Main_on
	movlw	b'00100000'	; GIE,  TMR0IE
	movwf	INTCON


	movf	LATA, w
	andlw	MAT_MASK_A
	xorwf	LATA, f
	movf	LATB, w
	andlw	MAT_MASK_B
	xorwf	LATB, f
	movf	LATC, w
	andlw	MAT_MASK_C
	xorwf	LATC, f

	return
 
	org	0x0f00
#include "abc.asm"




	END
