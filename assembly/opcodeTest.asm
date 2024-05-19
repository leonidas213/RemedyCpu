#include "rulesetTinyCpu.asm"



start:
    zero_all
    jump programStart
    nop
interruptHandler:
    jump returnFromInterrupt
returnFromInterrupt:
    reti
programStart:
    putoutput r0 ;0
    ldi r0,5
    putoutput r0;5
    putoutput r5 ;0
    mov r5,r0
    putoutput r0;5
    add r5,r0
    putoutput r5;10
    sub r5,r0
    putoutput r5;5
    adc r5,r0
    putoutput r5;10
    sbc r5,r0
    putoutput r5;5

    ldi r0,1
    and r0,r5
    putoutput r0;1
    ldi r0,2
    and r0,r5
    putoutput r0;0
    

    ldi r0,2
    or r0,r5
    putoutput r0;7
    ldi r0,1
    or r0,r5
    putoutput r0;5

    ldi r0,2
    xor r0,r5
    putoutput r0;7
    ldi r0,1
    xor r0,r5
    putoutput r0;4

    ldi r0,1
    lsl r0
