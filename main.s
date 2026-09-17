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


exec_timer: .res 1

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

print_buffer: .res 255  ; buffer of characters to print (null terminated)
print_idx: .res 1       ; index into the print buffer, indicates where the print starts and where to store a character
print_complete: .res 1  ; indicates if there needs to be something printed (BOUND BY NMI, NOT PRACTICAL)

print_ptr: .res 2       ; pointer to the part of the screen where you want to print

.rodata
fp0_test: .word %1_10001_0100110011 ; -5.2
fp1_test: .word %0_10000_1010101011 ; ~33.33....
fp2_test: .word $4000 ; 2.0
fp3_test: .word $3C00 ; 1.0
; fp0_test: .word $C533 ; -5.2
; fp1_test: .word $42AB ; ~33.33....

; Random half-precision test values (16-bit words)



test_num: .byte 183 ; decimal to ascii conversion test

test_str: .byte "Hello, world!", 0
;

.code
reset:
.include "init.s"

    lda #<fp2_test
    ldx #>fp2_test
    sta ptr1
    stx ptr1 + 1

    lda #<fp_x
    ldx #>fp_x
    sta ptr2
    stx ptr2 + 1

    jsr to_fp

    lda #<fp3_test
    ldx #>fp3_test
    sta ptr1
    stx ptr1 + 1

    lda #<fp_y
    ldx #>fp_y
    sta ptr2
    stx ptr2 + 1

    jsr to_fp

    lda #<fp_z
    ldx #>fp_z
    sta ptr1
    stx ptr1 + 1

    jsr fp_add_sub
    jsr to_sci_notation

    lda #0
    sta print_idx
    print_at $2000

loop:
    jmp loop


; ------------------------------------------------------------------------------------------------------------------------
; fp arithmetic

; Does a half precision floating point addition or subtraction
; inputs: fp_x, fp_y
; output: fp_z
fp_add_sub:
    ; handle zero and NaN
;     lda fp_x + Fp16::exponent

;     lda fp_x + Fp16::mantissa

; @x_is_zero:
;     lda fp_y + Fp16::mantissa
;     lda fp_z + Fp16::mantissa
;     lda fp_y + Fp16::mantissa + 1
;     lda fp_z + Fp16::mantissa + 1
;     lda fp_y + Fp16::exponent
;     lda fp_z + Fp16::exponent
;     lda fp_y + Fp16::sign
;     lda fp_z + Fp16::sign
;     rts

    ; create significands
    lda fp_x + Fp16::mantissa + 1
    ora #$4
    sta fp_x + Fp16::mantissa + 1
    
    lda fp_y + Fp16::mantissa + 1
    ora #$4
    sta fp_y + Fp16::mantissa + 1

    @y_not_neg:

    @adjust_exponent:
        lda fp_x + Fp16::exponent
        cmp fp_y + Fp16::exponent
        beq @exp_done
        bcc @y_exp_greater
        
        lda fp_x + Fp16::exponent
        sta fp_z + Fp16::exponent

        @shift_x_loop:
            lda fp_y + Fp16::exponent
            cmp fp_x + Fp16::exponent
            bcs @y_exp_greater
            
            clc
            ror_16 fp_y + Fp16::mantissa
            inc fp_y + Fp16::exponent
            jmp @shift_x_loop

        @y_exp_greater:

        lda fp_y + Fp16::exponent
        sta fp_z + Fp16::exponent

        @shift_y_loop:
            lda fp_x + Fp16::exponent
            cmp fp_y + Fp16::exponent
            bcs @exp_done

            clc
            ror_16 fp_x + Fp16::mantissa
            inc fp_x + Fp16::exponent
            jmp @shift_y_loop

        @exp_done:


    ; fix significands' signs
    lda fp_x + Fp16::sign
    beq @x_not_negative

    lda fp_x + Fp16::mantissa + 1
    eor #$FF
    clc
    adc #1
    sta fp_x + Fp16::mantissa + 1

    lda fp_x + Fp16::mantissa
    eor #$FF
    sta fp_x + Fp16::mantissa

@x_not_negative:

    lda fp_y + Fp16::sign
    beq @y_not_negative

    lda fp_y + Fp16::mantissa + 1
    eor #$FF
    clc
    adc #1
    sta fp_y + Fp16::mantissa + 1

    lda fp_y + Fp16::mantissa
    eor #$FF
    sta fp_y + Fp16::mantissa

@y_not_negative:

    ; Z <- X ± Y
    lda arith_subtraction
    bne :+

    clc
    adc_16 fp_x + Fp16::mantissa, fp_y + Fp16::mantissa, fp_y + Fp16::mantissa+1
    jmp @fix_sign

:   sec
    sbc_16 fp_x + Fp16::mantissa, fp_y + Fp16::mantissa, fp_y + Fp16::mantissa+1

@fix_sign:
    lda fp_x + Fp16::mantissa + 1
    bmi :+

    lda #0
    sta fp_z + Fp16::sign
    jmp @sig_normalize_overflow

:   lda #1
    sta fp_z + Fp16::sign

    lda fp_x + Fp16::mantissa + 1
    eor #$FF
    clc
    adc #1
    sta fp_x + Fp16::mantissa + 1

    lda fp_x + Fp16::mantissa
    eor #$FF
    sta fp_x + Fp16::mantissa


    @sig_normalize_overflow:
        lda fp_x + Fp16::mantissa + 1
        cmp #8
        bcc @sig_normalize_underflow

        clc
        ror_16 fp_x + Fp16::mantissa
        inc fp_x + Fp16::exponent

        jmp @sig_normalize_overflow

    @sig_normalize_underflow:
        lda fp_x + Fp16::mantissa + 1
        cmp #4
        bcs @sig_done

        clc
        rol_16 fp_x + Fp16::mantissa
        dec fp_x + Fp16::exponent

        jmp @sig_normalize_underflow

    @sig_done:

        lda fp_x + Fp16::mantissa
        sta fp_z + Fp16::mantissa

        lda fp_x + Fp16::mantissa + 1
        and #%11
        sta fp_z + Fp16::mantissa + 1


        lda fp_x + Fp16::exponent
        sta fp_z + Fp16::exponent

    @done:
        rts

; converts a uint to a Float16
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

; Converts a float to a uint16
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
    lda (ptr1), y
    jsr itob


    ldy #Fp16::mantissa
    ldx #8
    lda (ptr1), y
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
    lda (ptr1), y
    sec
    sbc #15 ; get biased exponent

    jsr u8toa

    lda #0
    jsr stosb

    rts


; Converts whatever is in A into a bit string starting from the LSB
; X: number of bits to convert (1 to 8)
itob:
    pha
    ldy print_idx
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
        ; ldy print_idx         ; Get current buffer position
        sta print_buffer, y   ; Store character ('0' or '1')
        dey
        inc print_idx         ; Advance buffer length pointer
        
        pla                   ; Restore remaining bits into A
        dex                   ; Decrement bit counter (X)
        bne @loop             ; Repeat until all X bits are processed

    rts

; converts whatever is in A into an ascii string
u8toa:
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

; Stores whatever is in a into the print buffer
stosb:
    ldx print_idx
    sta print_buffer, x
    inc print_idx
    rts

transfer_sb:
    ldy #0
    ldx print_idx
    :   lda (ptr1), y
        beq @done
        sta print_buffer, x
        inc print_idx
        iny
        jmp :-
    @done:
        rts

clear_printbuf:
    ldx #0
    lda #0
    sta print_idx
    :   sta print_buffer, x
        inx
        bne :-

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

        ldx print_idx

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

    inc exec_timer

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