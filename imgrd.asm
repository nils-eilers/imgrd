;--------------------------------------------------------------------------
	.listbytes unlimited
	.code

;--------------------------------------------------------------------------
	.include "6502.inc"		; general 6502 macros
	.include "petscii.inc"

	.import LISTN, TALK, SECND, ACPTR, UNTLK, UNLSN, OPEN, CLOSE
	.import CLRCH, SCNT, SETT, CHKIN, CHKOUT, BASIN, TKSA
	.import CIOUT, READY, STOPEQ, GETIN, STOPR, STROUT
	.import SPACE, SPAC2, INTOUT, STROUTZ, CRLF, BSOUT, HEXOUT

	.importzp ST, DN, FNADR, FNLEN, LFN, SA
	.importzp CURSOR, CURSP, CURAD, BLINK, KEY, CHAR
	.importzp MOVSRC, STRADR

	.importzp ptr, errptr

	.import upload_drivecode, get_ds, print_ds, send_cmd
	.import flashget, yesno, flashscreen, digit_thousands, itoa
	.import myintout, imgparmvect, waitkey, continue_or_abort
	.import play_fanfare, play_requiem, shutup
	.import SETNAM, SETLFS

	.export main, user_abort
	.export set_d64, set_d80, set_d82, autodetect_sides

	; menu settings
	.import menu
	.export sunit, sdrive, tunit, tdrive, retries, autoinc
	.export keep_partial, force_errtbl, bamonly, useflpcde
	.export sound

; ---------- CHANNELS / SECONDARY ADDRESSES -------------------------------

	CH_BUF			= 3	; sector buffer
	CH_IMG			= 9	; image file

; ---------- STATUS -------------------------------------------------------

	ST_TIMEOUT_WR		= 1	; Time out on write
	ST_TIMEOUT_RD		= 2	; Time out on read
	ST_TIMEOUTS		= 3
	ST_EOI			= 64	; Last byte
	ST_NODEV		= 128	; Device not present


; ---------- CBM DOS ERROR CODES ------------------------------------------

	ERROR_OK		= 0
	ERROR_FILE_NOT_FOUND 	= 62
	ERROR_FILE_EXISTS	= 63
	ERROR_ILLEGAL_TS	= 66
	

;--------------------------------------------------------------------------
; MAIN
;--------------------------------------------------------------------------

main:
	jsr menu
	lday msg_start
	jsr STROUTZ

read_image:
	lday msg_init_drive
	jsr STROUTZ
	lda sdrive			; INIT source drive
	ldy sunit
	jsr init_drive
	jsr get_ds
	pha
	jsr print_ds
	jsr CRLF
	pla
	beq @ok
	cmp #ERROR_ILLEGAL_TS		; ignore, could be 8050 formatted 
	beq @ok				; disk in 8250
	jsr continue_or_abort		; anything else: ask user to continue
	bne @cont
	jmp main
@cont:	jsr CRLF	
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

	jsr imgparmvect			; patch extension, set image parms

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

					; open image output file
	jsr get_image_number
	jsr ax2fn			; patch image number
	lda #str_imagename_end - str_imagename
	ldxy str_imagename
	jsr SETNAM
	lda #CH_IMG
	ldx tunit
	tay
	jsr SETLFS
	jsr OPEN

	jsr get_ds
	bcc image_open_ok
	jsr prnfn
	lda #':'
	jsr BSOUT
	jsr SPACE
	jsr print_ds
	jmp abort

ax2fn:					; patch image number AX into filename
	jsr itoa
	ldx #3
fn10:	lda digit_thousands,x
	sta imagenumber,x
	dex
	bpl fn10
	rts


image_open_ok:

	lday msg_writing_to
	jsr STROUTZ
	jsr prnfn
	jsr CRLF

	lday 0
	stay errcnt
	lday errbuf
	stay errptr
	lda #1
	sta rd_trk
	lda #0
	sta rd_sec

;	jmp image_complete		; showstopper if uncommented

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

	jsr close_src

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
@exit:	jsr close_files

	lda sound
	beq quiet
	lda errcnt			; audible feedback
	ora errcnt+1
	beq fanfr
	jsr play_requiem
	jmp quiet
fanfr:	jsr play_fanfare
quiet:

	lday msg_again
	jsr STROUTZ
	lday flg_again
	jsr yesno
	beq @anoth
	jsr shutup
	jmp read_image
