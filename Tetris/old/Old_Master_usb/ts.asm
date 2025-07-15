; vim: syntax=pic18
;
; copyright GPLv2
;
; Key a-f hex
;  (xx) l- look
;  (xx) L- Set high look bank
;   xx  p- push xx
;	z-hexdump 16b
;	Z-hexdump +16b
;	+-inc yyyy
;	--inc yyyy
;	g-Go/run 0x1000
;	x-xmocen new code > 0x1000 ( bootloader )
;	R-reset
;	s-status
;-
; -----------------------------------------------------------------------
;
;  Timers:
;	TMR0 -free running : USB-out timeout
;			: Mblink
;	TMR1 -free running : Clock
;
;	TMR3 -dcf clock	: reset each 10MS
;
;	TMR2	-  Led8x8
;	
;
; old	TMR1L, 7	; 128 * 8   * 2 = 2048
; old			; 4.000.000 /4 - 1.000.000 / 2048 = times 488/s
;
; new: 48.000.000 /4 = 12.000.000 / 488 = one IRQ for each 26785 cy
;    .26785 / 16pre / 16post = .105 = 0x69 - PR2
;
;
;
; PrintStat:
;
;OK
;KV_MON_Err_Mod, BANKED : KV_MON_Err, BANKED : KV_MON_Err_LiH KV_MON_Err_LiL :
;KV_MON_Err_Got, BANKED / KV_MON_Err_Exp, BANKED + KV_MON_ChaL, BANKED KV_MON_ChaH, BANKED
;
	list	w=0, n=9999, p=18F45k50
	radix	hex
	errorlevel -1302
	;errorlevel -302
	;errorlevel -1301

DEBUG=1
VBANK0=0x000
VBANK1=0x100
VBANK2=0x200
VBANK3=0x300
VBANK4=0x400
VBANK5=0x500
VBANK6=0x600
VBANK7=0x700

include "boot_gps.hw"
include "asmdef18.inc"
include "boot_gps.kinc"

VBANK4=KV_last_VBANK4
VBANK1=KV_last_VBANK1

cblock VBANK4
	PV_wait0
	PV_wait1
	PV_wait2
	Main_last_var
	endc
VBANK4=Main_last_var
#define _mblink		Main_Bits, 0
#define	_CLK_Blink	Main_Bits, 4
#define	_OSC_set	Main_Bits, 6
#define	_LED_buffer	Main_Bits, 7

cblock VBANK0
	Debugv
	DebugW
	W_TEMP
	STATUS_TEMP
	BSR_TEMP

	Main_Bits
	LED_type		; clock display

	M_in
	ws_tmp

	osc_lednr
	osc_pos
	osc_tim

	disp_cn
	key_g
	disp_delay

	;Key_Denoise_Tim		; for keys...
	;Key_bits		; todo init
	;KeyM_tim
	;KeyS_tim
	;setmode
	;sec
	;min
	;hour
	;led_var_i

	last_main0
	endc
VBANK0=last_main0

cblock VBANK2
	disp_a:0x10
	tris_da:0x10
	last_main2
	endc
VBANK2=last_main2

#define	_Key_LCK	Key_bits, 0	; lock input for Key_Mode_Timeout..
#define	_KeyMode	Key_bits, 1
#define	_KeyM_Last	Key_bits, 2
#define	_KeySet		Key_bits, 3
#define	_KeyS_Last	Key_bits, 4

#define	_setsec		Key_bits, 5
#define	_setmin		Key_bits, 6
#define	_sethour	Key_bits, 7

#define	MRETURN		0x1006

LED_start=0x1500	; size <00F0
CLK_start=0x1560	; size <00D0
GPS_start=0x1900	; size <0460
;#include "Led8x8.asm"
;#include "Clock.asm"
;include "Gps.asm"

ws_red=b'00000100'	; ( ws_red * 3 ) + ( ws_boost * 3 )
ws_blue=b'00010000'
ws_green=b'00000001'	; All can be X3, e.g.:
ws_boost=b'01000000'

;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
; Start:
;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	org	0x1000
	clrf	key_g
	bra	0x1028
	nop
	org	MRETURN
	return
