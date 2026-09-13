.feature   underline_in_numbers
.include    "helpers.inc"

.segment "HEADER"
.byte "NES", $1A
.byte 2
.byte 1
.byte 1

.segment "CHARS"
.incbin "charmap.chr" ; charmap from cc65

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

print_len: .res 1
print_complete: .res 1
print_buffer: .res 255

.rodata
fp0_test: .word %1_10001_0100110011 ; -5.2
fp1_test: .word %0_10000_1010101011 ; ~33.33....
test_num: .byte 183
; fp0_test: .word $C533 ; 5.2
; fp1_test: .word $42AB ; ~33.33....


test_str: .byte "Hello, world!", 0

.code
reset:
.include "init.s"

    lda #<fp0_test
    ldx #>fp0_test
    sta ptr1
    stx ptr1 + 1
    lda #<fp_x
    ldx #>fp_x
    sta ptr2
    stx ptr2 + 1

    jsr to_fp

    lda #<fp1_test
    ldx #>fp1_test
    sta ptr1
    stx ptr1 + 1
    lda #<fp_y
    ldx #>fp_y
    sta ptr2
    stx ptr2 + 1

    jsr to_fp

    lda #<fp_x
    ldx #>fp_x
    sta ptr1
    stx ptr1 + 1

    ; jsr fp_add_sub
    jsr to_sci_notation
    
    print_at $2000

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
    lda fp_x + Fp16::exponent
    cmp fp_y + Fp16::exponent
    bcc @y_exp_greater
    beq @exp_done

    @x_exp_greater:
        lda fp_y + Fp16::exponent
        cmp fp_x + Fp16::exponent
        bcs @exp_done
        
        rol_16 fp_y + Fp16::mantissa
        inc fp_y + Fp16::exponent
        bcc @x_exp_greater

        jmp @exp_done
    @y_exp_greater:
        lda fp_x + Fp16::exponent
        cmp fp_y + Fp16::exponent
        bcs @exp_done

        rol_16 fp_x + Fp16::mantissa
        inc fp_x + Fp16::exponent
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

; ptr1 -> input uint
; ptr2 -> output float
to_fp:
    ; mantissa
    ldy #(Fp16::mantissa)
    ldx #0
    lda (ptr1, x)
    sta (ptr2), y

    inc ptr1
    ldy #(Fp16::mantissa + 1)
    lda (ptr1, x)
    pha
    pha
    and #%11
    sta (ptr2), y

    ; exponent
    pla
    and #$7F
    lsr
    lsr
    ldy #(Fp16::exponent)
    sta (ptr2), y

    ; sign
    pla
    lsr
    lsr
    lsr
    lsr
    lsr
    lsr
    lsr
    ldy #(Fp16::sign)
    sta (ptr2), y

    rts

to_uint:
    lda fp_z + Fp16::mantissa
    sta return_w
    lda fp_z + Fp16::mantissa + 1
    sta return_w + 1

    lda fp_z + Fp16::exponent
    asl
    asl
    ora return_w + 1
    sta return_w + 1

    lda fp_z + Fp16::sign
    ror
    ror

    rts

; converts into a string
; ptr1: pointer to an Fp16 struct
to_sci_notation:
    lda #'1'
    jsr stosb
    lda #'.'
    jsr stosb
    
    ldy #Fp16::mantissa + 1
    ldx #2
    jsr itob


    ldy #Fp16::mantissa
    ldx #8
    jsr itob

    lda #' '
    jsr stosb
    lda #'X'
    jsr stosb
    lda #' '
    jsr stosb
    lda #'2'
    jsr stosb
    lda #'^'
    jsr stosb


    ldy #Fp16::exponent
    jsr u8toa

    lda #0
    jsr stosb

    rts


; Converts a byte into a bit string starting from the LSB
; X: number of bits to convert (1 to 8)
; Y: offset for pointer
; ptr1: pointer to a uint8
itob:
    lda (ptr1), y

    pha
    ldy print_len
    stx tmp1
    dec tmp1
    tya
    clc
    adc tmp1
    tay
    pla

    @loop:
        lsr                   ; Shift right; lowest bit (LSB) moves into Carry
        pha                   ; Save remaining bits on the stack
        
        lda #'0'              ; Default to ASCII '0'
        bcc @store            ; If Carry is clear, keep '0'
        lda #'1'              ; Otherwise, change to ASCII '1'

    @store:
        ; ldy print_len         ; Get current buffer position
        sta print_buffer, y   ; Store character ('0' or '1')
        dey
        inc print_len         ; Advance buffer length pointer
        
        pla                   ; Restore remaining bits into A
        dex                   ; Decrement bit counter (X)
        bne @loop             ; Repeat until all X bits are processed

    rts

; ptr1: u8 pointer
; Y: offset for pointer
u8toa:
    lda (ptr1), y

@hundreds:
    ldx #'0'-1
:   inx
    sec
    sbc #100
    bcs :-
    adc #100
    
    pha
    txa
    jsr stosb
    pla

@tens:
    ldx #'0'-1
:   inx
    sec
    sbc #10
    bcs :-
    adc #10

    pha
    txa
    jsr stosb
    pla

@ones:
    ldx #'0'-1
:   inx
    sec
    sbc #1
    bcs :-

    txa
    jmp stosb

stosb:
    ldx print_len
    sta print_buffer, x
    inc print_len
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
        lda print_ptr + 1
        sta $2006
        lda print_ptr
        sta $2006

        @loop:
            lda print_buffer, x
            beq @done

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