@anoth:	
	jsr shutup
	jmp main


;--------------------------------------------------------------------------
; GET IMAGE NUMBER
;--------------------------------------------------------------------------

gin80:	lday msg_ok
	jsr STROUTZ
	ldx imghi
	lda imghi+1
	rts

get_image_number:			; determine unused disk image number
	lday msg_gin
	jsr STROUTZ
	lda #'.'
	jsr BSOUT
	ldxa 1
	stxa imglo
	stxa imghi
	stxa imgno
	jsr check_image_number
	bne gin80
	lda #'.'
	jsr BSOUT
	ldxa 9999
	stxa imghi
	jsr check_image_number
	beq gin70

gin10:	lda #'.'
	jsr BSOUT

	sec
	lda imghi
	sbc imglo
	sta delta
	tax
	lda imghi+1
	sbc imglo+1
	sta delta+1
	bne gin20
	cpx #1
	beq gin80

gin20:
	lsr delta+1
	ror delta
	clc
	lda delta
	adc imglo
	sta imgno
	tax
	lda delta+1
	adc imglo+1
	sta imgno+1
	jsr check_image_number
	beq gin30			; branch if file exists
	lda imgno
	sta imghi
	lda imgno+1
	sta imghi+1
	jmp gin10
gin30:	lda imgno
	sta imglo
	lda imgno+1
	sta imglo+1
	jmp gin10

gin70:	lday msg_gin_failed
	jsr STROUTZ
	jmp abort


.bss
imgno:	.res 2
imglo:	.res 2
imghi:	.res 2
delta:	.res 2
.code
	



;--------------------------------------------------------------------------
; Does file disk-XXXX* exist? 
; XXXX gets replaced by the integer stored in XA
; returns status channel error code in A
;--------------------------------------------------------------------------
check_image_number:
	jsr ax2fn
	lda imagedot
	pha
	lda #'*'
	sta imagedot
	lda #imagedot - str_imagename + 1
	ldxy str_imagename
	jsr SETNAM
	lda #CH_IMG
	ldx tunit
	tay
	jsr SETLFS
	jsr OPEN
	pla
	sta imagedot
	jsr get_ds
	pha
	lda #CH_IMG
	sta LFN
	jsr CLOSE
	pla
	rts


;--------------------------------------------------------------------------
; PRNFN: print file name (without options)
;--------------------------------------------------------------------------
prnfn:
	ldx DN
	lda #0
	jsr myintout
	lda #'/'
	jsr BSOUT
	lda #<str_imagename
	sta STRADR
	lda #>str_imagename
	sta STRADR+1
	ldy #0
pfn10:	lda (STRADR),y
	beq pfn20
	cmp #','
	beq pfn20
	iny
	bne pfn10
pfn20:	tya
	tax
	jsr_rts STROUT
	

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

	lday cmd_bp			; reset block pointer to 0
	jsr send_cmd


; Copy block from floppy buffer to RAM buffer

	lday blkbuf
	stay ptr

	lda sunit
	sta DN
	jsr TALK
	lda #$60 | CH_BUF		; TALK unit "sunit",
	jsr TKSA			; secondary address "CH_BUF"

	ldy #0
rdb10:	jsr check_abort
rdb20:	lda ST				; reset any timeout errors
	and #$FF - ST_TIMEOUTS
	sta ST	
	jsr ACPTR			; read byte from bus
	sta (ptr),y
	lda ST
	and #ST_TIMEOUTS
	bne rdb10			; timeout: try again
	iny
	bne rdb20
	jsr UNTLK			; UNTALK




	lda tunit
	sta DN
	jsr LISTN
	lda #$60 | CH_IMG		; LISTEN unit "tunit",
	jsr SECND			; secondary address "CH_IMG"

	ldy #0
wrb10:	jsr check_abort
wrb20:	lda ST				; reset any timeout errors
	and #$FF - ST_TIMEOUTS
	sta ST
	lda blkbuf,y
	jsr CIOUT			; send byte to bus
	lda ST
	and #ST_TIMEOUTS
	bne wrb10			; timeout: try again
	iny
	bne wrb20
	jsr UNLSN			; UNLISTEN

	pla				; restore FDC error code
	rts


