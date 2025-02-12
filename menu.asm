	.include "petscii.inc"
	.include "6502.inc"

	.import STROUTZ, SPACE, CRLF, READY, GETIN, BSOUT, SPAC2
	.import STROUTZ_right, locate, myintout, spaces, wrongkey
	.import set_d64, set_d80, set_d82, autodetect_sides
	.import reset_source_drive
	.importzp ptr, DN

	.import sunit, sdrive, tunit, tdrive, retries
	.import keep_partial, write_errtbl, bamonly, useflpcde
	.import autoinc, sound
	.import catalog, str_catdrv

	.export menu, imgparmvect

.macro gotoxy column_X, row_Y
	.if .paramcount <> 2
	.error "gotoxy requires X and Y parameter"
	.endif
	ldx #column_X
	ldy #row_Y
	jsr locate
.endmacro

.macro print addr
	.if .paramcount <> 1
	.error "Start address of string required"
	.endif
	lday addr
	jsr STROUTZ
.endmacro

.enum imagetype
	d64
	auto_d80_d82
	force_d80
	force_d82
	end_of_table
.endenum

.enum append_error_table
	always
	on_errors
	never
.endenum

menu:
	jsr update_imgparmvect
	print msg_menuleft		; left menu column static text
	lday msg_menuright		; right menu column static text
	jsr STROUTZ_right
	gotoxy 0, 23			; bottom line actions
	print msg_return
	jsr prsound
	gotoxy 34, 23
	print msg_quit
	jsr prsunit
	jsr prsdrv
	jsr prtunit
	jsr prtdrv
	jsr prretr
	jsr prbamonly			; read all/only allocated blocks
	jsr prerrtbl			; append error table
	jsr prflpcde			; use floppy code or kernal to read
	jsr prpartial			; scratch or keep partial imgs
	jsr primgtp			; print image type
	jsr prname			; auto inc / manual image number

waituser:
mn50:	jsr GETIN
	beq mn50
	cmp #'Q'			; Q / STOP
	beq quit
	cmp #STOP
	bne mn51
quit:	lda #CLRHOME
	jsr BSOUT
	pla				; drop return address
	pla
	jmp READY
mn51:
	cmp #'B'			; B --> read all/only allocated blks
	bne mn52
	ldxa bamonly			; invert flag
	jsr toggle
	jsr prbamonly			; print new setting
	jmp waituser

mn52:	cmp #'T'			; T --> append error table
	bne mn53
	inc write_errtbl
	lda write_errtbl
	cmp #3
	bne mn52b
	lda #0
	sta write_errtbl
mn52b:	jsr prerrtbl
	jmp waituser

mn53:	cmp #'M'			; M --> read method
	bne mn54
	ldxa useflpcde
	jsr toggle
	jsr prflpcde
	jmp waituser

mn54:	cmp #'P'			; P --> scratch or keep partial imgs
	bne mn55
	ldxa keep_partial
	jsr toggle
	jsr prpartial
	jmp waituser

mn55:	cmp #'Y'			; Y --> select image type
	bne mn56
	ldx imgtype
	inx
	cpx #imagetype::end_of_table
	bne tp10
	ldx #0
tp10:	stx imgtype
	jsr update_imgparmvect
	jsr primgtp
	jmp waituser

update_imgparmvect:
	ldx imgtype
	lda setimgparms_lo,x
	sta vect_imgparm
	lda setimgparms_hi,x
	sta vect_imgparm+1
	rts

imgparmvect: jmp (vect_imgparm)		; forwarding to subroutine
.bss
vect_imgparm: .res 2
.code

mn56:	cmp #'$'			; $ --> catalog of source drive
	bne mn57
	lda sdrive
	ldy sunit
cat:	jsr catalog
	jmp menu

mn57:	cmp #'C'			; C --> catalog of target drive
	bne mn58
	lda tdrive
	ldy tunit
	bne cat

mn58:	cmp #'N'			; N --> given/auto inc image number
	bne mn59
	ldxa autoinc
	jsr toggle
	jsr prname
	jmp waituser

; TODO: allow only available unit numbers
; do not loop forever if only one unit is availble
mn59:	cmp #'U'			; U --> source unit number
	bne mn60
