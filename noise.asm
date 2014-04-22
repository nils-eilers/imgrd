;--------------------------------------------------------------------------
; NOISE
;--------------------------------------------------------------------------

	.include "6502.inc"
	.include "petscii.inc"
	.import BSOUT
	.export play_fanfare, play_requiem, shutup

; TODO: BASIC 2 compatible version
; TODO: what the name says

play_fanfare:
	ldx #16
	skip2
play_requiem:
	ldx #50
	lda 231
	pha
	stx 231
	lda #BELL
	jsr BSOUT
	pla
	sta 231

shutup:
	rts
	

