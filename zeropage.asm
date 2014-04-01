; -------------------------------------------------------------------------
; ZERO PAGE
; -------------------------------------------------------------------------

	.exportzp LINNUM	:= $11	; $11:=lsb, $12:=msb result from RDINT
	.exportzp STRADR	:= $1f	; string address $1f,$20

	.exportzp MEMSIZ	:= $34	; addr. of last RAM byte +1

	.exportzp MOVTEND	:= $55	; block move target end addr+1
	.exportzp MOVSEND	:= $57	; block move source end addr+1
	.exportzp MOVSRC	:= $5c	; block move source start addr

	.exportzp DN		:= $d4	; device number
	.exportzp FNADR		:= $da	; ptr $da,$db to filename
	.exportzp FNLEN		:= $d1	; filename's length
	.exportzp LFN		:= $d2	; logical file number
	.exportzp LVFLAG	:= $9d	; LOAD/VERIFY flag
	.exportzp SA		:= $d3	; secondary address
	.exportzp ST		:= $96	; status ST
	.exportzp EAL		:= $c9	; $c9/$ca end of program
	.exportzp VARTAB	:= $2a	; $2a/$2b start of basic variables

	.exportzp CHRGET	:= $70	; subroutine: get next BASIC text byte
	.exportzp CHRGOT	:= $76	; entry to get same byte of text again
	.exportzp TXTPTR	:= $77	; $77/$78 pointer to next CHRGET byte

	.exportzp MEMUSS	:= $fd	; tape load temps

	.exportzp KEY		:= $9e	; number of characters in keyboard buffer
	.exportzp CURSOR	:= $a7	; flag: cursor flashing
	.exportzp BLINK		:= $aa	; flag: cursor on
	.exportzp CURSP		:= $c6	; 
	.exportzp CURAD		:= $c4	;
	.exportzp CHAR		:= $a9	;
