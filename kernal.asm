;--------------------------------------------------------------------------
; KERNAL
;--------------------------------------------------------------------------

	.export BASIN		:= $ffcf ; read char from input channel -> A
	.export BSOUT		:= $ffd2 ; Write A to stdout
	.export CHKIN		:= $ffc6 ; set input unit
	.export CHKOUT		:= $ffc9 ; set output unit
	.export CLRCH		:= $ffcc ; reset input/output unit,UNLSN,UNTLK
	.export STOPR		:= $ffe1 ; return to BASIC if STOP key pressed
	.export GETIN		:= $ffe4 ; read char from keyboard buffer -> A

