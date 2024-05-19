#include "rulesetTinyCpu.asm"



start:
    jump programStart
    nop
interruptHandler:
    jump returnFromInterrupt
returnFromInterrupt:
    reti
programStart:
    ldi r0,5
    putoutput r0    ;expected 5

    mov r1,r0 
    putoutput r1      ;expected 5

    ldi r0,1
    add r1,r0 
    putoutput r1    ;expected 6

    ldi r0,4
    sub r1,r0 
    putoutput r1    ;expected 2

    ldi r0,6
    ldi r1,4
    and r0,r1 
    putoutput r1    ;expected 4

    ldi r0,1
    ldi r1,6
    or r0,r1 
    putoutput r0    ;expected 7

    ldi r0,2
    ldi r1,6
    xor r0,r1 
    putoutput r0    ;expected 4

    addi r1,5
    putoutput r1    ;expected 9

    ldi r1,2
    neg r1
    putoutput r1    ;expected 0xfffe

    not r1 
    putoutput r1    ;expected 1

    ldi r0,2
    ldi r1,3 
    mul r1,r0 
    putoutput r1    ;expected 6


    RandomSeed 4526
    rand r0         ;expected 11AE

    ;sts 5,r0
    ldi r5,15
forloop:
    sbci r5,1
    jumpNotNegative forloop

    rand r0
    ldi r1,0
loop:
    addi r1,1
    
    putoutput r1
    jump loop