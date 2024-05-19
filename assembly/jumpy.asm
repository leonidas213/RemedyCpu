#include "rulesetTinyCpu.asm"



start:

    ldi r0 ,0xff
    putoutput r0
    ldi r0 ,0x0
    ldi r1 ,1
forloop2:
    addi r0,1
    sts 10,r0
    putoutput r0
    lds r4,10
    addi r4 ,3
    putoutput r4

    cpi r0,0xf
    jumpNegative forloop2

    ldi r0 ,0x0
    jump programStart
    nop
interruptHandler:
    jump returnFromInterrupt
returnFromInterrupt:
    reti


programStart:
    jump jumpLabel
    nop 
    nop 
jumpLabel:

    ldi r0,5
    andi r0 ,2
    jumpNotZero nextLabel
    andi r0,5
    jumpZero nextLabel
    nop 
    nop 
    nop
nextLabel:
    ldi r5,15
forloop:
    putoutput r5
    sbci r5,1
    jumpNotNegative forloop

    nop
    nop
jump programStart
