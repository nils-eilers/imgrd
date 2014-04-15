	.include "6502.inc"
	.include "petscii.inc"

	.import		BSOUT
	.importzp	STRADR, tmp_X, tmp_Y
	.export		STROUTZ, STROUTZ_right, locate, spaces


;--------------------------------------------------------------------------
; STROUTZ:	output zero terminated string of any size
; in:		A -- lsb pointer to string
;		Y -- msb pointer to string
; out:		A = 0
;		Y = 0
; changes:	STRADR, STRADR + 1
;--------------------------------------------------------------------------

STROUTZ:
	sta STRADR			; store pointer to string
	sty STRADR+1
	ldy #0

@next:	lda (STRADR),y			; get next character
	beq @return			; return on zero character
	jsr BSOUT			; output character
	inc STRADR			; advance pointer
	bne @next
	inc STRADR+1
	bne @next			; and again

@return:
	rts



STROUTZ_right:
	sta STRADR			; store pointer to string
	sty STRADR+1
	ldy #0

@next:	lda (STRADR),y			; get next character
	beq @return			; return on zero character
	cmp #CR
	beq @do_CR
	jsr BSOUT			; output character
@incp:	inc STRADR			; advance pointer
	bne @next
	inc STRADR+1
	bne @next			; and again
@return:
	rts

@do_CR:	ldx #20
	stx tmp_X
	jsr BSOUT
@do_lp:	lda #CURRT
	jsr BSOUT
	dec tmp_X
	bne @do_lp
	beq @incp




;--------------------------------------------------------------------------
; SPACES	X < number of spaces to output
;--------------------------------------------------------------------------
spaces:	stx tmp_X
	beq spc80
spc10:	lda #' '
	jsr BSOUT
	dec tmp_X
	bne spc10
spc80:	rts
	




;--------------------------------------------------------------------------
; LOCATE	X < colum 0..39/79
;		Y < row 0..23
; slow but portable, uses HOME, CR and CURSOR RIGHT
;--------------------------------------------------------------------------
locate:
	stx tmp_X
	sty tmp_Y
	lda #HOME
	jsr BSOUT
lc10:	ldy tmp_Y
	beq lc20
	lda #CR
	jsr BSOUT
	dec tmp_Y
	bne lc10
lc20:	ldx tmp_X
	beq lc80
	lda #CURRT
	jsr BSOUT
	dec tmp_X
	bne lc20
lc80:	rts
