; vim:syntax=pic18 autowrite
; copyright GPLv2
;
; V1.1 IO
;   i2c: E0 - set TRIS=out write LATA,LATB,LATC +  sum
;   i2c: E1 - set TRIS=in  read PORTA,PORTB,PORTC + sum
; V2.0 add pwm
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
;
; Improvement : store last state in eeprom ( in/out/pwm/speed/duty... )
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;               Hardware Version 1.1
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;
;		   Pic18F2321:
;
;              mclr 1+.--+28 RB7 - IO 
;       IO   - RA0  2|   |27 RB6 - IO 
;       IO   - RA1  3|   |26 RB5 - IO 
;       IO   - RA2  4|   |25 RB4 - IO 
;       IO   - RA3  5|   |25 RB3 - IO 
;        OC  - RA4  6|   |25 RB2 - IO 
;       IO   - RA5  7|   |22 RB1 - IO 
;  (GND)     - VSS  8|   |21 RB0 - IO 
;       Xtal - RA7  9|   |20 Vdd -	(+5V)
;       Xtal - RA6 10|   |19 Vss -	(GND)
;       IO   - RC0 11|   |18 RC7 - IO 
; PWM2 /IO   - RC1 12|   |17 RC6 - IO 
; PWM1 /IO   - RC2 13|   |16 RC5 - IO 
;       Sdx  - RC3 14+---+15 RC4 - SDx
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Key a-f hex

;  (xx) l- look
;  (xx) L- Set high look bank
;   xx  p- push xx
;	z-hexdump 16b
;	Z-hexdump +16b
;  ctrl-z-hexdump -16b
;	+-inc yyyy
;	--inc yyyy
;	v- toggle verbose
;
;	R - reset
;	Y- queue len ( STK pointer)
;	G-
;	q- ( off )
;	R-reset
;-
;	s-status
;	i-?
;
;
; DEBUG=1
#ifdef DEBUG
SER_Start=0x0400 ; ~058h
MON_Start=0x0490 ; ~194h
#else
SER_Start=0
MON_Start=0
#endif

MonStartAt=SSPCON2
MON_Pchar=a':'
BootCode=1
;#define RESTORE_INTCON	b'11000000'
#define RESTORE_INTCON	b'00000000'
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	list	w=0, n=9999, p=18F2321
	errorlevel -302
	radix	hex
        include "p18f2321.inc"
        include "hardware.inc"
        include "asmdef18.inc"
        include "Serial.asm"
        include "Monitor18_save.asm"


cblock VBANK0
	pwm_mode
	i2c_addr
	i2c_sum
	i2c_data1
	i2c_data2
	i2c_data3
	i2c_data4
	I2C_wait
	i2c_stat
	i2c_io
	ROM_MASK_C_and
	M_var_last
endc
VBANK0=M_var_last

;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
; Start:
;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	org	0x0000
	bra	Init
	fill 	0xffff, 6
	org	0x0008
	retfie
	fill 	0xffff, 0x0e
	org	0x0018
	retfie
	fill 	0xffff, 6
;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
; init:
;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Init	
	org	0x20
	L_init

	clrf	PV_wait0
	clrf	PV_wait1
	clrf	PV_wait2
	setf	ROM_MASK_C_and

	movlw	0xff
	movwf	PR2
	clrf	CCPR1L	
	clrf	CCPR2L	
	clrf	CCP1CON	
	clrf	CCP2CON	
		; 76543210
	movlw	b'00000100' ; no scalars - go as fast as possible
	movwf	T2CON

	bsf	_DEBUG			; TODO
	rcall	K_MON_Init
	movlw	'r'
	rcall	PrintW

; init i2c:
	rcall	I2m_Init

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
MLoop
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	banksel 0x00

#ifdef	DEBUG
	btfss	_SerIn
	rcall	SerIn		; + K_input best sync we can do ... NO TIME!
#endif
	btfsc	PIR1, SSPIF
	rcall	I2mirq
	bra	MLoop

K_Return
MRETURN	return
;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
M_Input
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	movwf	MON_A1

	movf	MON_A1, w
	sublw	a'G'
	bz	Init

	movf	MON_A1, w
	sublw	a'i'
	bz	MonI_i		; start

	movf	MON_A1, w
	sublw	a'j'
	btfsc	_Z
	bra	MonI_j		; send A1

	movf	MON_A1, w
	sublw	a'r'
	btfsc	_Z
	bra	MonI_r		; got ,r -read i2c

	movf	MON_A1, w
	sublw	a'h'
	btfsc	_Z
	bra	MonI_h		; got ,h

;
; Rest wants "arguments"
;
;	btfss	KB_gotnum
;	bra	M_inp2		; so make sure we got some
;	movf	MON_A1, w
;	sublw	a'n'
;	btfsc	_Z
;	bra	MonI_h		; got ARG,w

	movf	MON_A1, w
