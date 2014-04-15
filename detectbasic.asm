;--------------------------------------------------------------------------
; BASVER -- detect BASIC version and jump to corresponding labels
; --> basic1
; --> basic2
; --> basic4
; --> basicunknown
;
; Inspired by code from Michael Sachse found at
; http://www.cbmhardware.de/cbmwiki/index.php/Detect_CBM
;--------------------------------------------------------------------------


        .export __BASVER__: absolute = 1

.segment "BASVER"

detectbasic:
	lda $e1c4	; check first '#' of "### commodore basic ###"
	cmp #$23
	bne basic4or1
	jmp basic2_detected

basic4or1:
	lda $e180	; check first '*' of "*** commodore basic ***"
	cmp #$2a
	bne basic4
	jmp basic1_detected

basic4:
	lda $dea4	; check first '*' of "*** commodore basic 4.0 ***"
	cmp #$2a
	bne unknown
	jmp basic4_detected

unknown:
	jmp unknown_basic_version



	.include "6502.inc"
	.include "petscii.inc"
	.import STROUTZ, main

;--------------------------------------------------------------------------
; UNKNOWN BASIC VERSION, ABORT
;--------------------------------------------------------------------------
.code
unknown_basic_version:
	lday detunknown
	jsr_rts STROUTZ             ; print message and return to BASIC

.rodata
detunknown:	.byte "UNABLE TO DETECT BASIC VERSION", CR, 0

;--------------------------------------------------------------------------
; BASIC 1: UNSUPPORTED
;--------------------------------------------------------------------------
.code
basic1_detected:
	lday detb1
	jsr_rts STROUTZ             ; print message and return to BASIC

.rodata
detb1:		.byte "SORRY, BASIC 1 IS NOT SUPPORTED", CR, 0

;--------------------------------------------------------------------------
; BASIC 2
; overwrite addresses in jump table with values appropiate for BASIC 2
; FIXME: untested code
;--------------------------------------------------------------------------
.code
	.importzp MOVSRC, MOVTEND, MOVSEND
basic2_detected:
	lday BASIC2_vectors_start
	stay MOVSRC		; pointer to vectors
	lday BASIC4_jump_table_start+1
	stay MOVTEND		; pointer to addresses in jump table
	lda #(BASIC2_vectors_end - BASIC2_vectors_start)/2
	sta MOVSEND		; vector counter
	
	ldy #0
copy:
	lda (MOVSRC),y		; copy LSB
	sta (MOVTEND),y
	inc MOVSRC
	bcc @nocarry
	inc MOVSRC+1
@nocarry:
	inc MOVTEND
	bcc @nocarry2
	inc MOVTEND+1
@nocarry2:
	lda (MOVSRC+1),y	; copy MSB
	sta (MOVTEND),y
	inc MOVSRC+1
	inc MOVTEND+1
	inc MOVTEND		; skip JMP
	bcc @nocarry3
	inc MOVTEND+1
@nocarry3:
	dec MOVSEND
	bne copy
	; fall through
;--------------------------------------------------------------------------
; BASIC 4
;--------------------------------------------------------------------------
basic4_detected:
	; jump table defaults to BASIC 4: nothing to do
        jmp main


;--------------------------------------------------------------------------
; BASIC 4 jump table (default)
;--------------------------------------------------------------------------

.segment "JUMPTABLE"
.export ACPTR, CIOUT, CLOSE, CRLF, INTOUT, HEXOUT, LISTN, OPEN, READY, SECND
.export SPAC2, SPACE, STOPEQ, TALK, UNLSN, UNTLK, SCNT, SETT, STROUT, CLSEI
.export OPENI, SCROUT

; this assembler should allow splitting long lines :-/
.assert ((BASIC4_jump_table_end-BASIC4_jump_table_start)/3)=((BASIC2_vectors_end-BASIC2_vectors_start)/2), error, "Number of ROM entries for BASIC 2 / 4 mismatch"

BASIC4_jump_table_start:

ACPTR:	jmp $f1c0
CIOUT:	jmp $f19e
CLOSE:	jmp $f2e0
CLSEI:	jmp $f72f ; close and unlisten
CRLF:	jmp $d534
HEXOUT:	jmp $d722
INTOUT:	jmp $cf83
LISTN:	jmp $f0d5
OPEN:	jmp $f563
OPENI:	jmp $f4a5 ; open file on IEEE device
READY:	jmp $b3ff
SCNT:	jmp $f2c1
SCROUT:	jmp $e202 ; output A to screen
SECND:	jmp $f143
SETT:	jmp $f2cd
SPAC2:	jmp $d52e
SPACE:	jmp $d531
STOPEQ:	jmp $f335
STROUT:	jmp $bb24
TALK:	jmp $f0d2
UNLSN:	jmp $f1b9
UNTLK:	jmp $f1b6

BASIC4_jump_table_end:

;--------------------------------------------------------------------------
; BASIC 2 jump table
;--------------------------------------------------------------------------

.rodata

BASIC2_vectors_start:

	.word $f18c	; ACPTR
	.word $f16f	; CIOUT
	.word $f2ac	; CLOSE
	.word $f6f0	; CLSEI
	.word $fdd0	; CRLF
	.word $e775	; HEXOUT
	.word $dcd9	; INTOUT
	.word $f0ba	; LISTN
	.word $f524	; OPEN
	.word $f466	; OPENI
	.word $c389	; READY
	.word $f28d	; SCNT
	.word $e3d8	; SCROUT
	.word $f128	; SECND
	.word $f299	; SETT
	.word $fdca	; SPAC2
	.word $fdcd	; SPACE
	.word $f301	; STOPEQ
	.word $ca23	; STROUT
	.word $f0b6	; TALK
	.word $f183	; UNLSN
	.word $f17f	; UNTLK

BASIC2_vectors_end:

.end
