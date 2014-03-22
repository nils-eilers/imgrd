	.include "6502.inc"		; general 6502 macros
	.include "petscii.inc"

        .import LISTN, TALK, SECND, ACPTR, UNTLK, UNLSN, OPEN, CLOSE
        .import CLRCH, CIOUT, READY, BSOUT, SPACE, SPAC2, INTOUT, STROUTZ
        .import HEXOUT, CRLF

	.importzp DN, ST, SA

	.export get_ds, print_ds, send_cmd

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

done:
        lda #0
        sta bufds,X                     ; zero terminate string
        jsr UNTLK

; Quick test for "00,"

        ldx #2
cmploop:
        lda bufds,X
        cmp str_ok,X
        bne err_exit
        dex
        bpl cmploop

        lda #0                          ; 00, OK
        clc                             ; indicate OK
        rts

dev_not_pr:
        ; TODO: copy "device not present" to bufds
        jsr UNTLK

err_exit:
        ; TODO: atoi(bufds) -> A
        lda #1
        sec                             ; indicate error
        rts

.endproc


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
; STRING CONSTANTS
;--------------------------------------------------------------------------
.rodata

str_ok:         .byte "00,"

;--------------------------------------------------------------------------
; VARIABLES
;--------------------------------------------------------------------------
.data

cmd_ix:         .byte "Ix", 0

.bss
bufds:          .res 40         ; Disk status text
