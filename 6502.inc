;--------------------------------------------------------------------------
; LDAY addr -- load immediate 16 bit value lsb to A, msb to Y
;--------------------------------------------------------------------------
	.macro lday addr
	.if .paramcount <> 1
	.error "LDAY requires 16 bit value"
	.endif
	lda #<addr
	ldy #>addr
	.endmacro

;--------------------------------------------------------------------------
; STAY addr -- store 16 bit value A (lsb) to addr, Y (msb) to addr+1
;--------------------------------------------------------------------------
	.macro stay addr
	.if .paramcount <> 1
	.error "STAY requires 16 bit value"
	.endif
	sta addr
	sty addr+1
	.endmacro

;--------------------------------------------------------------------------
; LDXA addr -- load immediate 16 bit value lsb to X, msb to A
;--------------------------------------------------------------------------
	.macro ldxa addr
	.if .paramcount <> 1
	.error "LDXA requires 16 bit value"
	.endif
	ldx #<addr
	lda #>addr
	.endmacro

;--------------------------------------------------------------------------
; LDXY addr -- load immediate 16 bit value lsb to X, msb to Y
;--------------------------------------------------------------------------
	.macro ldxy addr
	.if .paramcount <> 1
	.error "LDXA requires 16 bit value"
	.endif
	ldx #<addr
	ldy #>addr
	.endmacro

;--------------------------------------------------------------------------
; JSR_RTS: JSR addr followed by RTS --> JMP addr 
;--------------------------------------------------------------------------
        .macro jsr_rts addr
        jmp addr
        .endmacro

;--------------------------------------------------------------------------
; SKIP2 -- skip two bytes of code
;--------------------------------------------------------------------------
	.macro skip2
	.byte $2c	; BIT abs
	.endmacro
