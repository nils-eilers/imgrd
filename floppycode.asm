.segment "FLOPPY"
.export __FLOPPYCODE_SIZE__ := floppycode_end - floppycode_start

; This code gets uploaded to the floppy and
; runs in buffer #0 starting at $1100

drvnum	= $12
track	= $13
sector	= $14
jobs	= $1003	; table of jobcodes for buffer 0-14
headers = $1021	; table of headers (8 bytes per buffer)
dskid0	= $4342

; KSETH	= $ff1b

floppycode_start:

trk:	.byte 116
sect:	.byte 0
retry:	.byte 5
error:	.byte 0
spare:	.byte 0
spare2:	.byte 0

; -------------------------
; TODO: remove debug code!
	lda #$81
	sta error
	rts
; -------------------------

	lda trk		; start with M-E $1106
	sta track
	lda sect
	sta sector
	lda #1		; use buffer #1
	pha
;	jsr KSETH	; setup header with t,s,id
	jsr seth	; KSETH not present on 4040!
	pla
	tax
	ldy retry
read:	lda #$80	; read sector from drive #0
	ora drvnum
	sta jobs,x
wait:	lda jobs,x	; wait for drive job to finish
	bmi wait
	cmp #2
	bcc okay
	dey
	bne read
okay:	sta error
	rts

seth:	asl 
	asl 
	asl 
	tay
	lda track
	sta headers+2,y
	lda sector
	sta headers+3,y
	lda drvnum
	asl 
	tax
	lda dskid0,x
	sta headers,y
	lda dskid0+1,x
	sta headers+1,y
	rts

floppycode_end:

	.end
