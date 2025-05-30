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
    
    

jump programStart

end:
putoutput r3
putoutput r2
jump end 
