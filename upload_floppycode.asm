;--------------------------------------------------------------------------
; UPLOAD DRIVECODE
; The floppy code (max 255 bytes) is uploaded to device address DN
; in chunks of up to 32 bytes via M-W
;--------------------------------------------------------------------------

	.importzp MOVSRC, MOVSEND
	.import __FLOPPY_LOAD__, __FLOPPY_SIZE__
	.import STROUTZ, LISTN, SECND, UNLSN, CIOUT, STOPR
	.import SPACE, HEXOUT, CRLF
	.import get_ds, print_ds
	.importzp DN, SA, ST
	.export upload_drivecode

	.assert (__FLOPPY_SIZE__ < 256), error, "floppycode too large"
	.assert (<__FLOPPY_LOAD__ = 0), error, "floppycode not page-aligned"

	.include "6502.inc"
	.include "petscii.inc"

	ptr 	:= MOVSRC		; 16 bit pointer to floppy code
	chunk 	:= MOVSEND		; ptr (8 bit lsb) to start of chunk
	
upload_drivecode:
	lday msg_upload			; "UPLOADING DRIVE CODE... "
	jsr STROUTZ

	.ifdef DEBUG
		lda #>__FLOPPY_LOAD__	; print start address
		jsr HEXOUT
		lda #<__FLOPPY_LOAD__
		jsr HEXOUT
		jsr SPACE

		lda #>__FLOPPY_SIZE__	; print floppy code size
		jsr HEXOUT
		lda #<__FLOPPY_SIZE__
		jsr HEXOUT
		jsr CRLF
	.endif

	lda #<__FLOPPY_LOAD__		; Always 0, code is page-aligned
	sta ptr
	sta chunk
	lda #>__FLOPPY_LOAD__
	sta ptr+1

loop:  
	lda chunk			; chunk holds lsb addr of
					; chunk's last byte + 1
	clc				; add 32 to determine start address
	adc #32				; of next chunk

	bne chunknot0			; limit to FLOPPY_SIZE if it
	lda #<__FLOPPY_SIZE__		; wraps around to 0

chunknot0:
	sta chunk
	cmp #<__FLOPPY_SIZE__
	bcc chunkok
	lda #<__FLOPPY_SIZE__
	sta chunk

chunkok:

	lda #0
	sta ST				; ST=0
	jsr LISTN			; LISTEN
	lda #15
	sta SA
	jsr SECND			; send secondary address
	lda #'M'
	jsr CIOUT
	lda #'-'
	jsr CIOUT
	lda #'W'
	jsr CIOUT
	lda ptr				; LSB address
	jsr CIOUT
	lda #$11			; MSB $11xx
	
	lda #<__FLOPPY_SIZE__		; number of bytes left to copy
	sec
	sbc ptr
	cmp #33
	bcc sizefits
	lda #32				; M-W accepts max 34 bytes
sizefits:				; max 32 bytes used here
	.ifdef DEBUG
		pha
		jsr CRLF
		pla
		pha
		jsr HEXOUT
		jsr SPACE
		pla
	.endif
	jsr CIOUT			; tell M-W the number of bytes follwing

sendchunk:
	jsr STOPR

	ldy #0
	lda (ptr),Y			; copy byte to device
	.ifdef DEBUG
		pha
		jsr HEXOUT
		jsr SPACE
		pla
	.endif
	jsr CIOUT

	inc ptr
	lda chunk
	cmp ptr
	bne sendchunk

	jsr UNLSN

	.ifdef DEBUG
		jsr get_ds
		jsr print_ds
	.endif

	lda ptr				; all bytes copied?
	cmp #<__FLOPPY_SIZE__
	bcc loop

	lday msg_ok			; "OK"
	jsr_rts STROUTZ

;--------------------------------------------------------------------------
; STRING CONSTANTS
;--------------------------------------------------------------------------
	.rodata

msg_upload:     .byte "UPLOADING DRIVE CODE... ", 0
msg_ok:         .byte "OK", CR, 0

	.end