su10:	inc sunit
su15:	lda tunit			; assert sunit <> tunit
	cmp sunit
	beq su10
	lda #32				; max unit number 31
	cmp sunit
	bne su20
	lda #8				; reset to 8
	sta sunit
	bne su15
su20:	jsr prsunit
	jmp waituser

mn60:	cmp #'I'			; I --> target unit number
	bne mn61
tu10:	inc tunit
tu15:	lda sunit			; assert sunit <> tunit
	cmp tunit
	beq tu10
	lda #32				; max unit number 31
	cmp tunit
	bne tu20
	lda #8
	sta tunit
	bne tu15
tu20:	jsr prtunit
	jmp waituser

mn61:	cmp #'D'			; D --> source drive
	bne mn62
	inc sdrive
	lda #2				; source drive 0..1
	cmp sdrive
	bne sd10
	lda #0
	sta sdrive
sd10:	jsr prsdrv
	jmp waituser

mn62:	cmp #'V'			; V --> target drive
	bne mn63
	inc tdrive
	lda #10				; target drive 0..9
	cmp tdrive
	bne td10
	lda #0
	sta tdrive
td10:	jsr prtdrv
	jmp waituser

mn63:	cmp #'R'			; R --> number of retries
	bne mn64
	lda retries
	asl
	bcc rt10
	lda #1
rt10:	sta retries
	jsr prretr
	jmp waituser

mn64:	cmp #CR
	beq go
	cmp #' '
	bne mn65

go:
	gotoxy 0, 23			; clear bottom line
	ldx #39
	jsr spaces
	gotoxy 0, 19
	rts


mn65:	cmp #'S'			; S --> toggle audible feedback
	bne mn66
	ldxa sound
	jsr toggle
	jsr prsound
	jmp waituser

mn66:	cmp #'E'			; E --> reset source drive
	bne mn67
	jsr reset_source_drive
	jmp waituser	

mn67:
	jsr wrongkey
	jmp mn50


;--------------------------------------------------------------------------
; TOGGLE				X < lsb pointer to flag
; toggles boolean byte variable		A < msg pointer to flag
; this code is cumbersome but works with any values whereas eor #$ff doesnt
;--------------------------------------------------------------------------
toggle:
	stx ptr
	sta ptr+1
	ldy #0
	lda (ptr),y
	beq tg10
	tya
	sta (ptr),y
	rts
tg10:	lda #$ff
	sta (ptr),y
	rts
	


prbamonly:
	gotoxy 5, 13			; delete all/only allocated blocks
	ldx #14
	jsr spaces
	jsr CRLF
	ldx #19
	jsr spaces
	gotoxy 5, 13			; print all/only allocated blocks
	lday msg_only_allc
	ldx bamonly
	bne prbo10
	lday msg_all
prbo10:	jsr STROUTZ
	print msg_blocks
	rts

prerrtbl:
	gotoxy 20, 14			; append error table
	ldx #14
	jsr spaces
	gotoxy 20, 14
	ldx write_errtbl
	cpx #append_error_table::always
	bne prer10
	lday msg_always
	jsr_rts STROUTZ
prer10:	cpx #append_error_table::on_errors
	bne prer20
       	lday msg_on_err
	jsr_rts STROUTZ
prer20:	lday msg_never
	jsr_rts STROUTZ

prflpcde:
	gotoxy 0, 17			; read with floppy code / kernal
	ldx useflpcde
	bne prfl10
	print msg_kernal
	ldx #5
	jsr_rts spaces
prfl10:	lday msg_flpcde
	jsr_rts STROUTZ

prpartial:				; scratch or keep partial images
	gotoxy 20, 11
	ldx keep_partial
	beq prp10
	print msg_keep
	jmp prp20
prp10:	print msg_scratch
prp20:	print msg_partial
	rts

primgtp:				; print image type
	gotoxy 6, 8
	ldx #11
	jsr spaces
	gotoxy 6, 8
	lda imgtype
	asl
	tax
	lda imgtpstrtbl,x
	ldy imgtpstrtbl+1,x
	jsr_rts STROUTZ

prname:
	gotoxy 26, 8
	ldx #15
	jsr spaces
	gotoxy 26, 8
	lda autoinc
	beq prn10
	print msg_autoinc
	rts
prn10:	print msg_given_no
	rts
	
