	.include "6502.inc"	
	.include "petscii.inc"

	.import OPENI, TALK, ACPTR, INTOUT, SCROUT, GETIN, CRLF, READY
	.import CLSEI, SECND, STOPEQ, CLSEI, OPENI, SCROUT, STROUTZ
	.importzp DN, SA, FNLEN, FNADR, STATUS, MEMUSS
	.importzp linecounter

	.import menu
	.export catalog, str_catdrv, waitkey

	LINES = 24

;----------------------------------------------------------------------------
; CATALOG
;----------------------------------------------------------------------------

catalog:
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
nl10:	ldy #2
	bne to_list_blocks


stoplisting:
	jsr waitkey
abort:	jsr CLSEI			; close file with $E0, unlisten
	jsr CRLF
	jmp menu

continue_or_abort:
	lday msg_any_key
	jsr STROUTZ
	lday msg_stop
	jsr STROUTZ
:	jsr GETIN
	beq :-
	pha
;	jsr CRLF
	lda #CLRHOME
	jsr SCROUT
	pla
	cmp #STOP
	bne ca80
	pla				; drop return address
	pla
	jmp menu
ca80:	rts

waitkey:
	lday msg_any_key_mn
	jsr STROUTZ
:	jsr GETIN
	beq :-
	jsr_rts CRLF


.data
str_cat:	.byte "$"
str_catdrv:	.byte "0"

.rodata
msg_any_key:	.byte RVSON, "ANY KEY", RVSOFF, " TO CONTINUE", 0
msg_any_key_mn:	.byte RVSON, "ANY KEY", RVSOFF, " TO RETURN TO MENU", 0
msg_stop:	.byte ", ", RVSON, "STOP", RVSOFF, " TO ABORT", 0

