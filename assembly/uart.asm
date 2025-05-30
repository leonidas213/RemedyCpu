#include "rulesetTinyCpu.asm"



start:
    jumpAbs initialize
    nop
interruptHandler:
    
    

returnFromInterrupt:
    reti


initialize:

    ldi r0 , 0x0
    putoutput r0
    ;enable global interrupts   
    ldi r0 , 0x1
    out CpuinterruptEnable , r0

    jump programStart
    

programStart:
    
    ldi r0 ,48
    ldi r1,3
    for:
        out uartTransmit , r0
        subi r1,1
        jumpNotNegative for
    jump end


jump programStart

end:
nop
jump end 