prsunit:
	gotoxy 5, 4			; read unit
	ldx sunit
	lda #0
	jsr myintout
	jsr_rts SPACE

prsdrv:
	gotoxy 6, 5			; read drive
	ldx sdrive
	lda #0
	jsr myintout
	rts

prtunit:
	gotoxy 25, 4			; write unit
	ldx tunit
	lda #0
	jsr myintout
	jsr_rts SPACE

prtdrv:
	gotoxy 26, 5			; write drive
	ldx tdrive
	lda #0
	jsr myintout
	jsr_rts SPACE

prretr:
	gotoxy 9, 11			; retries
	ldx #4
	jsr spaces
	gotoxy 9, 11
	ldx retries
	lda #0
	jsr myintout
	rts

prsound:
	gotoxy 19, 23
	print msg_sound
	lda sound
	beq prs10
	lda #'Y'
	skip2
prs10:	lda #'N'
	jsr_rts BSOUT
	
.rodata
;                     ....:....1....:....2....:....3....:....4
msg_menuleft:	.byte CLRHOME, "IMGRD 0.2   2014,2025 FOR(;;)", CR, CR
		.byte "READ", CR
		.byte CR
		.byte RVSON, "U", RVSOFF, "NIT", CR
		.byte RVSON, "D", RVSOFF, "RIVE", CR
		.byte RVSON, "$", RVSOFF, " CATALOG", CR
		.byte CR
		.byte "T", RVSON, "Y", RVSOFF, "PE: ", CR
		.byte CR
		.byte CR
		.byte RVSON, "R", RVSOFF, "ETRIES:", CR
		.byte CR
		.byte "READ", CR
		.byte CR
		.byte CR
		.byte "READ ", RVSON, "M", RVSOFF, "ETHOD: ", CR
		.byte CR
		.byte CR
		.byte "R", RVSON, "E", RVSOFF, "SET DRIVE"
		.byte 0
msg_menuright:	.byte HOME, CR
		.byte CR
		.byte "WRITE",CR
		.byte CR
		.byte "UN", RVSON, "I", RVSOFF, "T", CR
		.byte "DRI", RVSON, "V", RVSOFF, "E", CR
		.byte RVSON, "C", RVSOFF, " CATALOG", CR
		.byte CR
		.byte RVSON, "N", RVSOFF, "AME:"
		.byte CR
		.byte CR
		.byte CR
		.byte CR
		.byte CR
		.byte "APPEND ERROR ", RVSON, "T", RVSOFF, "ABLE:"
		.byte 0
msg_return:	.byte RVSON, "RETURN", RVSOFF, " READ IMAGE", 0
msg_sound:	.byte RVSON, "S", RVSOFF, "OUND: ", 0
msg_quit:	.byte RVSON, "Q", RVSOFF, "UIT", 0
msg_all:	.byte "ALL ", 0
msg_only_allc:	.byte "ONLY", CR, "ALLOCATED ", 0
msg_blocks:	.byte RVSON, "B", RVSOFF, "LOCKS", 0
msg_on_err:	.byte "ON ERRORS ONLY", 0
msg_always:	.byte "ALWAYS", 0
msg_never:	.byte "NEVER", 0
msg_kernal:	.byte "KERNAL", 0
msg_flpcde:	.byte "FLOPPY CODE", 0
msg_keep:	.byte "KEEP", 0
msg_scratch:	.byte "SCRATCH", 0
msg_partial:	.byte " ", RVSON, "P", RVSOFF, "ARTIAL IMGS   ", 0
msg_autoinc:	.byte "AUTO INCREMENT", 0
msg_given_no:	.byte "GIVEN NUMBER", 0

msg_d64:	.byte "D64", 0
msg_auto_d8x:	.byte "AUTO D80/82", 0
msg_fd80:	.byte "FORCE D80", 0
msg_fd82:	.byte "FORCE D82", 0
imgtpstrtbl:	.word msg_d64, msg_auto_d8x, msg_fd80, msg_fd82
setimgparms_lo:	.lobytes set_d64, autodetect_sides, set_d80, set_d82
setimgparms_hi:	.hibytes set_d64, autodetect_sides, set_d80, set_d82


.data
imgtype:	.byte imagetype::force_d82

