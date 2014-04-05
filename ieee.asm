	.include "6502.inc"		; general 6502 macros
	.include "petscii.inc"

        .import LISTN, TALK, SECND, ACPTR, UNTLK, UNLSN, OPEN, CLOSE
        .import CLRCH, CIOUT, READY, BSOUT, SPACE, SPAC2, INTOUT, STROUTZ
        .import HEXOUT, CRLF
	.import mul10

	.importzp LFN, DN, ST, SA, FNADR, FNLEN

	.export get_ds, print_ds, send_cmd, SETNAM, SETLFS

        ptr = $3C                         ; pointer to command string
        ptr2 = $3E
        

;--------------------------------------------------------------------------
; PRINT DISK STATUS                     DN <-- unit
;--------------------------------------------------------------------------
print_ds:
        lday bufds
        jsr_rts STROUTZ

;--------------------------------------------------------------------------
; GET DISK STATUS                       
;
; DN <-- unit
;
; A = CBM error code (ds)
; Carry flag set on errors
; BUFDS holds zero terminated DS string or DEVICE NOT PRESENT
;--------------------------------------------------------------------------
.proc	get_ds

        jsr TALK                        ; TALK
        lda #$6f                        ; DATA SA 15
        sta SA
        jsr SECND                       ; send secondary address

        lda #0
        sta ptr

nextchar:
        jsr ACPTR                       ; read byte from IEEE bus
        bit ST                          ; check status ST
        bmi dev_not_pr
        ldx ptr
        cmp #CR                         ; last byte = CR?
        beq done
        sta bufds,X
        inx
        stx ptr
        bne nextchar                   ; branch always

dev_not_pr:
        ; TODO: copy "device not present" to bufds
        jsr UNTLK
	brk

done:
        lda #0
        sta bufds,X                     ; zero terminate string
        jsr UNTLK
.endproc
	; fall through
	;
	; convert unsigned ASCII integer to A
	; ignores leading zeroes
	; expects only digits and ',' !
	; 
dsatoi:
	ldx #0
	stx tmpds

dsa10:	lda bufds,x
	cmp #'0'			; ignore leading zeroes
	bne dsa20
	inx
	bne dsa10

dsa20:	cmp #','			; abort on ','
	beq dsa80
	pha
	lda tmpds			; multiply last digit by 10
	jsr mul10
	sta tmpds
	pla
	sec
	sbc #'0'
	clc
	adc tmpds			; add current digit
	sta tmpds
	inx
	lda bufds,x
	bne dsa20			; branch always

dsa80:	clc				; indicate 00,OK
	lda tmpds
	bne dsa85
	rts
dsa85:	sec                             ; indicate error
        rts

.bss
tmpds:	.res 1
.code



;--------------------------------------------------------------------------
; SEND COMMAND                          AY <-- ptr to cmd string
;                                       DN <-- unit
;--------------------------------------------------------------------------
.proc	send_cmd

        sta ptr
        sty ptr+1
        .ifdef DEBUG                    ;  8:CMD
           lda #'@'
           jsr BSOUT
           ldx DN
           lda #0
           jsr INTOUT
           lda #':'
           jsr BSOUT
           lda ptr
           ldy ptr+1
           jsr STROUTZ
           jsr CRLF
        .endif
        lda #$6f                        ; DATA SA 15
        sta SA
        jsr LISTN                       ; LISTEN
        lda SA
        jsr SECND                       ; send secondary address

nextchar:
        ldy #0
        lda (ptr),Y
        beq done
        inc ptr
        bne nocarry
        inc ptr+1
nocarry:
        jsr CIOUT                       ; send char to IEEE
        jmp nextchar

done:
        jsr_rts UNLSN

.endproc


;--------------------------------------------------------------------------
; INIT DRIVE                            A < DRIVE
;                                       Y < UNIT
;--------------------------------------------------------------------------
init_drive:
        sty DN
        clc
        adc #'0'
        sta cmd_ix+1
        lday cmd_ix
        jsr_rts send_cmd


;--------------------------------------------------------------------------
; SETLFS				A < LFN logical file number
;					X < DN	device address
;					Y < SA	secondary address
;--------------------------------------------------------------------------
SETLFS:
	sta LFN
	stx DN
	sty SA
	rts

;--------------------------------------------------------------------------
; SETNAM				A < file name length
;					X < LSB file name pointer
;					Y < MSB file name pointer
;--------------------------------------------------------------------------
SETNAM:
	sta FNLEN
	stx FNADR
	sty FNADR+1
	rts


;--------------------------------------------------------------------------
; STRING CONSTANTS
;--------------------------------------------------------------------------
.rodata



;--------------------------------------------------------------------------
; VARIABLES
;--------------------------------------------------------------------------
.data

cmd_ix:         .byte "Ix", 0

.bss
bufds:          .res 40         ; Disk status text
