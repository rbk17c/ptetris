; vim:syntax=pic18 autowrite
; %bP96bPF6bP8CbPFEbP96bPF6bP8CbPFEbP96bPF6bP8CbPFE

;
; Slave1
;   i2c: E0 - set TRIS=out write LATA,LATB,LATC +  sum
;   i2c: E1 - set TRIS=in  read PORTA,PORTB,PORTC + sum
;   E0&E1 respect PWM mode lines ( read=0, write=ignore )
;   i2c: E2 - write pwmcfg,pwn1,pwn2 +  sum
;     CFG: 
;      7 - extra bits  pwm0 bit 0
;      6 - extra bits  pwm0 bit 1
;      5 - extra bits  pwm1 bit 0
;      4 - extra bits  pwm1 bit 1
;      3 - speed >PR7
;      2 - speed >PR6
;      1 - pwm2 on/off
;      0 - pwn1 on/off
;   i2c: E3 read pwmcfg,pwn1,pwn2, + sum ( useless! )
;slavek22
;   i2c: E4 - set TRIS=out write LATA,LATC +  sum		<<< NOT PORTB
;   i2c: E5 - set TRIS=in  read PORTA,PORTC + sum		<<< NOT PORTB
;
;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	list	w=0, n=9999, p=18F26k22, r=hex

	CONFIG	FOSC	= INTIO67
	;CONFIG	FOSC	= HSMP	; ext, fast xtal
	CONFIG	PLLCFG	= OFF
	CONFIG	BOREN	= OFF
	CONFIG	PWRTEN	= ON
	CONFIG	WDTEN	= OFF
	;CONFIG	XINST	= ON
	ASSUME	0x0400

; -----------------------------------------------------------------------
;noul='0'; macro fix
;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
; Vars:
;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
VBANK0=0x000
;VBANK1=0x100
;VBANK2=0x200
;VBANK3=0x300
VBANK4=0x400
	cblock 	VBANK0
	Debugv
	DebugW
	PV_wait0
	PV_wait1
	PV_wait2
	blkc
	mled_on
	mled_off
	ws_tmp


	pwm_mode
	i2c_addr
	i2c_sum
	i2c_io
	i2c_put
	i2c_data1
	;i2c_data2
	i2c_data3
	i2c_data4
	I2C_wait
	i2c_stat
	ROM_MASK_C_and

	main_last_var
	endc
VBANK0=main_last_var

#define _mblink		Debugv, 1
ROM_MASK_A_read=b'11111111'
ROM_MASK_B_read=b'11111111'
ROM_MASK_C_read=b'11111111'
ROM_MASK_A_write=b'11111111'
ROM_MASK_B_write=b'11111111'
ROM_MASK_C_write=b'11111111'
ROM_MASK_A=b'11111111'
ROM_MASK_B=b'11111111'
ROM_MASK_C=b'11111111'

DEBUG=1			; include debug code (lots!)
MON_Pchar=a'%'

FREQ=.32000000
SEM_SPEED=.115200
Enable_Monitor=0x0580
RESTORE_INTCON=b'11000000'
ws_red=b'00000100'	; ( ws_red * 3 ) + ( ws_boost * 3 )
ws_blue=b'00010000'
ws_green=b'00000001'	; All can be X3, e.g.:
ws_boost=b'01000000'
;Enable_SEM=0x7B0
;
	include "p18f26k22.inc"
	include "asmdef18.inc"
	include "Hardware.inc"
	include "Monitor.asm"
Enable_SEM=MONIOR_END
	include "Sem.asm"
#define _i2c_if		PIR3, SSP2IF

;
; TMR0 - blink
;
;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
_Reset	org	0x0000
;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	bra	Init
	bra	Init
	bra	Init
	bra	Init
;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
_IRQL	org	0x0008		; bcf	RCON, IPEN		; NO use high & low prio irq
;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	btfsc	PIR1, TMR2IF
	bcf	PIR1, TMR2IF
	retfie	FAST
