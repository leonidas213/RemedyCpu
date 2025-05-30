#include "rulesetTinyCpu.asm"



start:
    jump setup
    nop
interruptHandler:
    addi r5,1
    putoutput r5
    resetTimer timer0
    jump returnFromInterrupt
    

returnFromInterrupt:
    reti

setup:

    ldi r0 , 0x0
    putoutput r0
    ;enable global interrupts   
    ldi r0 , 0x1
    out interruptEnable , r0
    ;enable timer
    
    setTimerTarget timer0, 0x10
    configureTimer timer0, 1,0,1


    configureTimer timer1, 0,0,1

programStart:
    readTimer timer0 , r0
    putoutput r0
    readTimer timer1 , r0
    putoutput r0


jump programStart
