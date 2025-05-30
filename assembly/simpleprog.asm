#include "rulesetTinyCpu.asm"



start:
    jump setup
    nop
interruptHandler:
    jump returnFromInterrupt
    

returnFromInterrupt:
    reti

setup:
    
    ldi r0,15
    ldi r1 ,0
    forloop:
        addi r1,1
        putoutput r1
         sbci r0,1
        jumpNotNegative forloop

    
    random:
    RandomSeed 4628
    Rand r0 
    putoutput r0
    jump random


    suspend:
    jump suspend
    