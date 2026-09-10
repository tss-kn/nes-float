.feature   underline_in_numbers
.include    "helpers.inc"



.segment "HEADER"
.byte "NES", $1A
.byte 2
.byte 1
.byte 1

.segment "CHARS"
.incbin "charmap.chr"

.zeropage
ptr1: .res 2
ptr2: .res 2
ptr3: .res 2
ptr4: .res 2

print_ptr: .res 2

.bss
; SEEEEEMM_MMMMMMMM
.struct Fp16
    sign        .byte  ; 1 bit
    exponent    .byte  ; 5 bits
    mantissa    .word  ; 10 bits
    ; status will use cpu flags
.endstruct
; "reigsters" for half precision float arithmetic (z <- x ± y)
fp_x: .tag Fp16
fp_y: .tag Fp16
fp_z: .tag Fp16
arith_subtraction: .res 1

overflow_scratch: .res 1

tmp1: .res 1
tmp2: .res 1
tmp3: .res 1
tmp4: .res 1

tmp1_w: .res 2
tmp2_w: .res 2
tmp3_w: .res 2
tmp4_w: .res 2

return_b: .res 1
return_w: .res 2
return_dw: .res 4
return_qw: .res 8

print_complete: .res 1

.rodata
fp0_test: .word %0_10001_0100110011 ; 5.2
fp1_test: .word %0_10100_0000101011 ; ~33.33....


test_str: .byte "Hello, world!", 0

.code
reset:
.include "init.s"

    lda #$81
    sta ptr1
    sta ptr1 + 1

    clc
    ror_16 ptr1

    lda fp0_test
    sta fp_x + Fp16::mantissa

    lda fp0_test + 1
    and #%11
    sta fp_x + Fp16::mantissa + 1

    lda fp0_test + 1
    lsr
    lsr
    sta fp_x + Fp16::exponent

    lda fp1_test
    sta fp_y + Fp16::mantissa

    lda fp1_test + 1
    and #%11
    sta fp_y + Fp16::mantissa + 1

    lda fp1_test + 1
    lsr
    lsr
    sta fp_y + Fp16::exponent

    jsr fp_add_sub

loop:
    jmp loop

; ------------------------------------------------------------------------------------------------------------------------
; fp arithmetic

; Does a half precision floating point addition or subtraction
; inputs: fp_x, fp_y
; output: fp_z
fp_add_sub:
    ; transfer sign
    lda fp_x + Fp16::sign
    sta fp_z + Fp16::sign

    lda fp_y + Fp16::sign
    ora fp_z + Fp16::sign
    sta fp_z + Fp16::sign

    ; create significands
    lda fp_x + Fp16::mantissa + 1
    ora #$4
    sta fp_x + Fp16::mantissa + 1

    lda fp_y + Fp16::mantissa + 1
    ora #$4
    sta fp_y + Fp16::mantissa + 1

@adjust_exponent:
    lda fp_y + Fp16::exponent
    sta tmp1

    lda fp_x + Fp16::exponent
    cmp tmp1
    bcc @y_exp_greater
    beq @exp_done

    @x_exp_greater:
        lda fp_y + Fp16::exponent
        rol_16 fp_y + Fp16::mantissa
        inc fp_y + Fp16::exponent
        cmp fp_x + Fp16::exponent
        bcc @x_exp_greater

        jmp @exp_done
    @y_exp_greater:
        lda fp_x + Fp16::exponent
        rol_16 fp_x + Fp16::mantissa
        inc fp_x + Fp16::exponent
        cmp fp_y + Fp16::exponent
        bcc @y_exp_greater
    @exp_done:
        sta fp_z + Fp16::exponent

    ; add or subtract significands
    lda arith_subtraction
    ; bne @a_sbc

    ; Z <- X ± Y
    clc
    adc_16 fp_x + Fp16::mantissa, fp_y + Fp16::mantissa, fp_y + Fp16::mantissa+1

@sig_check:
    lda fp_x + Fp16::mantissa
    cmp #8
    bcc @no_sig_overflow

    ror_16 fp_x + Fp16::mantissa
    jmp @sig_check
@no_sig_overflow:

    lda fp_x + Fp16::mantissa
    sta fp_z + Fp16::mantissa

    lda fp_x + Fp16::mantissa + 1
    and #%11
    sta fp_z + Fp16::mantissa + 1

@done:
    rts

to_fp:
    rts

to_uint:
    rts

; ------------------------------------------------------------------------------------------------------------------------

nmi:
    pha
    txa
    pha
    tya
    pha
    php

    flush_str_buffer:
        lda print_complete
        bne @done
        lda #$20
        ldx #0
        sta $2006
        stx $2006

        @loop:
            lda test_str, x
            beq @done

            ; cmp #'%'
            ; lda #1
            ; sta is_format

            sta $2007
            inx
            jmp @loop
            
        @done:
        lda #1
        sta print_complete

    lda #0
    sta $2005
    sta $2005

    plp
    pla
    tay
    pla
    tax
    pla

    rti

irq:
    rti

.segment "VECTORS"
.addr nmi
.addr reset
.addr irq