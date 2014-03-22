;--------------------------------------------------------------------------
; BASIC STARTER
;--------------------------------------------------------------------------

        line = 8050

        .import detectbasic
	.include "tokens.inc"

        .export __LOADADDR__: absolute = 1
.segment "LOADADDR"
        .addr *+2

        .export __EXEHDR__: absolute = 1
.segment "EXEHDR"

	.byte $00			; for BASIC 1 
	.word eol                       ; pointer to next line
	.word line			; line number
	.byte TK_SYS                    ; SYS TOKEN
;       .byte <(((start / 10000) .mod 10) + '0')
        .byte <(((start /  1000) .mod 10) + '0')
        .byte <(((start /   100) .mod 10) + '0')
        .byte <(((start /    10) .mod 10) + '0')
        .byte <(((start        ) .mod 10) + '0')
        .byte 0                         ; end of BASIC line
eol:    .byte 0,0			; end of BASIC program

.assert (start < 10000), error, "Start address too large"


start:
