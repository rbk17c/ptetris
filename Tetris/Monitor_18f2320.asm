; vim:syntax=pic18
; Monitor code
; Manual:
;
; set	MON_Start=0x0...
;
#define	MON_FSRl	FSR1L
#define	MON_FSRh	FSR1H
#define	MON_INDF	INDF1
#define	MON_POSTINC	POSTINC1
#define KB_halfnum	KV_MON_bits, 0, BANKED
#define KB_gotnum	KV_MON_bits, 1, BANKED

MON_ADR=LATA		; inital adress for monitor to point at ( LATA)

	NOLIST
#ifndef MON_Start
MON_Start=0
#endif

#IF MON_Start==0
	LIST
K_MON_Init=K_Return
K_PrintW=K_Return
K_PrintDigi=K_Return
K_PrintHex=K_Return
K_PrintP=K_Return
K_PrintNl=K_Return
K_PrintStat=K_Return
K_Input=K_Return
mon_readnum=K_Return
K_MON_swapTBL=K_Return
K_MON_swapFSRm=K_Return
K_GetC=K_Return

#ELSE ; {
	LIST
	ORG MON_Start
K_PrintW=K_SEM_PutC
K_GetC=K_SEM_PutC
K_GetC=K_SEM_PutC

#ifndef MON_Pchar
MON_Pchar=a'>'
#endif

	cblock	VBANK1
		KV_MON_bits
		KV_MON_readnum
		KV_MON_char
		KV_MON_Err_Code
		KV_MON_Err_Mod
		KV_MON_Err_LiH, KV_MON_Err_LiL
		KV_MON_Err_Got
		KV_MON_Err_Exp
		KV_MON_ChaL, KV_MON_ChaH	; changes done
		KV_MON_atL, KV_MON_atH
		TBLPTRU_s, TBLPTRH_s, TBLPTRL_s
		MON_A1
		MON_A2
		Monitor_last_var
	endc
VBANK1=Monitor_last_var

;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
K_MON_Init

;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	banksel	VBANK1
	clrf	KV_MON_bits, BANKED
	movlw	MON_Pchar
	movwf	KV_MON_char, BANKED

	movlw	a'R'
	movwf	KV_MON_Err_Mod, BANKED	; Module R
	clrf	KV_MON_Err_Code, BANKED
	clrf	KV_MON_Err_LiL, BANKED	; Start on line1
	clrf	KV_MON_Err_LiH, BANKED	; linesH
	clrf	KV_MON_Err_Got, BANKED	; 
	clrf	KV_MON_Err_Exp, BANKED	; 
	clrf	KV_MON_ChaL, BANKED	; changes done
	clrf	KV_MON_ChaH, BANKED 	
	movlw	high (MON_ADR)
	movwf	KV_MON_atH, BANKED
	movlw	low (MON_ADR)
	movwf	KV_MON_atL, BANKED
	return
;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
; print functions
;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
;K_promptC
;	movlw	a':'
;	bra	K_PrintW
;
;K_promptE
;	movlw	a'='
;	bra	K_PrintW

K_PrintNl
	movlw	h'0a'
	rcall	K_PrintW
	movlw	h'0d'
	bra	K_PrintW

K_Print_Err
	banksel	MON_A1
	movf	MON_A1, w, BANKED
	rcall	K_PrintHex
	movlw	a'?'
	bra	K_PrintW

K_PrintDigi
	banksel	MON_A1
	movwf	MON_A2, BANKED
	movlw	a'0'-1
	movwf	MON_A1, BANKED
	movlw	d'10'
txdiv10	incf	MON_A1, f, BANKED
	subwf	MON_A2, f, BANKED
	btfsc	_C
	bra	txdiv10
	movf	MON_A1, w, BANKED
	rcall	K_PrintW
	movf	MON_A2, w, BANKED
	addlw	a'0' + d'10'
	bra	K_PrintW

K_PrintP
	banksel	MON_A1
	bcf	KB_halfnum
	bcf	KB_gotnum
	rcall	K_PrintNl
	movf	KV_MON_char,w, BANKED
	bra	K_PrintW