;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
;_IRQH	org	0x0018
;	retfie	FAST
;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
;
;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Init
;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
		; 7___3210	;	intosc=8mhz
	lfsr	2, 0x00
		; icccsSCC
	movlw	b'01010000'	; FREQ  4   X 4ppl = 16mhz
	movlw	b'01100000'	; FREQ  8   X 4ppl = 32mhz
	;movlw	b'01110000'	; FREQ 16   X 4ppl = 64mhz
	movwf	OSCCON
	BANKSEL	OSCTUNE
	bsf	OSCTUNE, PLLEN, BANKED	; freqX4

	clrf	Debugv
	BANKSEL	ANSELA
	clrf	ANSELA
	clrf	ANSELB
	clrf	ANSELC

	movlw	TRIS_FOR_A
	movwf	TRISA
	movlw	TRIS_FOR_B
	movwf	TRISB
	movwf	WPUB		; pullup for ps/2, MCLR ans serIO
	bcf	INTCON2, NOT_RBPU
	movlw	TRIS_FOR_C
	movwf	TRISC
	clrf	LATA
	clrf	LATB
	clrf	LATC

	rcall	K_SEM_Init
	rcall	K_MON_Init
	rcall	I2m_Init

	movlw	b'10000010'	; on, PSA=2;T0CON used for USB
	movwf	T0CON		; each= 1/((4mips*10^6 ) / 2^16bit timer /2 psa) = .02621440


	BANKSEL	KV_MON_atH
	movlw	high (LATB)
	movwf	KV_MON_atH, BANKED
	movlw	low (LATB)
	movwf	KV_MON_atL, BANKED

	movlw	0x01
	movwf	blkc
	movlw	ws_green*1
	movwf	mled_on
	movlw	ws_blue*1
	movwf	mled_off

	clrf	PV_wait0
	clrf	PV_wait1
	clrf	PV_wait2
	bcf	_DEBUG

	;movlw	RESTORE_INTCON
	;movwf	INTCON
	;bsf	PIE1, TMR2IF

	;+bra	MainLoop
;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
MainLoop
;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
;i2c
	btfsc	_i2c_if
	rcall	I2mirq
; keyboard
	rcall	SEM_getc
	btfss	_C
	rcall	M_Input
; blink
	btfss	INTCON, TMR0IF	
	bra	MainLoop

	bcf	INTCON, TMR0IF		; ~18ms - 55hz
	decfsz	blkc, f
	bra	MainLoop
	movlw	0x08
	movwf	blkc

	rcall	Blink2
	bra	MainLoop

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
Blink2
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	btg	_mblink
	movf	mled_on, w
	btfss	_mblink
	movf	mled_off, w
	bra	ws_8bitcol	; IIrrbbgg

;------------------------------------------------------------------------------------------;
;    Multicol LED
;
ws_8bitcol	; IIbbrrgg
;------------------------------------------------------------------------------------------;
	movwf	ws_tmp
	andlw	0x03
	rcall	ws_shift	; green
	rrncf	ws_tmp, w	; red
	rrncf	WREG, w
	andlw	0x03
	rcall	ws_shift
	swapf	ws_tmp, w	; blue
	andlw	0x03
ws_shift
	btfsc	ws_tmp, 6
	rlncf	WREG, f
	btfsc	ws_tmp, 6
	rlncf	WREG, f
	btfsc	ws_tmp, 7
	swapf	WREG, f
	bcf	INTCON, GIE
	rcall	ws_bit
	rcall	ws_bit
	rcall	ws_bit
	rcall	ws_bit
	rcall	ws_bit
	rcall	ws_bit
	rcall	ws_bit
	rcall	ws_bit
	bsf	INTCON, GIE
	return

if FREQ==.16000000
ws_bit	rlcf	WREG, f		; 16mhz
	btfsc	_C		; tick = (1/(16000000/4))*10^9 = 250ns
	bra	ws_bit1
ws_bit0	bsfl	Mled	
	bcfl	Mled
	return
ws_bit1	bsfl	Mled
	nop
	nop
	bcfl	Mled
	return
elif FREQ==.32000000
ws_bit	rlcf	WREG, f		; 32mhz
	btfsc	_C		; tick = (1/(32000000/4))*10^9 = 125ns
	bra	ws_bit1
ws_bit0	bsfl	Mled	
	nop
	bcfl	Mled
	return
ws_bit1	bsfl	Mled
	bra	$+2
	bra	$+2
	bcfl	Mled
	return
endif

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
M_Input	BANKSEL	MON_A1
	movwf	MON_A1, BANKED
	rcall	K_PrintW
	;TODO btgl	LED_GRN