;--------------------------------------------------------------------------
; ABORT
;--------------------------------------------------------------------------
check_abort:
	jsr STOPEQ
	beq user_abort
	rts
	
user_abort:
	lday msg_aborted
	jsr STROUTZ

abort:

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
	jsr close_files
	jsr waitkey
	jmp main

;--------------------------------------------------------------------------
; CLOSE FILES
;--------------------------------------------------------------------------
close_files:
	lda #CH_IMG			; close image file
	sta LFN
	jsr CLOSE
close_src:
	lda #CH_BUF			; close data buffer
	sta LFN
	jsr_rts CLOSE


;--------------------------------------------------------------------------
; AUTO DETECT SIDES
;--------------------------------------------------------------------------
autodetect_sides:        
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
	dex
	stx doubleside
	inx
	lda #0
	jsr INTOUT
	jsr CRLF
	jsr_rts set_d8x_parm

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
; SET DRIVE CONSTANTS
;--------------------------------------------------------------------------
set_d64:
	lda #'6'
	sta imageext
	lda #'4'
	sta imageext+1

	lda #35
	sta tracks

	lda #0
	sta doubleside

	lday calc_blks_2031_4040
	stay vect_calc_blks

	lday 683
	bne calc_errbuf_top


set_d80:
	lda #'8'
	sta imageext
	lda #'0'
	sta imageext+1
	
	lda #77
	sta tracks

	lda #0
	sta doubleside

	lday calc_blks_8x50
	stay vect_calc_blks

	lday 2083
	bne calc_errbuf_top


set_d82:
	lda #'8'
	sta imageext
	lda #'2'
	sta imageext+1

	lda #154
	sta tracks

	lda #1
	sta doubleside

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

set_d8x_parm:
	lda doubleside
	bne @d82
	jmp set_d80
@d82:	jmp set_d82


;--------------------------------------------------------------------------
; STRING CONSTANTS
;--------------------------------------------------------------------------
.rodata

msg_start:	.byte "READING DISK IMAGE...", CR, 0
msg_init_drive:	.byte "INIT DRIVE: ", 0
msg_detect_sides:
		.byte "AUTODETECTING SIDES: ",0
msg_bad_blocks:	.byte " BAD BLOCK"
msg_bb_plural:	.byte "S", CR, CR, 0
msg_aborted:	.byte CR, "ABORTED", CR, 0
msg_appending:	.byte CR, "APPENDING ERROR TABLE... ",0
msg_ok:		.byte "OK", CR, 0
;                      ....:....1....:....2....:....3....:....4
msg_again:	.byte "READ ANOTHER DISK WITH SAME SETTINGS? ", 0
msg_another:	.byte "EDIT SETTINGS? ", 0
msg_gin:	.byte "SCANNING FILENAMES", 0
msg_gin_failed:	.byte "UNABLE TO DETERMINE IMAGE NAME", CR, 0
msg_writing_to:	.byte "WRITING TO ", 0

str_ok:		.byte "00,"

cmd_bp20:	.byte "B-P 2 0",0
cmd_me:		.byte "M-E", $06, $11, 0
cmd_mr:		.byte "M-R", $03, $11, 0


;--------------------------------------------------------------------------
; VARIABLES
;--------------------------------------------------------------------------
.data

; ----- USER SETTINGS -----------------------------------------------------
sunit:		.byte 8		; Source unit address
sdrive:		.byte 0		; Source drive 0/1
tunit:		.byte 9		; Target unit address
tdrive:		.byte 0		; Source drive 0/1
retries:	.byte 16	; Number of retries, must be power of 2
keep_partial:	.byte 1		; keep partial image file on break
force_errtbl:	.byte 0		; write error table always if non-zero
bamonly:	.byte 0		; read only allocated blocks
useflpcde:	.byte 1		; read with floppy code
autoinc:	.byte 1		; auto-increment image filenames
sound:		.byte 1		; make noise when image reading completes
;--------------------------------------------------------------------------

doubleside:	.byte 1		; flag: disk has data on both sides
tracks:		.byte 77	; last track
sectors:	.byte 29	; number of sectors


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
imagenumber:	.byte "0000"
imagedot:	.byte ".D"
imageext:	.byte "80"
imageoptions:	.byte ",W,S"
str_imagename_end:
		.byte 0

flg_again:	.byte 1

.bss
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