M_inp2	bra	K_Input2

;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
MonI_r	goto	K_PrintP
MonI_i	bsf	_DEBUG
	DEBUG_C '~'
	movf	SSPSTAT, w
	DEBUG_CH ':'
	movlw	'C'
	btfss	SSPCON1, CKP
	movlw	'c'
	rcall	PrintW
	bcf	_DEBUG
	return

MonI_h	bsf	_DEBUG
	btfsc	KB_gotnum
	bra	pushbuf
	DEBUG_C	'B'
	movf	SSPBUF, w
	DEBUG_CH	':'
	bcf	_DEBUG
	bcf	_DEBUG
	goto	K_PrintP

pushbuf	bcf	KB_gotnum
	movf	KV_MON_readnum, w
	movwf	SSPBUF
	DEBUG_C '<'
	bcf	_DEBUG
	goto	K_PrintP

MonI_j
	DEBUG_2C 'o','f'
	DEBUG_C 'f'
	btg	_DEBUG
	DEBUG_2C 'o','n'
	goto	K_PrintP

;####################################################################################################
;  I2m slave
;####################################################################################################

I2m_NAK				; master send NAK - dont want more data
	bsf	SSPCON1, CKP	; release clock - ready to send
	DEBUG_C	'!'
	return

I2m_reboot
	DEBUG_2C 'R', 'B'
	;DEBUG_VAR 'C', SSPCON1
	movf	SSPBUF, w		; bcf BF
	clrf	SSPCON1
	clrf	SSPCON2

I2m_Init
	; only one address bsf	SSP2MSK, MSK1	; two addresses, mask 36-37 & 38-39
	movlw	0x26		; 7bit i2cslave w.o. IRQ on start/stop - dont hold
	;movlw	0x3E		; 7bit i2cslave WITH IRQ on start/stop - dont hold
	movwf	SSPCON1	; enable + i2c-7bit +irq
	bsf	SSPCON2, SEN	; use clock stretching
	bsf	SSPCON2, ADMSK1	; two addresses, mask 36-37 & 38-39
	movlw	0xE0
	movwf	SSPADD		; my addr
	clrf	i2c_stat
	return

I2m_stoped				; not start wont happen, unless spurius IRQ
	movf	SSPBUF, w		; clr BF
	bcf	SSPCON1, SSPOV		; clr overflow
	return

;----------------------------------------------------------------------------------------------------
I2mirq		; I2C - service
;----------------------------------------------------------------------------------------------------
	bcf	PIR1, SSPIF

	btfss	SSPSTAT, S		; NOT s
	bra	I2m_stoped	; !S wont happen, unless spurius IRQ

	DEBUG_N

	;btfsc	SSP2CON1, CKP
	;bra	I2m_Start		; master not waiting

	btfsc	SSPSTAT, R_NOT_W
	bra	I2m_read
	;+bra	i2m_write

;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
i2m_write				; TRANSMIT from master ( I need to read... )
;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	btfsc	SSPSTAT, D_NOT_A	; 
	bra	I2m_write_data		; got data

;;;;;;;;;;;;;;;;
I2mw_adr
;;;;;;;;;;;;;;;;
	movf	SSPBUF, w		; clr BF
	bsf	SSPCON1, CKP		; release clock - ready to send
	movwf	i2c_addr
	clrf	i2c_sum	
	clrf	i2c_stat
	DEBUG_CH '{'
	return

;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
I2m_write_data				; from master to me
;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	movf	SSPBUF, w
	bsf	SSPCON1, CKP		; release clock - ready to send
	movwf	i2c_io
	DEBUG_CH	'<'		; TODO test WCOL / SSPOV - needed?

	movf	i2c_stat, w
	bz	I2m_Transmit1	; LATA
	decf	WREG, f
	bz	I2m_Transmit2	; LATB
	decf	WREG, f
	bz	I2m_Transmit3	; LATC
	decf	WREG, f
	bz	I2m_Transmit4
Ireturn	return				; ignore all further writes from master

I2m_Transmit1
	movf	i2c_io, w
	movwf	i2c_data1
	bra	I2m_wr2
I2m_Transmit2
	movf	i2c_io, w
	movwf	i2c_data2
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
i2c_sum_error
;-----------------------------------------------------------------------------------------
	DEBUG_2C	'S', 'F'
	movf	i2c_data1, w
	DEBUG_CH '+'
	movf	i2c_data2, w
	DEBUG_CH '+'
	movf	i2c_data3, w
	DEBUG_CH '+'
	movf	i2c_sum, w
	DEBUG_CH '='
	movf	i2c_data4, w
	DEBUG_CH '!'
	DEBUG_N
	bra	I2m_NAK

i2mw_sum_fine
	movf	i2c_addr, w
	sublw	0xe2
	bz	Pwm_write_set
	;+bra	Port_write_E0

