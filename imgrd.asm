;--------------------------------------------------------------------------
	.listbytes unlimited
	.code

;--------------------------------------------------------------------------
	.include "6502.inc"		; general 6502 macros
	.include "petscii.inc"

	.import LISTN, TALK, SECND, ACPTR, UNTLK, UNLSN, OPEN, CLOSE
	.import CLRCH, SCNT, SETT, CHKIN, CHKOUT, BASIN
	.import CIOUT, READY, STOPEQ
	.import SPACE, SPAC2, INTOUT, STROUTZ, CRLF, BSOUT
	.import HEXOUT

	.importzp ST, DN, FNADR, FNLEN, LFN, SA
	.importzp MOVSRC

	.import upload_drivecode, get_ds, print_ds, send_cmd
	.import SETNAM, SETLFS

	.export main

	ptr	:= $3C			; pointer to command string
	errptr	:= $3E			; pointer to error table

	CH_BUF	= 3			; secondary address for sector buffer
	CH_IMG	= 9			; secondary address for image file
	

;--------------------------------------------------------------------------
; MAIN
;--------------------------------------------------------------------------

main:
	lday hello			; say hello
	jsr STROUTZ
; TODO: ask user for settings
	jsr print_settings

	lda sdrive			; INIT source drive
	ldy sunit
	jsr init_drive
	jsr get_ds
	bcc @ok
	jsr_rts print_ds		; INIT failed
@ok:
	lday errbuf			; clear error table
	stay ptr
	ldy #0
clrlp:	tya
	sta (ptr),y
	inc ptr
	bne @cc
	inc ptr+1
@cc:	lda ptr+1
	cmp #>errbuf_end
	bne clrlp
	lda ptr
	cmp #<errbuf_end
	bne clrlp

	lda sunit
	sta DN
	jsr upload_drivecode		; upload drivecode

;	jsr autodetect_sides

	lda #str_ch1_end - str_ch1	; open data buffer
	ldxy str_ch1			; OPEN CH_BUF, sunit, CH_BUF, "#1"
	jsr SETNAM
	lda #CH_BUF
	ldx sunit
	tay
	jsr SETLFS
	jsr OPEN

	lda tdrive			; patch drive number
	clc
	adc #'0'
	sta str_imagename


	jsr set_d80			; default to .d80
	lda sides
	cmp #2
	bne @othet
	jsr set_d82			; two sides ==> .d82
	bcc @d8x			; branch always
@othet: lda tracks
	cmp #77
	bcs @d8x			; if tracks < 77, it must be .d64
	jsr set_d64
@d8x:
					; open image output file
	lda #str_imagename_end - str_imagename
	ldxy str_imagename
	jsr SETNAM
	lda #CH_IMG
	ldx tunit
	tay
	jsr SETLFS
	jsr OPEN

	jsr get_ds
	bcc @okopen
	lday msg_image_open_failed
	jsr STROUTZ
	jsr print_ds
	jmp exit
@okopen:

	lday 0
	stay errcnt
	lday errbuf
	stay errptr

	lda #1
	sta rd_trk
	lda #0
	sta rd_sec

copy_track:
	jsr calc_blks
	jsr CRLF
	ldx rd_trk
	lda #0
	jsr INTOUT
	jsr SPACE

next_blk:
	jsr copy_block			; copy block from disk to image file
	ldy #0
	sta (errptr),y			; store error code in table
	inc errptr
	bne @nocarry
	inc errptr+1
@nocarry:
	cmp #1				; block read successfully?
	beq @rdsuccess
	tax
	lda #0
	jsr INTOUT			; print FDC error code
	inc errcnt			; increment error counter
	bne @nocarry2
	inc errcnt+1
@nocarry2:
	bne @check_trk_complete

@rdsuccess:
	lda #'.'
	jsr BSOUT

@check_trk_complete:
	inc rd_sec
	lda rd_sec
	cmp sectors
	beq @secdone
	bne next_blk

@secdone:
	lda #0
	sta rd_sec
	lda rd_trk
	cmp tracks
	beq image_complete
	inc rd_trk
	bne copy_track

