	.import BSOUT	

	.export mul10, itoa
	.export digits
	.export digit_tenthousands, digit_thousands, digit_hundreds
	.export digit_tens, digit_ones, myintout

;--------------------------------------------------------------------------
; MUL10					multiply A by 10
;--------------------------------------------------------------------------
mul10:	sta tmp
	asl a
	asl a
	clc
	adc tmp
	asl a
	rts

.bss
tmp:	.res 1
.code


;--------------------------------------------------------------------------
; ITOA					X < LSB
; Convert unsigned 16 bit integer	A < MSB
; to ASCII digitsi			> digits .. digits + 4
;--------------------------------------------------------------------------
itoa:
	ldy #'0'-1
	sec
c10000:	iny
	stx tmpl
	sta tmpm
	txa
	sbc #<10000
	tax
	lda tmpm
	sbc #>10000
	bcs c10000
	sty digits
	ldx tmpl
	lda tmpm

	ldy #'0'-1
	sec
c1000:	iny
	stx tmpl
	sta tmpm
	txa
	sbc #<1000
	tax
	lda tmpm
	sbc #>1000
	bcs c1000
	sty digits+1
	ldx tmpl
	lda tmpm
	
	ldy #'0'-1
	sec
c100:	iny
	stx tmpl
	sta tmpm
	txa
	sbc #100
	tax
	lda tmpm
	sbc #0
	bcs c100
	sty digits+2

	lda tmpl
	ldy #'0'-1
	sec
c10:	iny
	sbc #10
	bcs c10
	sty digits+3
	adc #'9'+1
	sta digits+4

	rts

;--------------------------------------------------------------------------
; MYINTOUT				X < LSB
; Print unsigned 16 bit integer		A < MSB
; w/o loading space
;--------------------------------------------------------------------------
myintout:
	jsr itoa
	ldx #0
mio10:	lda digits,x
	cmp #'0'
	beq mio20
	jsr BSOUT
mio20:	inx
	cpx #5
	bne mio10
	rts

.bss

tmpl:			.res 1
tmpm:			.res 1

digits:
digit_tenthousands:	.res 1
digit_thousands:	.res 1
digit_hundreds:		.res 1
digit_tens:		.res 1
digit_ones:		.res 1

	.end
