;CPU SPECS
;36 half-word ram memory (16bit x 36)
;Random number generator
;up counting timer with;
;   -reload
;   -interrupt
;   -read
;ALU that can;
;   -addition
;   -substraction
;   -and
;   -or
;   -xor
;   -not
;   -make number negative
;   -logical shift left   
;   -logical shift right
;   -arithmetic shift right
;   -swapBytes
;   -swapNibbles
;   -multiplication
;negative,zero,carry flags
;immediate register to put 16 bit numbers in to the registers   
;jump to absolute or relative program addresses   
;configurable 4 GPIO pins(either input or output)   
;   
;   
;   

;//Todo: jmp is only absolute? 


;every registers default value is 0
timerEnable=1;1bit
timerPrescaler=2 ;3bit
timerTarget=3;16bit can work with interrupt
timerReload=4;1bit
timerReset=5;1bit

interruptEnable=6;1bit

OutputReg =7 ;4bit
OutputEnable =8 ;4bit if bit set 1 it become output if zero it become input

;random number generator
;RNG is always active at every clock cycle
RandomSeedAddr =9        ;seed location


#bankdef data
{
	#bits 16
	#outp 0
}
#subruledef registers
{
    r0 => 0
    r1 => 1
    r2 => 2
    r3 => 3
    r4 => 4
    r5 => 5
    r6 => 6
    r7 => 7
    r8 => 8
    r9 => 9
    r10 => 10
    r11 => 11
    r12 => 12
    r13 => 13;bp
    r14 => 14;sp
    r15 => 15;ra
    BP=>0xd
    SP=>0xe;stack pointer
    RA=>0xf;return addree

}
#ruledef 
{
    ;todo jump absolute

    ; Does nothing.
    nop => 0x0000
    ; Move the content of Rs to register Rd
    mov {rd:registers} , {rs:registers} => 0x01 @rd`4 @rs`4

    ; Adds the content of register Rs to register Rd without carry.
	add	{rd:registers} , {rs:registers} => 0x02 @rd`4 @rs`4

    ; Adds the content of register Rs to register Rd with carry.
    adc	{rd:registers} , {rs:registers} => 0x03 @rd`4 @rs`4

    ; Subtracts the content of register Rs from register Rd without carry.
    sub	{rd:registers} , {rs:registers} => 0x04 @rd`4 @rs`4

    ; Subtracts the content of register Rs from register Rd with carry.
    sbc	{rd:registers} , {rs:registers} => 0x05 @rd`4 @rs`4

    ; Stores Rs and Rd in register Rd.
    and	{rd:registers} , {rs:registers} => 0x06 @rd`4 @rs`4

    ; Stores Rs or Rd in register Rd.
    or	{rd:registers} , {rs:registers} => 0x07 @rd`4 @rs`4

    ; Stores Rs xor Rd in register Rd.
    xor	{rd:registers} , {rs:registers} => 0x08 @rd`4 @rs`4

    ;Loads Register Rd with the constant value [value].
    ldi {rd:registers} , {value: u4} => 
    {   
        0x0a @rd`4 @value`4
    }
    ldi {rd:registers} , {value:i16} => 
    {   lv=value[15:15]
        (0x8000 | value)`16 @0x09 @rd`4 @lv`4
    }

    ;Adds the constant [value] to register Rd without carry.
    addi {rd:registers} , {value: u4} => 
    {   
        0x0c @rd`4 @value`4
    }
    addi {rd:registers} , {value:i16} => 
    {   
        lv=value[15:15]
        (0x8000 | value)`16 @0x0b @rd`4 @lv`4
    }

    ; Adds the constant [value] to register Rd with carry.
    adci {rd:registers} , {value: u4} => 
    {   
        0x0e @rd`4 @value`4
    }
    adci {rd:registers} , {value:i16} => 
    {   lv=value[15:15]
        (0x8000 | value)`16 @0x0d @rd`4 @lv`4
    }

    ; Subtracts the constant [value] from register Rd without carry.
    subi {rd:registers} , {value: u4} => 
    {   
        0x10 @rd`4 @value`4
    }
    subi {rd:registers} , {value:i16} => 
    {   lv=value[15:15]
        (0x8000 | value)`16 @0x0f @rd`4 @lv`4
    }

    ; Subtracts the constant [value] from register Rd with carry.
    sbci {rd:registers} , {value: u4} => 
    {   
        0x12 @rd`4 @value`4
    }
    sbci {rd:registers} , {value:i16} => 
    {   lv=value[15:15]
        (0x8000 | value)`16 @0x11 @rd`4 @lv`4
    }

    ;Stores the two's complement of Rd in register Rd.
    neg {rd:registers} => 0x13 @rd`4 @0`4

    ;Stores Rd and [value] in register Rd
    andi {rd:registers} , {value: u4} => 
    {   
        0x15 @rd`4 @value`4
    }
    andi {rd:registers} , {value:i16} => 
    {   lv=value[15:15]
        (0x8000 | value)`16 @0x14 @rd`4 @lv`4
    }
    
    ;Stores Rd or [value] in register Rd
    ori {rd:registers} , {value: u4} => 
    {   
        0x17 @rd`4 @value`4
    }
    ori {rd:registers} , {value:i16} => 
    {   lv=value[15:15]
        (0x8000 | value)`16 @0x16 @rd`4 @lv`4
    }

    ;Stores Rd xor [value] in register Rd
    xori {rd:registers} , {value: u4} => 
    {   
        0x19 @rd`4 @value`4
    }
    xori {rd:registers} , {value:i16} => 
    {   lv=value[15:15]
        (0x8000 | value)`16 @0x18 @rd`4 @lv`4
    }

    ;Stores not Rd in register Rd.
    not {rd:registers} => 0x1a @rd`4 @0`4
    
    ;Multiplies the content of register Rs with register Rd and stores result in Rd.
    mul {rd:registers} , {rs:registers} => 0x1b @rd`4 @rs`4
    
    ;Multiplies the constant [const] with register Rd and stores result in Rd
    muli {rd:registers} , {value: u4} => 
    {   
        0x1d @rd`4 @value`4
    } 
    muli {rd:registers} , {value:i16} => 
    {   lv=value[15:15]
        (0x8000 | value)`16 @0x1c @rd`4 @lv`4
    }

    ;Subtracts the content of register Rs from register Rd without carry, does not store the result
    cmp {rd:registers} , {rs:registers} => 0x1e @rd`4 @rs`4

    ;Subtracts the content of register Rs from register Rd with carry, does not store the result.
    cpc {rd:registers} , {rs:registers} => 0x1f @rd`4 @rs`4

    ;Subtracts a constant [const] from register Rd without carry, does not store the result
    cpi {rd:registers} , {value: u4} => 
    {   
        0x21 @rd`4 @value`4
    }
    cpi {rd:registers} , {value:i16} => 
    {   lv=value[15:15]
        (0x8000 | value)`16 @0x20 @rd`4 @lv`4
    }

    ;Subtracts a constant [const] from register Rd with carry, does not store the result.
    cpci {rd:registers} , {value: u4} => 
    {   
        0x23 @rd`4 @value`4
    }
    cpci {rd:registers} , {value:i16} => 
    {   lv=value[15:15]
        (0x8000 | value)`16 @0x22 @rd`4 @lv`4
    }

    ;Shifts register Rd by one bit to the left. A zero bit is filled in and the highest bit is moved to the carry bit.
    lsl {rd:registers} => 0x24 @rd`4 @0`4

    ;Shifts register Rd by one bit to the right. A zero bit is filled in and the lowest bit is moved to the carry bit.
    lsr {rd:registers} => 0x25 @rd`4 @0`4

    ;Shifts register Rd by one bit to the left. The carry bit is filled in and the highest bit is moved to the carry bit.
    rol {rd:registers} => 0x26 @rd`4 @0`4

    ;Shifts register Rd by one bit to the right. The carry bit is filled in and the lowest bit is moved to the carry bit.
    ror {rd:registers} => 0x27 @rd`4 @0`4

    ;Shifts register Rd by one bit to the right. The MSB
    ;remains unchanged and the lowest bit is moved to the carry bit
    asr {rd:registers} => 0x28 @rd`4 @0`4

    ;Swaps the high and low byte in register Rd.
    swap {rd:registers} => 0x29 @rd`4 @0`4

    ;Swaps the high and low nibbles of both bytes in register Rd.
    swapn {rd:registers} => 0x2a @rd`4 @0`4

    ;Stores the content of register Rs to the memory at the
    ;address [Rd]
    st [{rd:registers}], {rs:registers} => 0x2b @rd`4 @rs`4

    ;Loads the value at memory address [Rs] to register Rd
    ld {rd:registers} , [{rs:registers}] => 0x2c @rd`4 @rs`4

    ;Stores the content of register Rs to memory at the
    ;location given by [const].
    sts {value: u4} , {rd:registers}  => 
    {   
        0x2e @value`4 @rd`4
    }
    sts {value:i16} , {rd:registers}  => 
    {   lv=value[15:15]
        (0x8000 | value)`16 @0x2d @lv`4 @rd`4
    }

    ;Loads the memory value at the location given by
    ;[const] to register Rd.
    lds {rd:registers} , {value: u4} => 
    {   
        0x30 @rd`4 @value`4
    }
    lds {rd:registers} , {value:i16} => 
    {   lv=value[15:15]
        (0x8000 | value)`16 @0x2f @rd`4 @lv`4
    }

    ;Loads the value at memory address (Rs+[const]) to
    ;register Rd.
    std [{rd:registers} + {value}] , {rs:registers} =>
	{
	    (0x8000 | value)`16 @0x31 @rd`4 @rs`4
	}
    std [{rd:registers} - {value}] , {rs:registers} =>
	{   vtemp=0-value
	    (0x8000 | vtemp)`16 @0x31 @rd`4 @rs`4
	}
    ldd {rd:registers} , [{rs:registers} + {value}] =>
    {
        (0x8000 | value)`16 @0x32 @rd`4 @rs`4
    }
    ldd {rd:registers} , [{rs:registers} - {value}] =>
    {       
        vtemp=0-value
        (0x8000 | vtemp)`16 @0x32 @rd`4 @rs`4
    }
    lpm {rd:registers} , [{rs:registers}] =>
    {
            0x33 @rd`4 @rs`4
    }
    jumpCarry {value: i8} => 
    {   relad=(value-pc-1)
        0x34 @relad`8
    }
    jumpZero {value: i8} => 
    {   relad=(value-pc-1)
        0x35 @relad`8
    }
    jumpNegative {value: i8} => 
    {   relad=(value-pc-1)
        0x36 @relad`8
    }
    jumpNotCarry {value: i8} => 
    {   relad=(value-pc-1)
        0x37 @relad`8
    }
    jumpNotZero {value: i8} => 
    {   relad=(value-pc-1)
        0x38 @relad`8
    }
    jumpNotNegative {value: i8} => 
    {   relad=(value-pc-1)
        0x39 @relad`8
    }
    rcall {rd:registers} ,{value:i16} =>
    {lv=value[15:15]
        (0x8000 | value)`16 @0x3a @rd`4 @lv`4
    } 
    rret {rs:registers} => 
    {   
        0x3b @0`4 @rs`4
    }
    jump {value: i8} => 
    {   relad=(value-pc-1)
		assert(relad <= 129)		
		assert(relad >= -129)

		0x3d @relad`8
    }
    jump {value: i16} => 
    {   lv=value[15:15]
        (0x8000 | value)`16 @0x3c @0`4 @lv`4
    }
	
    out {value: u4} , {rd:registers}  => 
    {   
        0x3f @value`4 @rd`4
    }
    out {value: i16} , {rd:registers}  => 
    {   lv=value[15:15]
        (0x8000 | value)`16 @0x3e @lv`4 @rd`4
    }
   
    outr [{rd:registers}] , {rs:registers}  => 
    {   
        0x40 @rd`4 @rs`4
    }
    getinput {rd:registers} => 
    {   
        0x42 @rd`4 @0x4`4
    }
    
    inr {rd:registers} , [{rs:registers}]  => 
    {   
        0x43 @rd`4 @rs`4
    }
    reti => 0x44 @0`4 @0`4

    rdflg {rd:registers} => 0x45 @rd`4 @0`4
    
    ;wrflg {rs:registers} => 0x46 @0`4 @rs`4

    Rand {rd:registers} => 0x47 @rd`4 @0`4
    timer {rd:registers} => 0x48 @rd`4 @0`4
   
    ;--------------macros-----------------------
    zero {rd:registers} => asm{
        addi {rd} , 0
    }
    zero_all => asm{
        zero r0
        zero r1
        zero r2
        zero r3
        zero r4
        zero r5
        zero r6
        zero r7
        zero r8
        zero r9
        zero r10
        zero r11
        zero r12
        zero r13
        zero r14
        zero r15}
    dec {rd:registers} => asm{
        subi {rd} , 1
    }
    inc {rd:registers} => asm{
        addi {rd} , 1
    }
	loadStr {string:i16} , {startAdr:i32} => asm{

		ldi r0 , {startAdr}
		sts {string} , r0

	}
	
	pop {rd:registers}=> asm{
		ld {rd} , [SP]
		addi SP , 1
	}
	
	push{rd:registers}=> asm{
		subi SP,1
		st [SP],{rd}
	}
	
	ret {value}=> asm{
		ld RA,[SP]
		addi SP, {value+1}
		rcall RA
	}
	call {value}=> asm{
		subi SP,1
		ldi RA,[$+2]
		st [SP],RA
		jmp {value}
		
	}
	enter {value}=>asm{
		subi SP,1
		st [SP],BP
		mov BP,SP
		subi SP, {value}
	}
	enteri{value}=>asm{
		std[SP-1],r0
		in r0,0
		std [SP-2],r0
		subi SP,2
	}
	leave => asm{
		mov SP,BP
		ld BP,[SP]
		addi SP,1
	}
	leavei=>asm{
		addi SP,2
		ldd r0, [SP-2]
		out 0,r0
		ldd r0,[SP-1]
	}
	_scall {value} =>asm{
		subi SP,1
		st [SP],RA
		rcall RA,{value}
		ld RA,[SP]
		addi SP,1
	}
    enableOutput {rd:registers} => asm{
        out OutputEnable , {rd}}

    putoutput {rd:registers} => asm{
        out OutputReg , {rd}
    }
    readRandomRange {rd:registers} , {min:i16} , {max:i16},{rDummy1:registers},{rDummy2:registers} => asm{
        ldi rDummy1 , {min}
        ldi rDummy2 , {max}
        sub rDummy2 , rDummy1
        Rand rd
        and rd , rDummy2
        add rd , rDummy1
    }
    RandomSeed {value : i16} => asm{
        ldi r12 ,{value}
        out RandomSeedAddr , r12
    }
  
    
    

                                        
} 
