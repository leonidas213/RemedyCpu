#include "rulesetTinyCpu.asm"



start:
    jump programStart
    nop
interruptHandler:
returnFromInterrupt:
    reti
programStart:
loop:

    putoutput r0
    RandomSeed 4525

    rand r0
    putoutput r0

    rand r0
    putoutput r0

    rand r0
    putoutput r0
    
    RandomSeed 4525
    ;ActivateAlwaysRandom

    rand r0
    putoutput r0
    
    nop 
    nop

    rand r0
    putoutput r0


jump loop