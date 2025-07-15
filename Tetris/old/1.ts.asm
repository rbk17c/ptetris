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

main
	SER_Input


	;btfsc	_i2c_if
	;rcall	I2CS_irq		; I2C - service

	;btfsc	ROW_IRQ
	;rcall	sMain
	bra	main

sMain	bcf	ROW_IRQ		; ---| slow loop ( each 65536cy) |---
	decfsz	timr1, f
	bra	main
 
	btfss	_Main_on
	bra	main

	;rcall	DISP_update_x


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
		last_disp_b0
	endc
VBANK0=last_disp_b0

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

Mon_xt
	movlw	a'r'
	rcall	K_PrintW
	movf	SR_ROW, W
	rcall	K_PrintHex


MaY_next
	incf	SR_ROW, f	
	btfsc	SR_ROW, 3
	clrf	SR_ROW
	movf	SR_ROW ,w	; addlw low(MZ_line), unless 
	movwf	TBLPTRL		; low(MZ_line) is 0
	;+bra	MaY_setpos


MaY_setpos
	;movf	TBLPTRL, w
	rcall	K_PrintHex
	movlw	'='
	rcall	K_PrintW

	TBLRD*
	movf	TABLAT, w
	rcall	K_PrintHex
	rcall	K_PrintNl
	
	movf	TABLAT, w
	;+bra	SR_setW


;+++++++++++++++++++++++++++++++++++++++++++++++
; shift register
;+++++++++++++++++++++++++++++++++++++++++++++++
SR_setW	movwf	SR_dat

SR_set	movlw	0x08		; 8 bits
	movwf	tmp1

SRloop1
	bcfl	_SR_clk		; CLK down

	btfsc	SR_dat, 0
	bsfl	_SR_dat		; set or clr dat
	btfss	SR_dat, 0
	bcfl	_SR_dat

	rlncf	SR_dat, f	
	bsfl	_SR_clk		; CLK up
	decfsz	tmp1, f
	bra	SRloop1

	bcfl	_SR_load	; load down
	nop
	bsfl	_SR_load	; load up
	return



Mon_xi
	rlcf	i2c_dat1, w	; just load _C from low
	rlcf	i2c_dat1+1, F	; rotate high, using low _C
	rlcf	i2c_dat1, F	; rotate low, final
	;+bra	Mon_xI
	

Mon_xI
DISP_update_x
	LFSR	0, Display0
	DAT_MAT
	LFSR	0, Display0

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

;	org	0x0f00
;#include "abc.asm"




	END