;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
; IRQ:
;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	org	0x1008 		; High-priority interrupt 
	btfsc	PIR1, TMR2IF
	nop;rcall	Led_Irq
	retfie	FAST
	nop
	nop
	nop
	nop
	nop

	ORG 0x1018		; Low-priority interrupt
	btfsc	USB_PIR
	rcall	irq_USB
	retfie
	nop
	nop
	nop
	nop
	nop

	ORG 0x1028		; init
init2	bra	init3

irq_USB	bcf	USB_PIR
	movff	STATUS, STATUS_TEMP
	movff	BSR, BSR_TEMP
	movwf	W_TEMP
	call	K_ServiceUSB	; service USB requests...
	movf	W_TEMP, w
	movff	BSR_TEMP, BSR
	movff	STATUS_TEMP, STATUS
	return

;------------------------------------------------------------------------------------------;
;	IRQ - helpers
;------------------------------------------------------------------------------------------;
LocalIRQ
	bcf	INTCON, GIEH
	bcf	INTCON, GIEL
	bsf	OSCTUNE, 0	; take IRQ from Kernel
	bsf	RCON, IPEN	; enable prioritized IRQ

	bcf	INTCON2, TMR0IP	; lowP irq
	;TODO bsf	INTCON,  TMR0IE	; enable

	bcf	IPR3, USBIP	; move usb to low
	bsf	PIE3, USBIE	; already set

	bsf	IPR1, TMR2IP	; tmr2 - high prioity
	;bsf	PIE1, TMR2IE

	bsf	INTCON, GIEH
	bsf	INTCON, GIEL

		; xssss|ee
		; 76543210
	movlw	b'01111111'	; on, ps:16, po:1[,4,16]
	movwf	T2CON
	movlw	0x18;	69
	movwf	PR2		; TODO some fancy FREQ/x ...
	return

KernelIRQ  ; ( undo LocalIRQ )
	bcf	INTCON, GIEH
	bcf	INTCON, GIEL

	;rcall	Led_AllOff

	bcf	INTCON, TMR0IE	; disable t0 irq
	bcf	PIE1,   TMR2IE	; disable t2 irq

	bsf	IPR3, USBIP	; move usb to (back ) to high
	bcf	RCON, IPEN	; disble prioritized IRQ
	bcf	OSCTUNE, 0	; set IRQ to Kernel

	bsf	INTCON, GIEH
	bsf	INTCON, GIEL
	return

;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
; init:
;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

init3
G_init	BANKSEL PV_wait0
	clrf	PV_wait0, BANKED
	clrf	PV_wait1, BANKED
	clrf	PV_wait2, BANKED
	rcall	wait2MS		; wait 2 ms to stabilize xtal + ppl
	BANKSEL	UCON
	movlw	0x00
	movwf	UCON, BANKED	; USB off
	BANKSEL	KV_blkc
	rcall	wait2MS		; leave USB off for 2 MS
	call	K_Init		; ports, usb, irq...
	rcall	wait2MS		; wait 2 ms to stabilize xtal + ppl
	bra	Re_init

	push