;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	movf	MON_A1, w, BANKED
	sublw	a'.'
	bz	MonI_dot	; am_mouse +X

	movf	MON_A1, w, BANKED
	sublw	a','
	bz	MonI_com	; am_mouse +X
;
; Rest wants "arguments"
;
	;movf	MON_A1, w, BANKED
	;btfss	KB_gotnum
	;bra	K_decod

	bra	K_decod	
;
;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
;
MonI_dot
	DEBUG_VAR 'N', KV_MON_readnum
	banksel	KV_MON_readnum
	movf	KV_MON_readnum, w, BANKED
	bra	PrintP

MonI_com
	DEBUG_VAR 'N', KV_MON_readnum
	banksel	KV_MON_readnum
	movf	KV_MON_readnum, w, BANKED
	bra	PrintP

;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
; I2m ( i2c Module )
;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

I2m_NAK				; master send NAK - dont want more data
	DEBUG_C	'!'
	return

I2m_reboot
	DEBUG_2C 'R', 'B'
	DEBUG_VAR 'C', SSP2CON1
	movf	SSP2BUF, w		; bcf BF
	clrf	SSP2CON1
	clrf	SSP2CON2

I2m_Init
	; only one address bsf	SSP2MSK, MSK1	; two addresses, mask 36-37 & 38-39
	movlw	0x26		; 7bit i2cslave w.o. IRQ on start/stop - dont hold
	;movlw	0x3E		; 7bit i2cslave WITH IRQ on start/stop - dont hold
	movwf	SSP2CON1	; enable + i2c-7bit +irq
	bsf	SSP2CON2, SEN	; use clock stretching
	bcf	SSP2MSK, MSK1	; two addresses, mask E4-E5,e6-E7
	movlw	0xE4
	movwf	SSP2ADD		; my addr
	clrf	i2c_stat
	return

;-----------------------------------------

DEBUG_I2mirq
	rcall	PrintNl
	movlw	'I'
	rcall	PrintW
	movlw	':'
	rcall	PrintW
	movf	SSP2STAT, w
	rcall	K_PrintBit
	movlw	'-'
	rcall	PrintW
	movlw	'C'
	btfss	SSP2CON1, CKP
	movlw	'c'
	rcall	PrintW
	movlw	'O'
	btfss	SSP2CON1, SSPOV
	movlw	'o'
	bra	PrintW

;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
I2m_stoped				; not start wont happen, unless spurius IRQ
	movf	SSP2BUF, w		; clr BF
	bcf	SSP2CON1, SSPOV		; clr overflow
MRETURN	return

;----------------------------------------------------------------------------------------------------
I2mirq		; I2C - service
;----------------------------------------------------------------------------------------------------
	bcf	_i2c_if

	btfss	SSP2STAT, S		; NOT s
	bra	I2m_stoped	; !S wont happen, unless spurius IRQ

	DEBUG_N

	;btfsc	SSP2CON1, CKP
	;bra	I2m_Start		; master not waiting

	btfsc	SSP2STAT, R_NOT_W
	bra	I2m_read
	;+bra	i2m_write

;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
i2m_write				; TRANSMIT from master ( I need to read... )
;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	btfsc	SSP2STAT, D_NOT_A	; 
	bra	I2m_write_data		; got data

;;;;;;;;;;;;;;;;
I2mw_adr
;;;;;;;;;;;;;;;;
	movf	SSP2BUF, w		; clr BF
	bsf	SSP2CON1, CKP		; release clock - ready to send
	;movwf	i2c_addr
	clrf	i2c_sum	
	clrf	i2c_stat
	DEBUG_CH '{'
	return

;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
I2m_write_data				; from master to me
;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	movf	SSP2BUF, w
	bsf	SSP2CON1, CKP		; release clock - ready to send
	movwf	i2c_io
	DEBUG_CH	'<'		; TODO test WCOL / SSPOV - needed?

	movf	i2c_stat, w
	bz	I2m_Transmit1	; LATA
	decf	WREG, f
	bz	I2m_Transmit3	; LATC
	decf	WREG, f
	bz	I2m_Transmit4
Ireturn	return				; ignore all further writes from master

I2m_Transmit1
	movf	i2c_io, w
	movwf	i2c_data1
	bra	I2m_wr2
