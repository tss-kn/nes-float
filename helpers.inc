; 16 bit analog of adc
.macro adc_16 dest, mem_lo, mem_hi
    lda dest
    adc mem_lo
    sta dest

    lda dest+1
    adc mem_hi
    sta dest+1
.endmacro

; 16 bit analog of adc
.macro sbc_16 dest, mem_lo, mem_hi
    lda dest
    sbc mem_lo
    sta dest

    lda dest+1
    sbc mem_hi
    sta dest+1
.endmacro

.macro ror_16 mem
    ror mem+1
    ror mem
.endmacro

.macro rol_16 mem
    rol mem
    rol mem+1
.endmacro

.macro lsr_16 mem
    ror mem+1
    lsr mem
.endmacro

.macro asl_16 mem
    rol mem
    asl mem+1
.endmacro

.macro print_at dest
    lda #>dest
    ldx #<dest
    sta print_ptr+1
    stx print_ptr

    lda #0
    sta print_complete
.endmacro