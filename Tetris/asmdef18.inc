; vim:syntax=pic
	NOLIST

#ifndef	ASMDEF
	#define	ASMDEF

	#define _Z		STATUS,Z
	#define _C		STATUS,C
	#define _DC		STATUS,DC
	#define _N		STATUS,N
	#define _OV		STATUS,OV

Dcall	macro	DEST
	call	DEST
	btfsc	_C
	return
	endm

Drcall	macro	DEST
	rcall	DEST
	btfsc	_C
	return
	endm

#endif
;=========================
; wait_macros
;=========================

IT=.10000000/(freq/.4000)	; instruktion time in 1/10 nS (48mhz= 833 10/nS)
maxline=2


waitMS	MACRO TIME	; time is in 1/10 ms (=100us -> ?ms)
INST=((TIME*.1000*.10)/IT)	; calc num of 1000 inst. to waste (depends on FREQ)
  if INST<.250
     ERROR "waitMS if not good for short delays, Plz. use waitNS"
  endif
  if INST>0x106FA
        ERROR "too long wait"
  endif
  if INST>.1;252500; && INST<.
	local IG=INST/.263
	local INST=INST-(IG*.263)
	if IG<0xff && INST>0
	local IG=IG+1
	local INST=INST-.263
	endif
	movlw	IG
	rcall	HW_wait_2
  endif
	ENDM

waitNS	MACRO TIME ; {	; time is in 1/10 ms (=100us -> ?ms)
INST=((TIME*.10)/IT)	; calc num of inst. to waste (depends on FREQ)
  local lines=maxline
  if INST>.263181
        ERROR "too long wait; use waitMS"
  endif
  if lines>=2 && INST>.1023; && INST<.263181
	local lines=lines-2
	local INST=INST-.14
	local IG=INST/.1028
	local INST=INST-(IG*.1028)
	if !lines && IG<0xff && INST>0
	local IG=IG+1
	local INST=INST-.1028
	endif
	movlw	IG
	rcall	HW_wait_1
  endif
  if lines>=2 && INST>.14 ;&& INST<=.1035
	local lines=lines-2
	local INST=INST-.14
	if INST<=0
	local IG=0
	else
	local IG=(INST)/.4
	local INST=INST-(IG*.4)
	endif
	if !lines && IG<0xff && INST>0
	local IG=IG+1
	local INST=INST-.4
	endif
	movlw	IG
	rcall	HW_wait_0
  endif
  if lines&& INST>=.4
	local lines=lines-1
	rcall	MRETURN
	local INST=INST-4
  endif
  if lines && INST>=.4
	rcall	MRETURN
	local INST=INST-4
	local lines=lines-1
  endif
  if lines && INST>=.2
	bra $+2
	local INST=INST-2
	local lines=lines-1
  endif
  if lines && INST>=.1
	local lines=lines-1
	nop
  endif
	endm ; }
waitUS	MACRO TIME	; time is in 1/10 ms (=100us -> ?ms)
	waitNS TIME*.1000
	ENDM

wait_for_it	MACRO	; install wait code

HW_wait_0
	movwf	HV_wait0
	bra	HW_ws
HW_wait_1
	movwf	HV_wait1
	bra	HW_ws
HW_wait_2
	movwf	HV_wait2
	bra	HW_ws
wait_some
HW_ws2	decf	HV_wait2,f
HW_ws1	decf	HV_wait1,f
HW_ws0	decf	HV_wait0,f
HW_ws	tstfsz	HV_wait0
	bra	HW_ws0
	tstfsz	HV_wait1
	bra	HW_ws1
	tstfsz	HV_wait2
	bra	HW_ws2
	return

	ENDM

; DEBUG & PRINT macros
PrintTBL	macro	STRING
	movlw	upper  (STRING)
	movwf	TBLPTRU
	movlw	high  (STRING)
	movwf	TBLPTRH
	movlw	low   (STRING)	
	rcall	K_PrintTBLi
	endm

#define _DEBUG		Debugv, 0
#ifndef	DEBUG
DEBUG=0
#endif

