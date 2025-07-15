; vim:syntax=pic18

;		Boot-serial for pic18f2320 ( Tetris Slave )
#Define VerStr .22, "ersion Tet 1.00, 8 Mhz" ; (V from cmd)

;;;;;;;;;;;;;;;;;;;;;;;;;

;  EUSART2
;#define	SeM_RCSTA	RCSTA2
;#define	SeM_TXSTA	TXSTA2
;#define	SeM_TXREG	TXREG2
;#define	SeM_RCREG	RCREG2
;#define	SeM_BAUDCTL	BAUDCON2
;#define SeM_SPBRG	SPBRG2
;#define	SeM_SPBRGH	SPBRGH2
;#define	_SeM_RCIF	PIR3, RC2IF
;#define	_SeM_TXIF	PIR3, TX2IF
;#define SDC_SSPSTAT	SSP2STAT
;#define SDC_SSPCON1	SSP2CON1
;#define SDC_SSPCON2	SSP2CON2
;#define SDC_SSPBUF	SSP2BUF
;


;====================================================================================================
;===  boot init code ===
;====================================================================================================
freq=.8000000
FREQ=freq ; freq=.4000000
	list	p=18F2320

#include	"p18f2320.inc"

	;OSC = INTIO2         Internal RC oscillator, port function on RA6 and port function on RA7
	;OSC = INTIO1         Internal RC oscillator, CLKO function on RA6 and port function on RA7
        CONFIG OSC = INTIO2     ; Internal RC oscillator, RB6 and RB7 as general purpose
	;CONFIG FSCM = ON	; Fail-Safe Clock Monitor enabled
	CONFIG FSCM = OFF	; Fail-Safe Clock Monitor enabled
	CONFIG IESO = OFF	; Internal/External Switchover mode disabled
	CONFIG BOR = OFF	; Brown-out Reset disabled
	CONFIG WDT = OFF	; WDT disabled (control is placed on the SWDTEN bit)
	CONFIG PBAD = DIG	; PORTB<4:0> pins are configured as digital I/O on Reset
	;CONFIG MCLRE = ON	; MCLR disabled; RE3 input is enabled in 40-pin only (PIC18F4X20)
	CONFIG MCLRE = OFF	; MCLR disabled; RE3 input is enabled in 40-pin only (PIC18F4X20)
	CONFIG STVR = ON	; Stack full/underflow will cause Reset
	CONFIG LVP = OFF	; Single-Supply ICSP disabled
;
	CONFIG DEBUG = OFF	; Background debugger disabled, RB6 and RB7 as general purpose
	CONFIG CP0 = OFF  	; Block 0 (000200-0007FFh) not code-protected
	CONFIG CP1 = OFF  	; Block 1 (000800-000FFFh) not code-protected
	CONFIG CP2 = OFF  	; Block 2 (001000-0017FFh) not code-protected
	CONFIG CP3 = OFF  	; Block 3 (001800-001FFFh) not code-protected
	CONFIG CPB = OFF  	; Boot block (000000-0001FFh) is not code-protected
	CONFIG CPD = OFF  	; Data EEPROM is not code-protected
	CONFIG WRT0 = OFF 	; Block 0 (000200-0007FFh) not write-protected
	CONFIG WRT1 = OFF 	; Block 1 (000800-000FFFh) not write-protected
	CONFIG WRT2 = OFF 	; Block 2 (001000-0017FFh) not write-protected
	CONFIG WRT3 = OFF 	; Block 3 (001800-001FFFh) not write-protected
	CONFIG WRTC = OFF 	; Configuration registers (300000-3000FFh) are not write-protected
	CONFIG WRTB = OFF 	; Boot block (000000-0001FFh) is not write-protected
	CONFIG WRTD = OFF 	; Data EEPROM is not write-protected
	CONFIG EBTR0 = OFF	; Block 0 (000200-0007FFh) not protected from table reads
	CONFIG EBTR1 = OFF	; Block 1 (000800-000FFFh) not protected from table reads
	CONFIG EBTR2 = OFF	; Block 2 (001000-0017FFh) not protected from table reads
	CONFIG EBTR3 = OFF	; Block 3 (001800-001FFFh) not protected from table reads
	CONFIG EBTRB = OFF	; Boot block (000000-0001FFh) is not protected from table reads

BootCode=BootCode+1


; -----------------------------------------------------------------------


L_init	MACRO				; local chip init, macro in *.hw
;	movlw	0xff
;	movff	WREG, ANCON0		; all digital
;	movff	WREG, ANCON1		; all digital
;	movlw	0x07
;	movwf	CM1CON
;	movwf	CM2CON
;
	clrf	OSCTUNE
		; 76543210
	movlw	b'01110011'	; 0-IDLEN, 111-8mhz,
	movwf	OSCCON		;  0-OTS,0-IOFS,10-Int.
	clrf	OSCTUNE
	clrf	OSCTUN2

	clrf	LATA		; all output low
	clrf	LATB
	clrf	LATC
	movlw	0x7f
	movwf	ADCON1
	movlw	TRIS2_FOR_A
	movwf	TRISA
	movlw	TRIS2_FOR_B
	movwf	TRISB
	movlw	TRIS2_FOR_C
	movwf	TRISC
	clrf	TBLPTRU
	ENDM

