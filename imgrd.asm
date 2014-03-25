;--------------------------------------------------------------------------
	.listbytes unlimited
	.code

;--------------------------------------------------------------------------
	.include "6502.inc"		; general 6502 macros
	.include "petscii.inc"

	.import LISTN, TALK, SECND, ACPTR, UNTLK, UNLSN, OPEN, CLOSE
	.import CLRCH
	.import CIOUT, READY
	.import SPACE, SPAC2, INTOUT, STROUTZ, CRLF, BSOUT
	.import HEXOUT

	.importzp ST, DN, FNADR, FNLEN, LFN, SA

	.import upload_drivecode, get_ds, print_ds, send_cmd

	.export main

	ptr = $3C                         ; pointer to command string
	ptr2 = $3E
	

;--------------------------------------------------------------------------
; MAIN
;--------------------------------------------------------------------------
main:
	lday hello			; say hello
	jsr STROUTZ
	jsr print_settings

	lda sdrive                      ; INIT source drive
	ldy sunit
	jsr init_drive
	jsr get_ds
	bcc @ok
	jsr_rts print_ds		; INIT failed

@ok:    
	lda sunit
	sta DN
	jsr upload_drivecode            ; upload drivecode

;        jsr autodetect_sides

	ldx #3                          ; open data buffer
	stx SA                          ; OPEN 3, sunit, 3, "#1"
	stx LFN
	dex
	stx FNLEN
	lda #<str_ch
	sta FNADR
	lda #>str_ch
	sta FNADR+1
	lda #'1'
	sta str_ch+1
	jsr OPEN

					
	lda #9                          ; open image output file
	sta LFN                          ; OPEN 9, tunit, 9, imagename
	sta SA
	lda tunit
	sta DN
	; TODO: build imagename from user input and tdrive
	; tdrive:imagename,w
	lda strlen_imagename
	sta FNLEN
	lda #<str_imagename
	sta FNADR
	lda #>str_imagename
	sta FNADR+1
	jsr OPEN
	jsr get_ds
	bcc @okopen
	lday msg_image_open_failed
	jsr STROUTZ
	jsr print_ds
	jmp exit
@okopen:

;--------------------------------------------------------------------------
; CLOSE FILES AND EXIT
;--------------------------------------------------------------------------
exit:
	lda #9				; close image file
	sta LFN
	jsr CLOSE
	lda #3				; close data buffer
	sta LFN
	jsr CLOSE

	jmp READY

;--------------------------------------------------------------------------
; AUTO DETECT SIDES IF SIDES=0 AND FORMAT=80
;--------------------------------------------------------------------------
autodetect_sides:        
	lda sides			; autodetect sides?
	bne no_autodetect
	lda format
	cmp #80
	bne no_autodetect

	lday msg_detect_sides
	jsr STROUTZ

	lda #16				; TODO: 16 --> 116
	sta rd_trk
	lda #0
	sta rd_sec
	lda #1
	sta rd_retr
	jsr readsector

	ldx #1
	cmp #1				; FDC code == 1 (OK) ?
	bne @singlesided
	inx
@singlesided:
	lda #0
	jsr INTOUT
	jsr_rts CRLF

no_autodetect:
	lda sides
	sta dsksides
	rts

;--------------------------------------------------------------------------
; READ SECTOR
;--------------------------------------------------------------------------
readsector:
	; can't send this with send_cmd because the command contains
	; a NULL byte
	lda sunit			; M-W $1100 03 bytes: trk sec retries
	sta DN
	jsr LISTN
	lda #$6f
	sta SA
	jsr SECND
	ldy #9				; command length
	ldx #0
@loop:  lda cmd_rd_sec,X
	stx saveX
	sty saveY
	.ifdef DEBUG
	   pha
	   jsr HEXOUT
	   jsr SPACE
	   pla
	.endif
	jsr CIOUT

	ldx saveX
	ldy saveY
	inx
	dey
	bne @loop
	jsr UNLSN
	rts				; TODO: remove breakpoint

	.ifdef DEBUG
	   jsr get_ds
	   jsr print_ds
	   jsr CRLF
	.endif

	lday cmd_me			; M-E $1106 --> run drive code
	jsr send_cmd

	.ifdef DEBUG
	   jsr get_ds
	   jsr print_ds
	   jsr CRLF
	.endif

	lday cmd_mr			; read job queue status
	jsr send_cmd

	jsr TALK			; get FDC error code
	lda #$6f
	sta SA
	jsr SECND
	jsr ACPTR
	sta rd_res
	.ifdef DEBUG
		jsr HEXOUT
		lda rd_res
	.endif
	jsr UNTLK

	rts

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
; PRINT SETTINGS
;--------------------------------------------------------------------------
print_settings:

	lday msg_src
	jsr STROUTZ
	lday msg_udrv
	jsr STROUTZ
	lda #0
	ldx sunit
	jsr INTOUT
	jsr SPACE
	lda #'/'
	jsr BSOUT
	lda #0
	ldx sdrive
	jsr INTOUT
	jsr SPAC2
	lda sunit
	sta DN
	jsr get_ds
	jsr print_ds
	jsr CRLF

	lday msg_target
	jsr STROUTZ
	lday msg_udrv
	jsr STROUTZ
	lda #0
	ldx tunit
	jsr INTOUT
	jsr SPACE
	lda #'/'
	jsr BSOUT
	lda #0
	ldx tdrive
	jsr INTOUT
	jsr SPAC2
	lda tunit
	sta DN
	jsr get_ds
	jsr print_ds
	jsr_rts CRLF

;--------------------------------------------------------------------------
; STRING CONSTANTS
;--------------------------------------------------------------------------
.rodata

hello:	.byte CR, CR
		.byte "IMGRD 0.02 PRE-ALPHA", CR

msg_src:	.byte "SOURCE ", 0
msg_target:	.byte "TARGET ", 0
msg_udrv:	.byte "UNIT/DRIVE:", 0
msg_image_open_failed:
		.byte "OPEN IMAGE: ",0
msg_detect_sides:
		.byte "AUTODETECTING SIDES: ",0

str_ok:		.byte "00,"

cmd_bp20:	.byte "B-P 2 0",0
cmd_me:		.byte "M-E", $06, $11, 0
cmd_mr:		.byte "M-R", $03, $11, 0

;--------------------------------------------------------------------------
; VARIABLES
;--------------------------------------------------------------------------
.data
sunit:		.byte 8		; Source unit address
sdrive:		.byte 0		; Source drive 0/1
tunit:		.byte 9		; Target unit address
tdrive:		.byte 0		; Source drive 0/1
ilv:		.byte 1		; Interleave
sides:		.byte 0		; Sides, 0=auto
retries:	.byte 15	; Number of retries
format:		.byte 80

cmd_ix:		.byte "Ix", 0

cmd_rd_sec:	.byte "M-W"
		.addr $1100
		.byte 3
rd_trk:		.res 1		; track
rd_sec:		.res 1		; sector
rd_retr:	.res 1		; retries

str_ch:		.byte "#x"

strlen_imagename:
		.byte 13
str_imagename:	.byte "0:IMAGE.D80,W"

.bss
dsksides:	.res 1          ; number of disk sides
rd_res:		.res 1          ; FDC error code
saveA:		.res 1
saveX:		.res 1
saveY:		.res 1


;--------------------------------------------------------------------------
	.end

