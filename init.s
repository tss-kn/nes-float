    sei        ; ignore IRQs
    cld        ; disable decimal mode
    ldx #$40
    stx $4017  ; disable APU frame IRQ
    ldx #$ff
    txs        ; set stack pointer to $01ff
    inx        ; now X = 0
    stx $2000  ; disable NMI
    stx $2001  ; disable rendering
    stx $4010  ; disable DMC IRQs

    ; Optional (omitted):
    ; Set up mapper and jmp to further init code here.

    ; The vblank flag is in an unknown state after reset,
    ; so it is cleared here to make sure that @vblankwait1
    ; does not exit immediately.
    bit $2002

    ; First of two waits for vertical blank to make sure that the
    ; PPU has stabilized
@vblankwait1:
    bit $2002
    bpl @vblankwait1

    ; We now have about 30,000 cycles to burn before the PPU stabilizes.
    ; One thing we can do with this time is put RAM in a known state.
    ; Here we fill it with $00, which matches what (say) a C compiler
    ; expects for BSS. Since we haven't modified the X register since
    ; the earlier code above, it's still set to 0, so we can just
    ; transfer it to the Accumulator and save a byte
    txa
@clrmem:
    sta $00,x
    sta $100,x
    sta $200,x
    sta $300,x
    sta $400,x
    sta $500,x
    sta $600,x
    sta $700,x
    inx
    bne @clrmem

    ; Other things you can do between vblank waits are set up audio
    ; or set up other mapper registers.

@vblankwait2:
    bit $2002
    bpl @vblankwait2


    lda #$3f
    sta $2006
    lda #0
    sta $2006

    lda #$30
    ldx #$0F

    stx $2007
    stx $2007
    stx $2007
    sta $2007

    stx $2007
    stx $2007
    stx $2007
    sta $2007

    stx $2007
    stx $2007
    stx $2007
    sta $2007

    stx $2007
    stx $2007
    stx $2007
    sta $2007

    lda #%10000000
    sta $2000
    lda #%00001110
    sta $2001