I2m_Transmit3
	movf	i2c_io, w
	movwf	i2c_data3
	;+bra	I2m_wr2
I2m_wr2 addwf	i2c_sum, f
	incf	i2c_stat, f	
	return

I2m_Transmit4				; cheksum
	incf	i2c_stat, f
	movf	i2c_io, w
	movwf	i2c_data4
	subwf	i2c_sum, w
	bz	i2mw_sum_fine
	;+bra	i2c_sum_error

;-----------------------------------------------------------------------------------------
I2c_sum_error
;-----------------------------------------------------------------------------------------
	DEBUG_2C	's', 'f'
	movf	i2c_data1, w
	DEBUG_CH '+'
	movf	i2c_data3, w
	DEBUG_CH '+'
	movf	i2c_sum, w
	DEBUG_CH '='
	movf	i2c_data4, w
	DEBUG_CH '!'
	DEBUG_N
	return

;-----------------------------------------------------------------------------------------
i2mw_sum_fine
;-----------------------------------------------------------------------------------------
Port_write_set
	DEBUG_2C	'P', '+'
	movf	i2c_data1, w
	movwf	LATA
		;xorwf	LATA, w
		;andlw	ROM_MASK_A
		;xorwf	LATA, f
		;movlw	ROM_MASK_A_write

		;movf	i2c_data2, w
		;xorwf	LATB, w
		;andlw	ROM_MASK_B
		;xorwf	LATB, f
		;movlw	ROM_MASK_B_write
		;movwf	TRISB

	movf	i2c_data3, w
		;xorwf	LATC, w
		;andlw	ROM_MASK_C
		;xorwf	LATC, f
		;movlw	ROM_MASK_C_write
		;andwf	ROM_MASK_C_and, w	; pwm in use?
		;movwf	TRISC
	movwf	LATC
	clrf	TRISA
	clrf	TRISC
	DEBUG_N
	return

;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
I2m_read
;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	btfsc	SSP2STAT, D_NOT_A	; 
	bra	I2m_read_data
;;;;;;;;;;;;;;;;
I2mr_adr
;;;;;;;;;;;;;;;;
	movf	SSP2BUF, w		; clr BF
	movwf	i2c_addr
	clrf	i2c_sum			; check sum
	clrf	i2c_stat
	DEBUG_CH '['
	;+bra	I2m_read_data

;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
I2m_read_data
;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	btfsc	SSP2CON2, ACKSTAT
	bra	I2m_NAK				; master send NAK - dont want more data
	
	btfsc	i2c_addr, 1	; E5: 1110-0101 - E7: 1110-0111
	bra	I2m_Recive_E7

I2m_Recive_E5
	movf	i2c_stat, w
	bz	I2m_recive1		; portA
	decf	WREG, f
	bz	I2m_recive3		; portC
	decf	WREG, f
	bz	I2m_recive4		; ci2c_sum
	movlw	0x55			; if master keeps reading...
	bra	I2m_putC

I2m_recive1
	btfsc	TRISA, 0		; is output?
	bra	I2m_recive1a
	setf	TRISA			; set input
	setf	TRISC
	DEBUG_2C 'A','I'
	waitUS	.10
I2m_recive1a
	movf	PORTA, w
	;incf	i2c_put, f
	;movf	i2c_put, w
	bra	I2m_putC
I2m_recive3
	movf	PORTC, w
	;incf	i2c_put, f
	;movf	i2c_put, w
	bra	I2m_putC
I2m_recive4
	movf	i2c_sum, w
	;+bra	I2m_putC

;;;;;;;;;;;;,,
I2m_putC
;;;;;;;;;;;;,,
	movwf	SSP2BUF
	bsf	SSP2CON1, CKP		; release clock - ready to send
	addwf	i2c_sum, f
	incf	i2c_stat, f
	DEBUG_C	'>'
	DEBUG_H				; TODO test WCOL / SSPOV - needed?
	return

I2m_Recive_E7		
	DEBUG_2C 'A','i'
	setf	TRISA			; set input
	setf	TRISC			; set input
	movlw	0xff			; enables master to do STOP
	;bsf	SSP2CON1, CKP		; release clock - ready to send
	;return
	bra	I2m_putC

;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	END
;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
