#include"ruleset.asm"

sw1=1
sw2=2
sw3=4
sw4=8
button1=16
button2=32
button3=64
button4=128
button5=256


start:
    jmp programStart
    nop
interruptHandler:
    
readInput:
    getinput r0
    lds r1,0
    sts 0,r0
    ;compare r0 and address 0 of ram
    cpi r0,0 
    jmzs returnFromInterrupt;if r0 and address 0 of ram are equal, return from interrupt
    cpi r1,0
    jmzc returnFromInterrupt ;if r1 and address 0 of ram are not equal, return from interrupt
    
    mov r1,r0
    andi r1,sw1
    jmzc sw1Pressed

    mov r1,r0
    andi r1,sw2
    jmzc sw2Pressed

    mov r1,r0
    andi r1,sw3
    jmzc sw3Pressed

    mov r1,r0
    andi r1,sw4
    jmzc sw4Pressed

    mov r1,r0
    andi r1,button1
    jmzc button1Pressed

    mov r1,r0
    andi r1,button2
    jmzc button2Pressed

    mov r1,r0
    andi r1,button3
    jmzc button3Pressed

    mov r1,r0
    andi r1,button4
    jmzc button4Pressed

    mov r1,r0
    andi r1,button5
    jmzc button5Pressed



    sw1Pressed:
        ldi r0,1
        jmp returnFromInterrupt
    sw2Pressed:
        ldi r0,2
        jmp returnFromInterrupt
    sw3Pressed:
        ldi r0,3
        jmp returnFromInterrupt
    sw4Pressed:
        ldi r0,4
        jmp returnFromInterrupt
    button1Pressed:
        ldi r0,5
        jmp returnFromInterrupt
    button2Pressed:
        ldi r0,6
        jmp returnFromInterrupt
    button3Pressed:
        ldi r0,7
        jmp returnFromInterrupt
    button4Pressed:
        ldi r0,8
        jmp returnFromInterrupt
    button5Pressed:
        ldi r0,9
        jmp returnFromInterrupt
returnFromInterrupt:
    reti
programStart:
    putoutput r0
    jmp programStart