DEBUG_C macro charA
#if DEBUG>0
#if DEBUG<2
	btfss	_DEBUG
	bra	DEBUG_END
#endif ; DEBUG<2
	movwf	DebugW
	movlw	charA
	call	K_PrintW
	movf	DebugW, w
	LOCAL DEBUG_END=$
#endif ; DEBUG
	endm

DEBUG_2C macro charA, charB
#if DEBUG>0
#if DEBUG<2
	btfss	_DEBUG
	bra	DEBUG_END
#endif ; DEBUG<2
	movwf	DebugW
	movlw	charA
	call	K_PrintW
	movlw	charB
	call	K_PrintW
	movf	DebugW, w
	LOCAL DEBUG_END=$
#endif ; DEBUG
	endm
DEBUG_H  macro
#if DEBUG>0
#if DEBUG<2
	btfss	_DEBUG
	bra	DEBUG_END
#endif ; DEBUG<2
	movwf	DebugW
	call	K_PrintHex
	movf	DebugW, w
	LOCAL DEBUG_END=$
#endif ; DEBUG
	endm

DEBUG_HN  macro
#if DEBUG>0
#if DEBUG<2
	btfss	_DEBUG
	bra	DEBUG_END
#endif ; DEBUG<2
	movwf	DebugW
	call	K_PrintHex	;H
	call	K_PrintNl		;N
	movf	DebugW, w
	LOCAL DEBUG_END=$
#endif ; DEBUG
	endm


DEBUG_CH  macro charA
#if DEBUG>0
#if DEBUG<2
	btfss	_DEBUG
	bra	DEBUG_END
#endif ; DEBUG<2
	movwf	DebugW
	movlw	charA
	call	K_PrintW
	movf	DebugW, w
	call	K_PrintHex
	movf	DebugW, w
	LOCAL DEBUG_END=$
#endif ; DEBUG
	endm

DEBUG_CN macro charA
#if DEBUG>0
#if DEBUG<2
	btfss	_DEBUG
	bra	DEBUG_END
#endif ; DEBUG<2
	movwf	DebugW
	movlw	charA
	call	K_PrintW
	call	K_PrintNl
	movf	DebugW, w
	LOCAL DEBUG_END=$
#endif ; DEBUG
	endm

DEBUG_N macro
#if DEBUG>0
#if DEBUG<2
	btfss	_DEBUG
	bra	DEBUG_END
#endif ; DEBUG<2
	movwf	DebugW
	call	K_PrintNl
	movf	DebugW, w
	LOCAL DEBUG_END=$
#endif ; DEBUG
	endm

DEBUG_VAR macro VAR_name, VAR
#if	DEBUG>0
#if	DEBUG<2
	btfss	_DEBUG
	bra	DEBUG_END
#endif
	movwf	DebugW
	call	K_PrintNl
	movlw	VAR_name 
	call	K_PrintW
	movlw	':'
	call	K_PrintW
	movff	VAR, WREG
	call	K_PrintHex
	movf	DebugW, w
	LOCAL DEBUG_END=$
#endif ; DEBUG
	endm

DEBUG_VAR16 macro VAR_name, VAR, VAR1
#if	DEBUG>0
#if	DEBUG<2
	btfss	_DEBUG
	bra	DEBUG_END
#endif
	movwf	DebugW
	movlw	VAR_name 
	call	K_PrintW
	movlw	':'
	call	K_PrintW
	movff	VAR, WREG
	call	K_PrintHex
	movff	VAR1, WREG
	call	K_PrintHex
	movf	DebugW, w
	LOCAL DEBUG_END=$
#endif ; DEBUG
	endm

DEBUG_sVAR macro VAR
#if	DEBUG>0
#if	DEBUG<2
	btfss	_DEBUG
	bra	DEBUG_END
#endif
	movwf	DebugW
	movff	VAR, WREG
	call	K_PrintHex
	movf	DebugW, w
	LOCAL DEBUG_END=$
#endif ; DEBUG
	endm
	LIST