K_PrintHex ; uses: t2, (PrintW t3)
	banksel	MON_A1
	movwf	MON_A2, BANKED
	swapf	MON_A2, w, BANKED
	rcall	MON_2hx	; rcall	K_PrintW
	movf	MON_A2, w, BANKED
	;rcall	tohex ;	bra	K_PrintW

MON_2hx	andlw	b'00001111'
	addlw	0x00 - 0x0A
	btfsc	_C;bnc	hextab0_9
	addlw	a'A' + 0x0A - 0x0A - (  0x0A + a'0' )	 
	addlw	a'0' + 0x0A
	bra	K_PrintW

;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
K_Input
M_Input
;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
	BANKSEL	MON_A1
	movwf	MON_A1, BANKED
	rcall	K_PrintW

	movf	MON_A1, w, BANKED
	sublw	h'0d'		; got Newline ?
	btfsc	_Z
	bra	K_PrintP

	movf	MON_A1, w, BANKED
	sublw	a'R' ; 2B
	btfsc	_Z
	reset
;
ckhex	movf	MON_A1, w, BANKED; in only 10 instr.
	addlw	-a'0'		; < '0'
	bnc	mon_decodeA
	addlw	-0x0a		; > '9'
	bnc	mon_H09		; got 0-9 => decodehex
	andlw	b'11011111'	; all capitals ( this works, while offset by 0x0a+'0')
	addlw	-'A'+(0x0a+'0')	; <'A' ?
	bnc	mon_decodeB
	addlw	-0x06		; >'F' ( A+6 )
	bc	mon_decodeC
	addlw	0x06
mon_H09	addlw	0x0a		; change output to 0-9
	btfsc	KB_halfnum
	bra	mon_H2
	movwf	KV_MON_readnum, BANKED
	bsf	KB_halfnum
	bcf	KB_gotnum
	return
mon_H2	swapf	KV_MON_readnum, f, BANKED
	iorwf	KV_MON_readnum, f, BANKED
	bcf	KB_halfnum
	bsf	KB_gotnum
	return
mon_decodeA	; <'0'
mon_decodeB	; <'A'
mon_decodeC	; >'F'
mon_decode
	movf	MON_A1, w, BANKED
	sublw	a'V'
	btfsc	_Z
	bra	K_Version	; got ,q

	movf	MON_A1, w, BANKED
	sublw	a'T'
	btfsc	_Z
	bra	Mon_xT

	movf	MON_A1, w, BANKED
	sublw	a't'
	btfsc	_Z
	bra	Mon_xt

	movf	MON_A1, w, BANKED
	sublw	a'i'
	btfsc	_Z
	bra	Mon_xi

	movf	MON_A1, w, BANKED
	sublw	a'I'
	btfsc	_Z
	bra	Mon_xI

	movf	MON_A1, w, BANKED
	sublw	a'j'
	btfsc	_Z
	bra	Mon_xj

	movf	MON_A1, w, BANKED
	sublw	a'J'
	btfsc	_Z
	bra	Mon_xJ

#ifdef	dumpEEPROM
	movf	MON_A1, w, BANKED
	sublw	'y'
	btfsc	_Z
	bra	DEBUG_I2CS_irq

	movf	MON_A1, w, BANKED
	sublw	'Y'
	btfsc	_Z
	bra	I2CS_reboot
#endif
#ifdef	DEBUG_I2CS
	movf	MON_A1, w, BANKED
	sublw	'y'
	btfsc	_Z
	return ; bra	DEBUG_I2CS_irq
#endif

	movf	MON_A1, w, BANKED
	sublw	a'+' ; 2B
	bz	MonI_add	; got ,+

	movf	MON_A1, w, BANKED
	sublw	a'-'
	bz	MonI_sub	; got ,-

	movf	MON_A1, w, BANKED
	sublw	a'l'
	bz	mon_Fsh	; got ,l

	movf	MON_A1, w, BANKED
	sublw	a'L'
	bz	Set_FSR		; got ,L

	movf	MON_A1, w, BANKED
	andlw	b'10011111'	; all capitals
	sublw	0x1a 		; ctrl + a'Z'
	bz	MON_Dump8	; got ,Z or 'z'

	movf	MON_A1, w, BANKED
	sublw	a's'
	bz	K_PrintStat

	movf	MON_A1, w, BANKED
	sublw	a'g'
	bz	Mon_Go

	btfss	KB_gotnum	
	bra	K_Print_Err	; so make sure we got some

	movf	MON_A1, w, BANKED
	sublw	a'p'
	btfsc	_Z
	bra	mon_Pfr		; got ARG,p

	bra	K_Print_Err	; error