Re_init	pop
	movlw	TRIS_FOR_A
	movwf	TRISA		; todo ( new kernel )
	movlw	TRIS_FOR_C
	movwf	TRISC
	bcf	_MultiLed

	rcall	LocalIRQ

	setf	LATB
	clrf	LATD
	clrf	TRISB
	clrf	TRISD
	clrf	TBLPTRU		; since dev < 64k...
	;;clrf	TXSTA1
	;clrf	RCSTA1
	;movlw	b'10011001'	; TMR1CS1 TMR1CS0 T1CKPS1 T1CKPS0 T1OSCEN  T1SYNC RD16 TMR1ON
	movlw	b'00111001'	; TMR1CS1 TMR1CS0 T1CKPS1 T1CKPS0 T1OSCEN  T1SYNC RD16 TMR1ON
	movwf	T1CON		; 16bit, ps=8, int src, on

	rcall	disp_setup

		; 76543210
	movlw	b'00001001'	; use only USB
	movwf	KV_MON_conf, BANKED
	movlw	0x20
	movwf	KV_blki, BANKED
	movlw	'#'
	movwf	KV_MON_char, BANKED
	rcall	PrintP

	movlw	b'00110011'		; fosc/4, psa=8, !OSC, !sync, RD16, on
	movwf	T3CON			; each= 1/((12mips*10^6 ) / 2^16bit timer /8 psa)
					;       1/ (( 12 * 10^6) / 2^16 /8 ) = .04369s
	movlw	low (LATD)
	movwf	KV_MON_atL, BANKED
	movlw	high(LATD)
	movwf	KV_MON_atH, BANKED
	movlw	b'00000001'
	movwf	Debugv	;	_DEBUG

	clrf	LED_type
	movlw	( ws_green * 2 ) + ( ws_boost * 0 )	; give green light :)
	rcall	ws_8bitcol
	clrf	disp_cn

	;+bra	kLoop

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
kLoop
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	btfsc	INTCON, TMR0IF	; T0 timeout
	rcall	Blink2

	call	K_GetC 		; banksave
	btfss	_C
	rcall	M_input
	
	dcfsnz	disp_delay,f
	rcall	disp_update


	bra	kLoop

disp_update
	movlw	0x0f
	movwf	disp_delay
	rcall	MonI_i
	return
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
Blink2
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	bcf	INTCON, TMR0IF		;   as soon as GIE is set.
	nop

	BANKSEL	KV_blkc
	decfsz	KV_blkc, f, BANKED
	return
	movlw	0x25
	movwf	KV_blkc
	btg	_mblink

	movlw	( ws_red * 1 ) + ( ws_boost * 0 )	; give red light :)
	btfss	disp_cn, 0
	movlw	( ws_green * 1 ) + ( ws_boost * 0 )	; give green light :)
	;movlw	ws_blue*2
	btfss	_mblink
	movlw	0
	bra	ws_8bitcol	; IIrrbbgg
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


Update_Firmware	; got x
	rcall	KernelIRQ 	; ( or undo localIRQ )
	call	K_Update_Firmware
	bra	Re_init

MonI_n	BANKSEL	KV_MON_readnum
	movf	KV_MON_readnum, w, BANKED
	;rcall	ws_8bitcol	; IIrrbbgg
	bra	PrintP
MonI_G
	movlw	'G'
	rcall	PrintW
	movlw	'o'
	rcall	PrintW
	movlw	'n'
	rcall	PrintW
	movlw	'e'
	rcall	PrintW
	bra	Re_init

MonI_q	movlw	'R'
	rcall	PrintW
	bra	disp_setup

MonI_U
	movlw	'U'
	rcall	PrintW
	movlw	'S'
	rcall	PrintW
	movlw	'B'
	rcall	PrintW
	bra	G_init
	
MonI_g	incf	key_g,f
	return
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
M_input
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	movwf	M_in
	;movf	M_in, w
	sublw	'g'
	bz	MonI_g

	movf	M_in, w
	sublw	'x'
	btfsc	_Z
	bra	Update_Firmware	; got , x


	movf	M_in, w
	sublw	a'i'
	bz	MonI_i

	movf	M_in, w
	sublw	a'r'
	btfsc	_Z
	bra	Re_init

	movf	M_in, w
	sublw	a'U'
	bz	MonI_U

	movf	M_in, w
	sublw	a'q'
	bz	MonI_q

	movf	M_in, w
	sublw	a'G'
	bz	MonI_G

	movf	M_in, w
	sublw	a'w'
	bz	MonI_w

	movf	M_in, w
	sublw	a'W'
	bz	MonI_W

	;movf	M_in, w
	;sublw	a'O'
	;bz	MonI_O

	movf	M_in, w
	sublw	a't'
	bz	MonI_t

	movf	M_in, w
	sublw	a'y'
	bz	MonI_y

	;movf	M_in, w
	;sublw	a'w'
	;bz	MonI_w

	movf	M_in, w
	sublw	a'j'
	bz	MonI_j

	movf	M_in, w
	sublw	a'v'
	btfsc	_Z
	bra	gps_vers

