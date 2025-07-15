; vim:syntax=pic18 autowrite
;
; i2c Slave
;	K_I2Cs_Init=ready for i2c-slave, addr: 
;	I2CS_reboot; reset i2c and call init
;    
;
;
;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
; Vars:
;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

#ifndef I2CS_Start
I2CS_Start=0
#endif

#IF I2CS_Start==0  ; {
	LIST
K_I2Cs_Init=K_Return
I2CS_reboot=K_Return

#ELSE ; } {
	LIST
	ORG I2CS_Start
#define PV_wait0	HV_wait0
#define PV_wait1	HV_wait1
#define PV_wait2	HV_wait2
	cblock 	VBANK0

	i2c_addr
	i2c_sum
	i2c_io
	i2c_put
	i2c_data1
	;i2c_data2
	i2c_data3
	i2c_data4
	;I2C_wait
	i2c_pc

	main_last_var
	endc
VBANK0=main_last_var

DEBUG=1			; include debug code (lots!)
MON_Pchar=a'%'

I2C_LISTEN=0x21		; 21 in pico, 42 in real
;
;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
; I2SC ( i2c slave Module )
;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

I2CS_reboot
	DEBUG_2C 'R', 'B'
	DEBUG_VAR 'C', SSPCON1
	movf	SSPBUF, w		; bcf BF
	clrf	SSPCON1
	clrf	SSPCON2

;----------------------------------------------------------------------------------------------------
K_I2Cs_Init
I2CS_Init
;----------------------------------------------------------------------------------------------------
	;movlw	'2'
	;rcall	K_PrintW
	; only one address bsf	SSPMSK, MSK1	; two addresses, mask 36-37 & 38-39
	;movlw	0x3E		; 7bit i2cslave WITH IRQ on start/stop - dont hold
	movlw	0x36		; 7bit i2cslave w.o. IRQ on start/stop - dont hold
	movwf	SSPCON1		; enable + i2c-7bit +irq
	bsf	SSPCON2, SEN	; use clock stretching
	;bcf	SSPMSK, MSK1	; two addresses, mask E4-E5,e6-E7
	;bsf	SSPCON2, GCEN	; picF2420: no mask, but general recive ( adr= 0x00 )
	movlw	I2C_LISTEN*.2		; 21 in pico, 42 in real TODO make as define, to enable this in compile
	movwf	SSPADD		; my addr
	clrf	i2c_stat
	bsf	SSPCON1, CKP	; release clock - ready to get commands
	return

;----------------------------------------------------------------------------------------------------


I2CS_NAK				; master send NAK - dont want more data
	DEBUG_C	'!'
	return

I2CS_stoped				; not start wont happen, unless spurius IRQ
	movf	SSPBUF, w		; clr BF
	bcf	SSPCON1, SSPOV		; clr overflow
	return

;----------------------------------------------------------------------------------------------------
I2CS_irq		; I2C - service
;----------------------------------------------------------------------------------------------------
	bcf	_i2c_if
	DEBUG_N
	DEBUG_C 'I'

	btfss	SSPSTAT, S	; NOT s
	bra	I2CS_stoped	; !S wont happen, unless spurius IRQ


	;btfsc	SSPCON1, CKP
	;bra	I2CS_Startaddr		; master not waiting

	btfsc	SSPSTAT, R_NOT_W
	bra	I2CS_read
	;+bra	i2m_write

;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
i2m_write				; TRANSMIT from master ( I need to read... )
;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	btfsc	SSPSTAT, D_NOT_A	; 
	bra	I2CS_write_data		; got data

;;;;;;;;;;;;;;;;
I2CS_w_adr
;;;;;;;;;;;;;;;;
	movf	SSPBUF, w		; clr BF
	bsf	SSPCON1, CKP		; release clock - ready to send ACK
	;movwf	i2c_addr
	clrf	i2c_sum	
	clrf	i2c_stat
	DEBUG_CH '{'
	return

;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
I2CS_write_data				; from master to me
;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	movf	SSPBUF, w
	bsf	SSPCON1, CKP		; release clock - ready to send
	movwf	i2c_io
	DEBUG_CH	'<'		; TODO test WCOL / SSPOV - needed?

	movf	i2c_stat, w
	bz	I2CS_Transmit1	; LATA
	decf	WREG, f
	bz	I2CS_Transmit3	; LATC
	decf	WREG, f
	bz	I2CS_Transmit4
Ireturn	return				; ignore all further writes from master
	return				; ignore all further writes from master

I2CS_Transmit1
	movf	i2c_io, w
	movwf	i2c_data1
	bra	I2CS_wr2
I2CS_Transmit3
	movf	i2c_io, w
	movwf	i2c_data3
	;+bra	I2CS_wr2
I2CS_wr2 addwf	i2c_sum, f
	incf	i2c_stat, f	
	return

I2CS_Transmit4				; cheksum
	incf	i2c_stat, f
	movf	i2c_io, w
	movwf	i2c_data4
	return ; TODO

	subwf	i2c_sum, w
	;TODObz	i2mw_sum_fine
	;+bra	i2c_sum_error
#if 0

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
#endif ;0

;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
I2CS_read
;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	btfsc	SSPSTAT, D_NOT_A	; 
	bra	I2CS_read_data
;;;;;;;;;;;;;;;;
I2CS_r_adr
;;;;;;;;;;;;;;;;
	movf	SSPBUF, w		; clr BF
	movwf	i2c_addr
	movwf	i2c_sum			; check sum - addr is now part of sum
	clrf	i2c_stat
	DEBUG_CH '['
	;+bra	I2CS_read_data

;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
I2CS_read_data
;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	btfsc	SSPCON2, ACKSTAT
	bra	I2CS_NAK				; master send NAK - dont want more data
	
	btfsc	i2c_addr, 1	; E5: 1110-0101 - E7: 1110-0111
	bra	I2CS_Recive_E7

I2CS_Recive_E5
	movf	i2c_stat, w
	bz	I2CS_recive1		; portA
	decf	WREG, f
	bz	I2CS_recive3		; portC
	decf	WREG, f
	bz	I2CS_recive4		; ci2c_sum
	movlw	0x55			; if master keeps reading...
	bra	I2CS_putC

I2CS_recive1
	btfsc	TRISA, 0		; is output?
	bra	I2CS_recive1a
	setf	TRISA			; set input
	setf	TRISC
	DEBUG_2C 'A','I'
	waitUS	.10
I2CS_recive1a
	movf	PORTA, w
	;incf	i2c_put, f
	;movf	i2c_put, w
	bra	I2CS_putC
I2CS_recive3
	movf	PORTC, w
	;incf	i2c_put, f
	;movf	i2c_put, w
	bra	I2CS_putC
I2CS_recive4
	movf	i2c_sum, w
	;+bra	I2CS_putC

;;;;;;;;;;;;,,
I2CS_putC
;;;;;;;;;;;;,,
	movwf	SSPBUF
	bsf	SSPCON1, CKP		; release clock - ready to send
	addwf	i2c_sum, f
	incf	i2c_stat, f
	DEBUG_C	'>'
	DEBUG_H				; TODO test WCOL / SSPOV - needed?
	return

I2CS_Recive_E7		
	DEBUG_2C 'A','i'
	setf	TRISA			; set input
	setf	TRISC			; set input
	movlw	0xff			; enables master to do STOP
	;bsf	SSPCON1, CKP		; release clock - ready to send
	;return
	bra	I2CS_putC

;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#ENDIF ; } i2c_slave.asm