;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
;Monitor_function_calls
;~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
Mon_Go	bra	rMon_go
	;return

MonI_add
	rcall	K_MON_swapFSRm
	incf	MON_INDF,f
	bra	MonI_s1

MonI_sub
	rcall	K_MON_swapFSRm
	decf	MON_INDF,f
MonI_s1	movf	MON_INDF, w
	rcall	K_PrintHex
	bra	K_MON_swapFSRm

mon_Fsh	movf	KV_MON_readnum, w, BANKED
	btfsc	KB_gotnum
	movwf	KV_MON_atL, BANKED
Mon_shw	rcall	K_PrintNl
	movlw	a'D'
	rcall	K_PrintW
	movlw	a':'
	rcall	K_PrintW
	rcall	K_MON_swapFSRm
	movf	MON_INDF, w
	rcall	K_PrintHex
	rcall	K_MON_swapFSRm
	bra	K_PrintP

mon_Pfr	rcall	K_MON_swapFSRm
	movf	KV_MON_readnum, w, BANKED
	movwf	MON_INDF
	rcall	K_MON_swapFSRm
	bra	K_PrintP

Set_FSR	movf	KV_MON_readnum, w, BANKED
	btfsc	KB_gotnum
	movwf	KV_MON_atH, BANKED
ShowFSR	rcall	K_PrintNl
	movlw	a'L'
	rcall	K_PrintW
	movlw	a':'
	rcall	K_PrintW
	movf	KV_MON_atH, w, BANKED
	rcall	K_PrintHex
	movf	KV_MON_atL, w, BANKED
	rcall	K_PrintHex
	bra	K_PrintP

;===========================================================
DUMPLEN=.16
MON_Dump8
;===========================================================
	rcall	K_MON_swapFSRm
	movf	KV_MON_readnum, w, BANKED
	btfsc	KB_gotnum
	movwf	MON_FSRl

	btfsc	MON_A1, 6, BANKED	; CTRL-Z
	bra	MOND8m			; not minus

	movlw	DUMPLEN			; FSR-=DUMPLEN
	subwf	MON_FSRl, f
	bc	MOND8
	decf	MON_FSRh, f
	bra	MOND8

MOND8m	btfsc	MON_A1, 5, BANKED	; SHIFT-Z
	bra	MOND8			; not plus
					; add DUMPLEN to next go
	movlw	DUMPLEN			; FSR-=DUMPLEN
	addwf	MON_FSRl, f
	bnc	MOND8
	btfsc	_C
	incf	MON_FSRh, f
	;+bra	MOND8

MOND8	rcall	K_PrintNl		; just Z ( and ':' 0x3a )
	movf	MON_FSRh, w
	rcall	K_PrintHex
	movf	MON_FSRl, w
	rcall	K_PrintHex
	movlw	a':'
	rcall	K_PrintW

	movlw	DUMPLEN
	movwf	KV_MON_readnum, BANKED
MOND81	movf	MON_POSTINC, w
	rcall	K_PrintHex
	decfsz	KV_MON_readnum, f, BANKED
	bra	MOND81

	movlw	DUMPLEN			; rewind FSR
	subwf	MON_FSRl, f
	btfss	_C
	decf	MON_FSRh, f

	bra	K_MON_swapFSRm

;===========================================================
K_PrintStat
;===========================================================
	rcall	K_PrintNl
	;+banksel VBANK1
	movf	KV_MON_Err_Code, w , BANKED
	bnz	MonPe_1
	movlw	a'O'
	rcall	K_PrintW
	movlw	a'K'
	rcall	K_PrintW
	bra	MonPe_2
MonPe_1	movlw	a'E'
	rcall	K_PrintW
	movlw	a'r'
	rcall	K_PrintW
	movlw	a'r'
	rcall	K_PrintW