Port_write_E0
Port_write_set
	DEBUG_2C	'P', '+'
	movf	i2c_data1, w
	movwf	LATA
	;xorwf	LATA, w
	;andlw	ROM_MASK_A
	;xorwf	LATA, f
	movlw	ROM_MASK_A_write
	movwf	TRISA

	movf	i2c_data2, w
	xorwf	LATB, w
	andlw	ROM_MASK_B
	xorwf	LATB, f
	movlw	ROM_MASK_B_write
	movwf	TRISB

	movf	i2c_data3, w
	xorwf	LATC, w
	andlw	ROM_MASK_C
	xorwf	LATC, f
	movlw	ROM_MASK_C_write
	andwf	ROM_MASK_C_and, w	; pwm in use?
	movwf	TRISC

	DEBUG_N
	return

;;;;;;;;;;;;,,
Pwm_write_set
;;;;;;;;;;;;,,
	DEBUG_2C	'W', '+'
	

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
	movlw	0xff			; 1. ser PR
	btfsc	i2c_data1, 2
	bcf	WREG, 7
	btfsc	i2c_data1, 3
	bcf	WREG, 6
	movwf	PR2

	movf	i2c_data2, w		; 2. set duty
	movwf	CCPR1L
	movf	i2c_data3, w
	movwf	CCPR2L
					; 4. TMR2 is running
	setf	ROM_MASK_C_and
	movlw	0x00
	btfss	i2c_data1, 0
	bra	PW1_off
	bcf	TRISC, RC2		; 3. set TRIS...
	bcf	ROM_MASK_C_and, RC2
	movlw	0x0C
	btfsc	i2c_data1, 5
	bsf	WREG,5
	btfsc	i2c_data1, 4
	bsf	WREG,4
PW1_off	movwf	CCP1CON			; 5. configure CCpx for PWM

	movlw	0x00
	btfss	i2c_data1, 1
	bra	PW2_off
	bcf	TRISC, RC1		; 3. set TRIS...
	bcf	ROM_MASK_C_and, RC1
	btfsc	i2c_data1, 7
	bsf	WREG,5
	btfsc	i2c_data1, 6
	bsf	WREG,4
	movlw	0x0C
PW2_off movwf	CCP2CON

	DEBUG_N
	bra	I2m_release		; TODO i2m-retuen error

;####################################################################################################
I2m_read
;####################################################################################################
	btfsc	SSPSTAT, D_NOT_A	; 
	bra	I2m_read_data
;;;;;;;;;;;;;;;;
I2mr_adr
;;;;;;;;;;;;;;;;
	movf	SSPBUF, w		; clr BF
	movwf	i2c_addr
	clrf	i2c_sum			; check sum
	clrf	i2c_stat
	DEBUG_CH '['
	;+bra	I2m_read_data+4???

;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
I2m_read_data
;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	btfsc	SSPCON2, ACKSTAT
	bra	I2m_NAK				; master send NAK - dont want more data
	
	;btfsc	i2c_addr, 1	; E3: 1110-0011 - E1: 1110-0001
	;bra	I2m_Recive_E3	; is all the same...

;I2m_Recive_E3
I2m_Recive_E1
	movf	i2c_stat, w
	bz	I2m_recive1		; portA
	decf	WREG, f
	bz	I2m_recive2		; portC
	decf	WREG, f
	bz	I2m_recive3		; portC
	decf	WREG, f
	bz	I2m_recive4		; ci2c_sum
	movlw	0x55			; if master keeps reading...
	bra	I2m_putC

I2m_recive1
	btfsc	TRISA, 0		; is output? ( CHECK: ROM_MASK_A_read,0 )
	bra	I2m_recive1a
	movlw	ROM_MASK_A_read
	movwf	TRISA
	movlw	ROM_MASK_B_read
	movwf	TRISB
	movlw	ROM_MASK_C_read
	andwf	ROM_MASK_C_and, w	; pwm in use?
	movwf	TRISC
	DEBUG_2C 'A','I'
I2m_recive1a
	movf	PORTA, w
	bra	I2m_putC
I2m_recive2
	movf	PORTB, w
	bra	I2m_putC
I2m_recive3
	movf	PORTC, w
	bra	I2m_putC
I2m_recive4
	movf	i2c_sum, w
	;+bra	I2m_putC

;;;;;;;;;;;;,,
I2m_putC
;;;;;;;;;;;;,,
	movwf	SSPBUF
	bsf	SSPCON1, CKP		; release clock - ready to send
	addwf	i2c_sum, f
	incf	i2c_stat, f
	DEBUG_C	'>'
	DEBUG_H				; TODO test WCOL / SSPOV - needed?
	return

;####################################################################################################
; old
;####################################################################################################


I2m_release
	return



;-----------------------------------------------------------------------------------------
	END
;-----------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------
;-----------------------------------------------------------------------------------------

;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
; I2m ( i2c Module )
;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

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