;
; Rest wants "arguments"
;
	btfss	KB_gotnum
	bra	USBin2		; so make sure we got some
	movf	M_in, w
	sublw	a'n'
	btfsc	_Z
	bra	MonI_n		; got ARG, w
USBin2	movf	M_in, w
	goto	K_Input

;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

gps_vers
MonI_y
MonI_w
MonI_W
MonI_t
MonI_i
	incf	disp_cn, w	; so disp_cn = FSR1???
	andlw	0x0F      	;   - drop disp_cn
	movwf	disp_cn   	;   OR set FSR1H too.


	;LFSR	FSR1, disp_a	; q sets this
MonI_iz
	clrf	LATD
	btfsc	disp_cn, 3
	setf	LATD

	LFSR	FSR1, disp_a
	movf	PLUSW1, w
	movwf	LATB	


	LFSR	FSR1, tris_da
	movf	disp_cn, w
	movf	PLUSW1, w
	movwf	TRISD	


	return

	movf	disp_cn, w
	rcall	PrintHex
	movlw	'='
	rcall	PrintW
	movlw	'>'
	rcall	PrintW
	movf	TRISD, w
	rcall	PrintHex
	movlw	','
	rcall	PrintW


	movf	LATB, w
	rcall	PrintHex






	bra	PrintP

MonI_j	movlw	'j'		; free
	rcall	PrintW
	return



	org	0x1600


disp_setup
	LFSR	FSR1 ,disp_a
char_A:	movlw	b'00011000'
	movwf	POSTINC1
	movlw	b'00111100'
	movwf	POSTINC1
	movlw	b'01100110'
	movwf	POSTINC1
	movlw	b'01111110'
	movwf	POSTINC1
	movlw	b'01100110'
	movwf	POSTINC1
	movlw	b'01100110'
	movwf	POSTINC1
	movlw	b'01100110'
	movwf	POSTINC1
	movlw	b'00000000'
	movwf	POSTINC1

char_B:	movlw	b'01111100'
	xorlw	0xff
	movwf	POSTINC1
	movlw	b'01100110'
	xorlw	0xff
	movwf	POSTINC1
	movlw	b'01100110'
	xorlw	0xff
	movwf	POSTINC1
	movlw	b'01111100'
	xorlw	0xff
	movwf	POSTINC1
	movlw	b'01100110'
	xorlw	0xff
	movwf	POSTINC1
	movlw	b'01100110'
	xorlw	0xff
	movwf	POSTINC1
	movlw	b'01111100'
	xorlw	0xff
	movwf	POSTINC1
	movlw	b'00000000'
	xorlw	0xff
	movwf	POSTINC1

;char_C:	movlw	b'00111100'
;	movwf	POSTINC1
;	movlw	b'01100110'
;	movwf	POSTINC1
;	movlw	b'01100000'
;	movwf	POSTINC1
;	movlw	b'01100000'
;	movwf	POSTINC1
;	movlw	b'01100000'
;	movwf	POSTINC1
;	movlw	b'01100110'
;	movwf	POSTINC1
;	movlw	b'00111100'
;	movwf	POSTINC1
;	movlw	b'00000000'
;	movwf	POSTINC1
;
;char_H:	movlw	b'01100110'
;	movwf	POSTINC1
;	movlw	b'01100110'
;	movwf	POSTINC1
;	movlw	b'01100110'
;	movwf	POSTINC1
;	movlw	b'01111110'
;	movwf	POSTINC1
;	movlw	b'01100110'
;	movwf	POSTINC1
;	movlw	b'01100110'
;	movwf	POSTINC1
;	movlw	b'01100110'
;	movwf	POSTINC1
;	movlw	b'00000000'
;	movwf	POSTINC1
;
;char_M:	movlw	b'01100011'
;	movwf	POSTINC1
;	movlw	b'01110111'
;	movwf	POSTINC1
;	movlw	b'01111111'
;	movwf	POSTINC1
;	movlw	b'01101011'
;	movwf	POSTINC1
;	movlw	b'01100011'
;	movwf	POSTINC1
;	movlw	b'01100011'
;	movwf	POSTINC1
;	movlw	b'01100011'
;	movwf	POSTINC1
;	movlw	b'00000000'
;	movwf	POSTINC1


	LFSR	FSR1 ,tris_da
