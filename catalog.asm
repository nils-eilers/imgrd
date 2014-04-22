	.include "6502.inc"	
	.include "petscii.inc"

	.import OPENI, TALK, ACPTR, INTOUT, SCROUT, GETIN, CRLF, READY
	.import CLSEI, SECND, STOPEQ, CLSEI, OPENI, SCROUT, STROUTZ
	.import init_drive, get_ds, print_ds
	.importzp DN, SA, FNLEN, FNADR, STATUS, MEMUSS
	.importzp linecounter

	.export catalog, waitkey, continue_or_abort

	LINES = 24

;----------------------------------------------------------------------------
; CATALOG		A < drive
;			Y < unit
;----------------------------------------------------------------------------

catalog:

	sty DN
	tax
	clc
	adc #'0'
	sta str_catdrv
	txa

	; init drive
	; this fails with 66,ILLEGAL TRACK OR SECTOR if a 8050 formatted disk
	; was inserted in a 8250 but will trigger the 8050 mode and the
	; following catalog will work
	jsr init_drive			

	lda #LINES
	sta linecounter
	lda #CLRHOME
	jsr SCROUT
	ldy #2
	sty FNLEN			; store length
	lday str_cat
	stay FNADR			; set filename

	lda #$60			; DATA SA 0
	sta SA
	jsr OPENI			; open file
	jsr TALK
	lda SA
	jsr SECND
	lda #0
	sta STATUS

	ldy #3
list_blocks:
	sty FNLEN
	jsr ACPTR
	sta MEMUSS			; store blocks LSB
	ldy STATUS
	bne to_stoplisting
	jsr ACPTR
	sta MEMUSS + 1			; store blocks MSB
	ldy STATUS
	bne to_stoplisting
	ldy FNLEN
	dey 
	bne list_blocks
	ldx MEMUSS
	lda MEMUSS + 1
	jsr INTOUT			; write #blocks to screen
	lda #' '
	bne listing			; branch always

;----------------------------------------------------------------------------
; 6502 wasn't made for writing relative code :(
to_stoplisting:	bne stoplisting
to_list_blocks:	bne list_blocks
;----------------------------------------------------------------------------

listing:
	jsr SCROUT
lst10:	jsr ACPTR			; read byte from IEEE
	ldx STATUS
	bne stoplisting
	cmp #0
	beq newline
	jsr SCROUT			; write filename and type
	jsr STOPEQ			; abort listing with STOP key
	beq abort
	jsr GETIN			; pause listing with SPACE key
	beq lst10			; no key pressed -> continue
	cmp #' '			; =space?
	bne lst10			; only space pauses listing
lst30:	jsr GETIN
	beq lst30			; wait for any key
	bne lst10			; then continue

newline:	
	lda #CR
	jsr SCROUT
	dec linecounter
	bne nl10
	lda #LINES
	sta linecounter
	jsr continue_or_abort
	beq abort
	lda #CLRHOME
	jsr SCROUT
	
nl10:	ldy #2
	bne to_list_blocks


stoplisting:
	jsr CLSEI
	jsr get_ds
	bcc sl10
	jsr CRLF
	jsr print_ds
	jsr CRLF
sl10:	jsr_rts waitkey

abort:	jsr_rts CLSEI			; close file with $E0, unlisten


;----------------------------------------------------------------------------
; CONTINUE OR ABORT
; --> zero flag set if user wants to abort
;----------------------------------------------------------------------------
continue_or_abort:
	lday msg_ca
	jsr STROUTZ
:	jsr GETIN
	beq :-
	cmp #STOP
	rts

waitkey:
	lday msg_mn
	jsr STROUTZ
:	jsr GETIN
	beq :-
	jsr_rts CRLF


.data
str_cat:	.byte "$"
str_catdrv:	.byte "0"

.rodata
msg_ca:		.byte RVSON, "ANY KEY", RVSOFF, " TO CONTINUE, "
		.byte RVSON, "STOP", RVSOFF, " TO ABORT", 0
msg_mn:		.byte RVSON, "ANY KEY", RVSOFF, " TO RETURN TO MENU", 0