MonPe_2	movlw	a' '
	rcall	K_PrintW
	movf	KV_MON_Err_Mod, w, BANKED; module
	rcall	K_PrintW
	movlw	a':'
	rcall	K_PrintW
	movf	KV_MON_Err_Code, w, BANKED; Error code
	rcall	K_PrintHex
	movlw	a'@'
	rcall	K_PrintW
	movf	KV_MON_Err_LiH, w, BANKED; LinesH
	rcall	K_PrintHex
	movf	KV_MON_Err_LiL, w, BANKED; LinesL
	rcall	K_PrintHex
	movlw	a':'
	rcall	K_PrintW
	movf	KV_MON_Err_Got, w , BANKED; Byte that I dont like
	rcall	K_PrintHex
	movlw	a'/'
	rcall	K_PrintW
	movf	KV_MON_Err_Exp, w , BANKED; Bytes that I wanted
	rcall	K_PrintHex
	movlw	a'+'
	rcall	K_PrintW
	movf	KV_MON_ChaH, w, BANKED	; changes done
	rcall	K_PrintHex
	movf	KV_MON_ChaL, w, BANKED 	
	rcall	K_PrintHex
	bra	K_PrintP
	;+return

;===========================================================
K_MON_swapFSRm
;===========================================================
	BANKSEL	VBANK1
	movf	FSR1L, w
	xorwf	KV_MON_atL, w, BANKED
	xorwf	FSR1L, f
	xorwf	KV_MON_atL, f, BANKED
	movf	FSR1H, w
	xorwf	KV_MON_atH, w, BANKED
	xorwf	FSR1H, f
	xorwf	KV_MON_atH, f, BANKED
	return

;===========================================================
K_MON_swapTBL
;===========================================================
	BANKSEL	VBANK1
	movf	TBLPTRU,   w
	xorwf	TBLPTRU_s, w, BANKED
	xorwf	TBLPTRU,   f
	xorwf	TBLPTRU_s, f, BANKED

	movf	TBLPTRH,   w
	xorwf	TBLPTRH_s, w, BANKED
	xorwf	TBLPTRH,   f
	xorwf	TBLPTRH_s, f, BANKED

	movf	TBLPTRL,   w
	xorwf	TBLPTRL_s, w, BANKED
	xorwf	TBLPTRL,   f
	xorwf	TBLPTRL_s, f, BANKED
	return

K_Version	; got ,V
;===========================================================
	rcall	K_MON_swapTBL
	PrintTBL Version
	rcall	K_MON_swapTBL
	bra	K_PrintP
Version	DB	VerStr

;===========================================================
K_PrintTBLi ; indexed
;===========================================================
	movwf	TBLPTRL
	TBLRD*+
	movf	TABLAT, w	; len

K_PrintTBL ; w=len
	movwf	MON_A1, BANKED

Mon_PTl	TBLRD*+
	movf	TABLAT, w
	rcall	K_PrintW
	decfsz	MON_A1, f, BANKED
	bra	Mon_PTl
	return
	
;===========================================================
K_showTBL
;===========================================================
	rcall	K_PrintNl
K_sshowTBL
	movlw	'T'
	rcall	K_PrintW
	movlw	'B'
	rcall	K_PrintW
	movlw	'L'
	rcall	K_PrintW
	movlw	':'
	rcall	K_PrintW
	movf	TBLPTRU, w
	rcall	K_PrintHex
	movf	TBLPTRH, w
	rcall	K_PrintHex
	movf	TBLPTRL, w
	rcall	K_PrintHex
	movlw	'='
	rcall	K_PrintW
	movf	TABLAT, w
	TBLRD*
	rcall	K_PrintHex
	bra	K_PrintNl
;

K_PrintBit
        banksel MON_A1
        movwf   MON_A1, BANKED
        movlw   a'b'
        rcall   K_PrintW
        movlw   .8
        movwf   MON_A2, BANKED
Mon_pbc rlcf    MON_A1, f, BANKED
        movlw   '0'
        btfsc   _C
        movlw   '1'
        rcall   K_PrintW
        decfsz  MON_A2, f, BANKED
        bra     Mon_pbc
        return


#endif ; }
