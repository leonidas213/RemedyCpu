#include "rulesetTinyCpu.asm"


start:
    jump setup
    nop
interruptHandler:
    
    jump returnFromInterrupt
    

returnFromInterrupt:
    reti
    reti

setup:

   ldi r0,14
   ldi r0,14
   ldi r0,14
   ldi r1,5
   sbc r1,r0 
   ldi r5,setup
   readflags r2
   ldi r0 ,14
   ldi r1 ,14
   sub r0,r1 
   writeflags r2 


