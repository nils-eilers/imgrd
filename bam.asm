	.include "6502.inc"
	.include "petscii.inc"
	.include "cbmdos.inc"
	.import STROUTZ, HEXOUT, CRLF, SPACE
	.import print_OK, print_bad_blocks, getblkptr1, print_TS
	.import rd_trk, rd_sec, bamonly, errcnt
	.importzp ptr1
	.export rdbam, blkused
	.export vect_rdbam, rdbamd64, rdbamd80, rdbamd82
	.export vect_blkused, blkused_d64, blkused_8x50

;--------------------------------------------------------------------------
; RDBAM
;--------------------------------------------------------------------------
rdbam:
	lda #0
	sta badbam			; set number of bad BAMs to 0

	lday bam1			; init read ptr for BAM blocks
	stay ptr1

	lday msg_rdbam
	jsr STROUTZ

	jsr do_rdbam

	ldx badbam			; print OK / n BAD BLOCKS
	beq :+
	jmp brokenbam
:	jsr_rts print_OK

do_rdbam:
	jmp (vect_rdbam)		; poor man's JSR (indirect)

brokenbam:
	stx errcnt
	lda #0
	sta errcnt+1
	jsr_rts print_bad_blocks

rdbamd64:
	lda #18
	ldx #0
	beq rdbba			; branch always

rdbamd80:
	ldx #0
	jsr rdbb38
	ldx #3
	bne rdbb38			; branch always

rdbamd82:
	jsr rdbamd80
	ldx #6
	jsr rdbb38
	ldx #9
	bne rdbb38			; branch always

rdbb38:	lda #38				; read BAM block from track 38
rdbba:	sta rd_trk			; read BAM block from track in A
	stx rd_sec
	jsr getblkptr1			; Read block to (ptr1)
	inc ptr1+1			; increment ptr1 page for next BAM
	cmp #FDC_OK+1
	bcc :+
	inc badbam			; increment bad BAM counter
:	rts


;--------------------------------------------------------------------------
; BLKUSED				A < track  (1..n)
; Checks BAM table to lookup		X > sector (0..n)
; if the given block is used
; 					Carry set   > block free
; 					Carry clear > block used
; If bamonly indicates to read all blocks, or if a BAM is on a bad block,
; this subroutine will always indicates "block used" by setting carry.
;--------------------------------------------------------------------------
blkused:
	ldy bamonly
	bne bu20
bu10:	clc
	rts
bu20:	ldy badbam
	bne bu10

	tay
	dey
	tya				; track 1..n --> 0..n
	jmp (vect_blkused)

blkused_d64:
	asl				; track * 4
	asl
	sta ptr1

	txa
	lsr
	lsr
	lsr				; sector / 8
	clc
	adc ptr1
	tay
	lda bam1+4,y
	
bu30:	tay
	txa				; sector % 8 used as counter
	and #7				; for shifting bits
	tax
	tya

bu40:	lsr				; shift BAM bits into carry flag
	dex
	bpl bu40
	rts

blkused_8x50:
	ldy #>bam1			; set ptr1 to one of the 4 BAMs
bu50:	cmp #50
	bcc bu60			; branch if track < 50
	iny				; increment BAM number
	sbc #50
	bcs bu50			; branch always
bu60:	sty ptr1+1

; ptr1 points to the appropiate BAM, A=trk (0..49), X=sec
	sta ptr1
	asl				; track (0..49) * 5
	asl
	clc
	adc ptr1
	adc #7				; skip BAM prologue
	sta ptr1

	txa
	lsr
	lsr
	lsr				; sector / 8
	tay

.ifdef DEBUG_BAM
	stx tmp_sec
	pha
	lda ptr1+1
	jsr HEXOUT
	lda ptr1
	jsr HEXOUT
	jsr SPACE
	pla
	jsr HEXOUT
.endif

	lda (ptr1),y

.ifdef DEBUG_BAM
	pha
	jsr HEXOUT
	jsr CRLF
	pla
	ldx tmp_sec
.endif

	jmp bu30

.rodata
msg_rdbam:	.byte "READING BAM: ", 0

.bss
		.align $100
bam1:		.res 256	; block containing BAM #1
bam2:		.res 256	; block containing BAM #2
bam3:		.res 256	; block containing BAM #3
bam4:		.res 256	; block containing BAM #4
vect_rdbam:	.res 2
vect_blkused:	.res 2
badbam:		.res 1		; number of bad BAM blocks

.ifdef DEBUG_BAM
tmp_sec:	.res 1
.endif