image_complete:

	jsr CRLF
	jsr CRLF
	ldx errcnt
	lda errcnt+1
	jsr INTOUT			; print number of bad blocks
	lda #'S'
	sta msg_bb_plural
	lda errcnt
	cmp #1
	bne plural
	lda errcnt+1
	bne plural
	lda #' '
	sta msg_bb_plural
plural:
	lday msg_bad_blocks
	jsr STROUTZ

	lda force_errtbl
	bne @appnd
	lda errcnt
	ora errcnt+1
	beq @exit
@appnd:	jsr append_errtbl
@exit:	jmp exit


;--------------------------------------------------------------------------
; APPEND ERROR TABLE TO IMAGE FILE
;--------------------------------------------------------------------------
append_errtbl:
	lday msg_appending
	jsr STROUTZ

	ldx #CH_IMG
	jsr CHKOUT

	lday errbuf
	stay ptr

@loop:	ldy #0
	lda (ptr),y
	jsr BSOUT
	inc ptr
	bne @cc
	inc ptr+1
@cc:	lda ptr+1
	cmp errbuf_top+1
	bne @loop
	lda ptr
	cmp errbuf_top
	bne @loop

	jsr CLRCH
	lday msg_ok
	jsr_rts STROUTZ
	

;--------------------------------------------------------------------------
; COPY BLOCK
;--------------------------------------------------------------------------
copy_block:
	jsr read_block			; read block in floppy buffer
	pha				; save FDC error code

	lday cmd_bp			; copy block from floppy buffer	
	jsr send_cmd			; to RAM buffer	
	ldx #CH_BUF
	jsr CHKIN
	lday blkbuf
	stay ptr

@rd_blk:
	jsr check_abort
	jsr BASIN
	ldy #0
	sta (ptr),y
	inc ptr
	bne @rd_blk
	jsr CLRCH

	ldx #CH_IMG			; copy block from RAM buffer
	jsr CHKOUT			; to image file

@wr_blk:
	jsr check_abort
	ldy #0
	lda (ptr),y
	jsr BSOUT
	inc ptr
	bne @wr_blk
	jsr CLRCH
	pla				; restore FDC error code
	rts


;--------------------------------------------------------------------------
; ABORT
;--------------------------------------------------------------------------
check_abort:
	jsr STOPEQ
	beq abort
	rts
	
abort:	lday msg_aborted
	jsr STROUTZ

	lda keep_partial		; scratch partial image file?
	bne keep_partial_image
	lda tunit
	sta DN
	lda imageoptions
	pha
	lda #0
	sta imageoptions		; zero terminate file name
	lday str_scratch
	jsr send_cmd
	pla
	sta imageoptions		; restore option string
keep_partial_image:
	; fall through
;--------------------------------------------------------------------------
; CLOSE FILES AND EXIT
;--------------------------------------------------------------------------
exit:
	lda #CH_IMG			; close image file
	sta LFN
	jsr CLOSE
	lda #CH_BUF			; close data buffer
	sta LFN
	jsr CLOSE

	jmp READY


;--------------------------------------------------------------------------
; AUTO DETECT SIDES
;--------------------------------------------------------------------------
autodetect_sides:        
	lda sides			; autodetect sides?
	bne no_autodetect

	lday msg_detect_sides
	jsr STROUTZ

	lda #116
	sta rd_trk
	lda #0
	sta rd_sec
	lda #1
	sta rd_retr
	jsr read_block

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
; READ BLOCK				rd_trk	< track number
;					rd_sec	< sector number
;					rd_retr	< retries
;
;					A	> FDC error code
;--------------------------------------------------------------------------
read_block:
	jsr check_abort
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

read_fdc_status:
	lday cmd_mr			; read job queue status
	jsr send_cmd

	jsr TALK			; get FDC error code
	lda #$6f
	sta SA
	jsr SECND
	jsr ACPTR
	pha
	.ifdef DEBUG
		jsr HEXOUT
	.endif
	jsr UNTLK
	pla

	rts


;--------------------------------------------------------------------------
; CALCULATE BLOCKS PER TRACK
;--------------------------------------------------------------------------
calc_blks:
	jmp (vect_calc_blks)

