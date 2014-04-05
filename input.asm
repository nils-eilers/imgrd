	.import GETIN, BSOUT, CRLF, READY
	.importzp KEY, CURSOR, BLINK, CHAR, CURSP, CURAD
	.import user_abort

	.export flashget, flashscreen, wrongkey, yesno

	.include "petscii.inc"
	.include "6502.inc"

	ptr	:= $3C


;--------------------------------------------------------------------------
; FLASHGET: Wait for key with flashing cursor > A
;--------------------------------------------------------------------------
flashget:
	lda KEY
	sta CURSOR
	beq flashget
	sei
	lda BLINK
	beq fg80
	lda CHAR
	ldy #0
	sty BLINK
	ldy CURSP
	sta (CURAD),y
fg80:	jsr_rts GETIN


wrongkey:
;--------------------------------------------------------------------------
; FLASHSCREEN
;--------------------------------------------------------------------------
flashscreen:
	jsr invertscreen
	jsr delay
	jsr invertscreen
	rts


	SCREEN = $8000

invertscreen:
	lday SCREEN
	stay addr_load
	stay addr_store
is10:	ldx #0
	addr_load = *+1
is20:	lda SCREEN,x
	eor #$80
	addr_store = *+1
	sta SCREEN,x
	inx
	bne is20
	ldx addr_load+1
	inx
	stx addr_load+1
	stx addr_store+1
	cpx #>SCREEN + 9
	bne is10
	rts

delay:	ldx #0
	ldy #50
dl10:	inx
	bne dl10
	dey
	bne dl10
	rts


;--------------------------------------------------------------------------
; YESNO
; [in]	A (lsb), Y(msb) ptr to flag
; [out]	flag in A
; 	STOP aborts
;--------------------------------------------------------------------------
yesno:
	stay ptr
	ldy #0
	lda (ptr),y
	beq yn10
	lda #'Y'
	skip2
yn10:	lda #'N'
yn30:	jsr BSOUT
	lda #CURLF
	jsr BSOUT
yn35:	jsr flashget
	cmp #STOP
	bne yn37
	jmp user_abort
yn37:	cmp #'Y'
	beq yn40
	cmp #'N'
	beq yn50
	cmp #CR
	beq yn60
	jsr wrongkey
	jmp yn35
yn40:	jsr BSOUT
	lda #1
	bne yn55
yn50:	jsr BSOUT
	lda #0
yn55:	ldy #0
	sta (ptr),y
yn60:	jsr CRLF
	ldy #0
	lda (ptr),y
	rts