tristable_inv
	movlw	b'11111110'
	movwf	POSTINC1
	movlw	b'11111101'
	movwf	POSTINC1
	movlw	b'11111011'
	movwf	POSTINC1
	movlw	b'11110111'
	movwf	POSTINC1
	movlw	b'11101111'
	movwf	POSTINC1
	movlw	b'11011111'
	movwf	POSTINC1
	movlw	b'10111111'
	movwf	POSTINC1
	movlw	b'01111111'
	movwf	POSTINC1

tristable_inv2
	movlw	b'11111110'
	movwf	POSTINC1
	movlw	b'11111101'
	movwf	POSTINC1
	movlw	b'11111011'
	movwf	POSTINC1
	movlw	b'11110111'
	movwf	POSTINC1
	movlw	b'11101111'
	movwf	POSTINC1
	movlw	b'11011111'
	movwf	POSTINC1
	movlw	b'10111111'
	movwf	POSTINC1
	movlw	b'01111111'
	movwf	POSTINC1



;tristable_reg
;	movlw	b'00000001'
;	movwf	POSTINC1
;	movlw	b'00000010'
;	movwf	POSTINC1
;	movlw	b'00000100'
;	movwf	POSTINC1
;	movlw	b'00001000'
;	movwf	POSTINC1
;	movlw	b'00010000'
;	movwf	POSTINC1
;	movlw	b'00100000'
;	movwf	POSTINC1
;	movlw	b'01000000'
;	movwf	POSTINC1
;	movlw	b'10000000'
;	movwf	POSTINC1






	clrf	disp_cn		; 0-0F
	movlw	b'11111110'
	movwf	TRISD

	movlw	b'00000001'
	movwf	LATD
	
	clrf	TRISB
	movlw	b'01010101'
	movwf	LATB
	
	clrw
	bra	MonI_iz

;------------------------------------------------------------------------------------------;
;------------------------------------------------------------------------------------------;
;------------------------------------------------------------------------------------------;
	org 0x1700
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

ws_bit	rlcf	WREG, f
	bsf	_MultiLed
	nop			; 1
	btfsc	_C		; 1
	rcall	wait8c		; 1 / 8
	bcf	_MultiLed	; return, rcall, rrf, bsf  2+2+1+1 + wait8
	;+bra	wait8c
wait8c	bra	$+2
	bra	$+2
	return





;--------------------------- call - repeaters ---------------------------------------------;
PrintW		goto	K_PrintW
PrintP		goto	K_PrintP
PrintHex	goto	K_PrintHex
PrintNl		goto	K_PrintNl
;PrintP		goto	K_PrintP
;PrintStat	goto	K_PrintStat
;PrintDigi	goto	K_PrintDigi
;lk_PrintTBL	goto	K_PrintTBL

;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
HW_wait_0
;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	movwf	PV_wait0, BANKED
	bra	HW_ws
HW_wait_1
	movwf	PV_wait1, BANKED
	bra	HW_ws
HW_wait_2
	movwf	PV_wait2, BANKED
	bra	HW_ws
wait_some
HW_ws2	decf	PV_wait2, f, BANKED
HW_ws1	decf	PV_wait1, f, BANKED
HW_ws0	decf	PV_wait0, f, BANKED
HW_ws	tstfsz	PV_wait0, BANKED
	bra	HW_ws0
	tstfsz	PV_wait1, BANKED
	bra	HW_ws1
	tstfsz	PV_wait2, BANKED
	bra	HW_ws2
	return

wait2MS
	waitNS	.2000000	; wait 2 ms
	return

SwitchCaseX2
	rlncf	WREG	; w * 2
SwitchCase
	rlncf	WREG	; w * 2
	addwf	TOSL, f
	movlw	0
	addwfc	TOSH, f
	addwfc	TOSU, f	; for >64K bytes memory
	return

	END
