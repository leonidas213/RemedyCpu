#include "rulesetTinyCpu.asm"



start:
    jumpAbs initialize
    nop
interruptHandler:
    
    

returnFromInterrupt:
    reti

dividerFunc:
    ;r0 = dividend
    ;r1 = divisor
    ;r2 = quotient
    ;r3 = remainder
    div_while:
        cmp r0,r1
        jumpNegative div_end
        sub r0,r1
        addi r2,1
        jump div_while
    div_end:
        mov r3,r0
        jump end



initialize:

    ldi r0 , 0x0
    putoutput r0
    ;enable global interrupts   
    ldi r0 , 0x1
    out CpuinterruptEnable , r0

    jump programStart
    

programStart:
    
    ldi r0 ,100
    ldi r1, 2
    jump dividerFunc



jump programStart

end:
putoutput r3
putoutput r2
jump end 