calc_blks_2031_4040:
	lda rd_trk
	cmp #1
	beq @zone1
	cmp #18
	beq @zone2
	cmp #25
	beq @zone3
	cmp #31
	beq @zone4
	rts
@zone1:	lda #21
	skip2
@zone2:	lda #19
	skip2
@zone3:	lda #18
	skip2
@zone4:	lda #17
	sta sectors
	rts

calc_blks_8x50:
	lda rd_trk
	cmp #1
	beq @zone1
	cmp #40
	beq @zone2
	cmp #54
	beq @zone3
	cmp #65
	beq @zone4
	cmp #78
	beq @zone1
	cmp #117
	beq @zone2
	cmp #131
	beq @zone3
	cmp #142
	beq @zone4
	rts
@zone1:	lda #29
	skip2
@zone2:	lda #27
	skip2
@zone3:	lda #25
	skip2
@zone4:	lda #23
	sta sectors
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
; SET DRIVE CONSTANTS
;--------------------------------------------------------------------------
set_d64:
	lda #'6'
	sta imageext
	lda #'4'
	sta imageext+1

	lday calc_blks_2031_4040
	stay vect_calc_blks

	lday 683
	bne calc_errbuf_top


set_d80:
	lda #'8'
	sta imageext
	lda #'0'
	sta imageext+1

	lday calc_blks_8x50
	stay vect_calc_blks

	lday 2083
	bne calc_errbuf_top


set_d82:
	lda #'8'
	sta imageext
	lda #'2'
	sta imageext+1

	lday calc_blks_8x50
	stay vect_calc_blks

	lday 4166

calc_errbuf_top:
	clc
	adc #<errbuf
	sta errbuf_top
	tya
	adc #>errbuf
	sta errbuf_top+1
	rts

;--------------------------------------------------------------------------
; STRING CONSTANTS
;--------------------------------------------------------------------------
.rodata

hello:	.byte CR, CR
		.byte "IMGRD 0.02 PRE-ALPHA", CR

msg_src:	.byte "SOURCE ", 0
msg_target:	.byte "TARGET ", 0
msg_image_open_failed:
		.byte "CREATING IMAGE: ",0
msg_detect_sides:
		.byte "AUTODETECTING SIDES: ",0
msg_bad_blocks:	.byte " BAD BLOCK"
msg_bb_plural:	.byte "S", CR, 0
msg_aborted:	.byte CR, "ABORTED", CR, 0
msg_appending:	.byte CR, "APPENDING ERROR TABLE... ",0
msg_ok:		.byte "OK", CR, 0

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
sides:		.byte 1		; Sides, 0=auto
retries:	.byte 15	; Number of retries
tracks:		.byte 77	; last track
sectors:	.byte 29	; number of sectors
keep_partial:	.byte 1		; keep partial image file on break
force_errtbl:	.byte 0		; write error table always if non-zero

cmd_ix:		.byte "Ix", 0

cmd_rd_sec:	.byte "M-W"
		.addr $1100
		.byte 3
rd_trk:		.byte 39	; track
rd_sec:		.byte 1		; sector
rd_retr:	.byte 5		; retries

.assert CH_BUF < 10, error, "CH_BUF > 9"
cmd_bp:		.byte "B-P ", CH_BUF+'0', " 0", 0

str_ch1:	.byte "#1"
str_ch1_end:

str_scratch:	.byte "S"
str_imagename:	.byte "0:DISK-"
imagenumber:	.byte "000.D"
imageext:	.byte "80"
imageoptions:	.byte ",W,S"
str_imagename_end:
		.byte 0

.bss
dsksides:	.res 1		; number of disk sides
rd_res:		.res 1		; FDC error code
saveA:		.res 1
saveX:		.res 1
saveY:		.res 1

		.align $100
blkbuf:		.res 256	; block buffer
vect_calc_blks:	.res 2		; aligned, not starting at last byte of page
errcnt:		.res 2		; number of bad blocks
errbuf:		.res 4166	; error table per block
errbuf_end:
errbuf_top:	.res 2		; address of last entry+1


;--------------------------------------------------------------------------
		.end

