; CPU SPECS
; external spi memory up to 64k
; external serial rom up to 64k
; which works like this
; 
; first you it read 16 bit program address from cpu
; then send 16 bit opcode to cpu
; then you send 3 clock cycles to cpu so it can execute the opcode
; rinse and repeat
;
;     
;                  _   _    _   _    _   _    _   _    _   _    _   _    _   _    _   _   _   _    _   _    _   _    _   _    _   _    _   _    _   _    _   _   _    _   _   
;  CLOCK         _/ \_/ \__/ \_/ \__/ \_/ \__/ \_/ \__/ \_/ \__/ \_/ \__/ \_/ \__/ \_/ \_/ \_/ \__/ \_/ \__/ \_/ \__/ \_/ \__/ \_/ \__/ \_/ \__/ \_/ \__/ \_/ \_/ \__/ \_/ \___| o o o
;                ------------------------------------------------------------------------ -----------------------------------------------------------------------------------  | o o o
;  Bit numbers   | 15| 14 | 13| 12 | 11| 10 |  9|  8 |  7|  6 |  5|  4 |  3|  2 |  1| 0 | 15| 14 | 13| 12| 11 | 10 |  9|  8 |  7|  6|  5 |  4|  3 |  2|  1 |  0| 
;  Datas         |                  Program Counter(Program Address)                    |                          Opcode(Operation code)                      | 3 clock cycles| o o o
;
; Yeah i know it is slow but it is what it is
; so if you have 35 mhz clock this cpu will run at 1mhz :D
; Anyway here is the cpu specs
; 
; Total of 16 general purpouse registers that can hold 16 bit numbers
;  or 13 general purpouse registers and stack pointer, branch pointer, return address registers
; 
; A Random number generator (linear feedback shift register) that generates 16 bit random numbers at every clock cycle but you need to seed it first
; - 3 16-bit timers with:
;      - Reload functionality after reaching the target value
;      - Interrupt generation upon reaching the target
;      - Capability to read the timer value
;      - Timer reset functionality
;      - 3-bit prescaler ranging from 1x (1 clock cycle per tick) to 128x (128 clock cycles per tick)

; Arithmetic Logic Unit (ALU) capabilities include:
; - Addition
; - Subtraction
; - Bitwise AND
; - Bitwise OR
; - Bitwise XOR
; - Bitwise NOT
; - Negation
; - Logical shift left
; - Logical shift right
; - Arithmetic shift right
; - Byte swapping
; - Nibble swapping
; - Multiplication
; - Division
;
; Flags: Negative, Zero, Carry
; Immediate register for storing 16-bit values
; Jump instructions supporting both absolute and relative addresses
; Configurable 4 GPIO pins (either input or output) 
; Input pins can trigger interrupts (not edge-sensitive, shared interrupt line, global enable/disable) 
;   -input pins can generate interrupt but it is not edge sensitive   
;   and it is not possible to disable interrupt for a specific pin
;   because all input pins share the same interrupt line
;   so the interrupt happens when any of the input pins change (and you don't know which one caused it)
; Interrupts can be enabled or disabled globally
; Interrupt register to manage and read active interrupts (3 timers, 1 input pin)
; Interrupt register format:
;|    15-4    |       3      |    2   |   1    |   0    |
;|------------|--------------|--------|--------|--------|
;|  always 0  |inputInterrupt| timer3 | timer2 | timer1 |


; every registers default value is 0
;----------   WRITABLE REGISTERS   -------------
timer1Config = 1        ;5-bit    |    1 bit       |  1 bit  |    3 bit   | 1 bit  |  
                        ;         |Interrupt enable| reload  |  prescaler | enable |

timer1Target = 2        ; 16-bit target value for interrupt generation
timer1Reset = 3         ; 1-bit reset timer
timer2Config = 4        ; Similar configuration as timer1
timer2Target = 5        ; 16-bit target value for timer2
timer2Reset = 6         ; 1-bit reset timer2
timer3Config = 7        ; Similar configuration as timer1
timer3Target = 8        ; 16-bit target value for timer3
timer3Reset = 9         ; 1-bit reset timer3

CpuinterruptEnable = 10   ; 1-bit

OutputReg = 11          ; 8-bit data for GPIO pins
OutputEnable = 12       ; 8-bit configuration for GPIO pins (input/output)

; random number generator
; RNG is always active at every clock cycle
RandomSeedAddr = 13        ;16-bit seed location
RandomAdr=13
InputInterruptEnable = 14 ;1-bit if 1, input pins interrupt is enabled

uartTransmit = 16

;----------   READABLE REGISTERS   -------------
timer1ReadAdr = 1       ;16-bit
timer2ReadAdr = 2       ;16-bit
timer3ReadAdr = 3       ;16-bit
InterruptRegister = 4   ;16-bit

; ---------- PROGRAMMING EXAMPLES -----------
; Example 1: Basic addition and store result in memory
; Load immediate values into registers and add them
;
; ldi r1, 0x10            ; Load 0x10 into r1
; ldi r2, 0x20            ; Load 0x20 into r2
; add r1, r2              ; Add r1 and r2, store result in r1
; sts r1, 0x1000          ; Store result from r1 into memory address 0x1000
; ldi r2, 0xff
; out outputEnable, r2    ; Enable all output pins
; putoutput r1            ; Output result from r1

; Example 2: Timer configuration
; ldi r1, 0x01            ; Enable timer into r1
; ldi r2, 0x1000          ; Load target value into r2
; out timer1Config, r1    ; Enable timer1 with prescaler value 1x with no reload and no interrupt
; out timer1Target, r2    ; Set timer1 target value
; loop:
;    in  r1, timer1ReadAdr   ; Read timer1 value
;    putoutput r1            ; Output timer1 value
;    jump loop               ; Loop indefinitely


#bankdef data
{
	#bits 16
	#outp 0
}
#subruledef timers
{
    timer0 => 0
    timer1 => 1
    timer2 => 2
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
    BP => 0xd;branch pointer
    SP => 0xe;stack pointer
    RA => 0xf;return addres

}
#ruledef 
{
    ;todo adresses 33,45,46,47 are empty  0x50 need to be deleted
    ;todo investigate jump logic potential bug maybe
    ;todo maybe add max/min that returns the bigger register or value?
    ; sleep, gettick
    ; id that return cpuid?
    ; cpu cache?
    ; adding bram
    ;__________
    ; Does nothing.
    nop => 0x0000
    ;______________________________________________________________________
    ; Move the content of Rs to register Rd
    mov {rd:registers},{rs:registers} => 0x01 @rd`4 @rs`4
    ;______________________________________________________________________
    ; Adds the content of register Rs or an immediate constant [value] to register Rd without carry.
	add	{rd:registers},{rs:registers} => 0x02 @rd`4 @rs`4
    add {rd:registers},{value: u4} => 
    {   
        0x0c @rd`4 @value`4
    }
    add {rd:registers},{value:i16} => 
    {   
        lv=value[15:15]
        (0x8000 | value)`16 @0x0b @rd`4 @lv`4
    }
    ;______________________________________________________________________
    ; Adds the content of register Rs or an immediate constant [value] to register Rd with carry.
    adc	{rd:registers},{rs:registers} => 0x03 @rd`4 @rs`4
    adc {rd:registers},{value: u4} => 
    {   
        0x0e @rd`4 @value`4
    }
    adc {rd:registers},{value:i16} => 
    {   lv=value[15:15]
        (0x8000 | value)`16 @0x0d @rd`4 @lv`4
    }
    ;______________________________________________________________________
    ; Subtracts the content of register Rs or an immediate constant [value] from register Rd without carry.
    sub	{rd:registers},{rs:registers} => 0x04 @rd`4 @rs`4
    sub {rd:registers},{value: u4} => 
    {   
        0x10 @rd`4 @value`4
    }
    sub {rd:registers},{value:i16} => 
    {   lv=value[15:15]
        (0x8000 | value)`16 @0x0f @rd`4 @lv`4
    }
    ;______________________________________________________________________
    ; Subtracts the content of register Rs or an immediate constant [value] from register Rd with carry.
    sbc	{rd:registers},{rs:registers} => 0x05 @rd`4 @rs`4
    sbc {rd:registers},{value: u4} => 
    {   
        0x12 @rd`4 @value`4
    }
    sbc {rd:registers},{value:i16} => 
    {   lv=value[15:15]
        (0x8000 | value)`16 @0x11 @rd`4 @lv`4
    }
    ;______________________________________________________________________
    ; Performs a bitwise AND between Rd and Rs or an immediate constant [value], and stores the result in Rd.
    and	{rd:registers},{rs:registers} => 0x06 @rd`4 @rs`4
    and {rd:registers},{value: u4} => 
    {   
        0x15 @rd`4 @value`4
    }
    and {rd:registers},{value:i16} => 
    {   lv=value[15:15]
        (0x8000 | value)`16 @0x14 @rd`4 @lv`4
    }
    ;______________________________________________________________________
    ; Performs a bitwise OR between Rd and Rs or an immediate constant [value], and stores the result in Rd.
    or	{rd:registers},{rs:registers} => 0x07 @rd`4 @rs`4
    or {rd:registers},{value: u4} => 
    {   
        0x17 @rd`4 @value`4
    }
    or {rd:registers},{value:i16} => 
    {   lv=value[15:15]
        (0x8000 | value)`16 @0x16 @rd`4 @lv`4
    }
    ;______________________________________________________________________
    ; Performs a bitwise XOR between Rd and Rs or an immediate constant [value], and stores the result in Rd.
    xor	{rd:registers},{rs:registers} => 0x08 @rd`4 @rs`4
    xor {rd:registers},{value: u4} => 
    {   
        0x19 @rd`4 @value`4
    }
    xor {rd:registers},{value:i16} => 
    {   lv=value[15:15]
        (0x8000 | value)`16 @0x18 @rd`4 @lv`4
    }
    ;______________________________________________________________________
    ;Loads Register Rd with the constant value [value].
    ldi {rd:registers},{value: u4} => 
    {   
        0x0a @rd`4 @value`4
    }
    ldi {rd:registers},{value:i16} => 
    {   lv=value[15:15]
        (0x8000 | value)`16 @0x09 @rd`4 @lv`4
    }
    ;______________________________________________________________________
    ;Stores the two's complement of Rd in register Rd.
    neg {rd:registers} => 0x13 @rd`4 @0`4
    ;______________________________________________________________________
    ;Stores not Rd in register Rd.
    not {rd:registers} => 0x1a @rd`4 @0`4
    ;______________________________________________________________________    
    ; Performs multiplication of Rd, and Rs or an immediate constant [value], and stores the result in Rd.
    mul {rd:registers},{rs:registers} => 0x1b @rd`4 @rs`4
    mul {rd:registers},{value: u4} => 
    {   
        0x1d @rd`4 @value`4
    } 
    mul {rd:registers},{value:i16} => 
    {   lv=value[15:15]
        (0x8000 | value)`16 @0x1c @rd`4 @lv`4
    }
    ;______________________________________________________________________
    ; Compares Rd, and Rs or an immediate constant [value] (subtracts Rs from Rd without storing the result) Without using carry flag.
    ; Flags are updated accordingly.
    cmp {rd:registers},{rs:registers} => 0x1e @rd`4 @rs`4
    cmp {rd:registers},{value: u4} => 
    {   
        0x21 @rd`4 @value`4
    }
    cmp {rd:registers},{value:i16} => 
    {   lv=value[15:15]
        (0x8000 | value)`16 @0x20 @rd`4 @lv`4
    }
    ;______________________________________________________________________
      ; Compares Rd, and Rs or an immediate constant [value] (subtracts Rs from Rd without storing the result) With carry flag.
    ; Flags are updated accordingly.
    cpc {rd:registers},{rs:registers} => 0x1f @rd`4 @rs`4
    cpc {rd:registers},{value: u4} => 
    {   
        0x23 @rd`4 @value`4
    }
    cpc {rd:registers},{value:i16} => 
    {   lv=value[15:15]
        (0x8000 | value)`16 @0x22 @rd`4 @lv`4
    }
    ;______________________________________________________________________

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

    ;______________________________________________________________________
    ;Stores the content of register Rs to the memory at the
    ;address [Rd]
    st [{rd:registers}], {rs:registers} => 0x2b @rd`4 @rs`4

    ;Loads the value at memory address [Rs] to register Rd
    ld {rd:registers},[{rs:registers}] => 0x2c @rd`4 @rs`4
    ;______________________________________________________________________
    ;Stores the content of register Rs to memory at the
    ;location given by [const].
    st [{value: u4}],{rs:registers}  => 
    {   
        0x2e @value`4 @rs`4
    }
    st [{value:i16}],{rd:registers}  => 
    {   lv=value[15:15]
        (0x8000 | value)`16 @0x2d @lv`4 @rs`4
    }
    ;______________________________________________________________________
    ;Loads the memory value at the location given by
    ;[const] to register Rd.
    ld {rd:registers},[{value: u4}] => 
    {   
        0x30 @rd`4 @value`4
    }
    ld {rd:registers},[{value:i16}] => 
    {   lv=value[15:15]
        (0x8000 | value)`16 @0x2f @rd`4 @lv`4
    }
    ;______________________________________________________________________
    ;Loads the value at memory address (Rs+[const]) to
    ;register Rd.
    st [{rd:registers} + {value}],{rs:registers} =>
	{
	    (0x8000 | value)`16 @0x31 @rd`4 @rs`4
	}
    st [{rd:registers} - {value}],{rs:registers} =>
	{   vtemp=0-value
	    (0x8000 | vtemp)`16 @0x31 @rd`4 @rs`4
	}
    ;______________________________________________________________________
    ld {rd:registers},[{rs:registers} + {value}] =>
    {
        (0x8000 | value)`16 @0x32 @rd`4 @rs`4
    }
    ld {rd:registers},[{rs:registers} - {value}] =>
    {       
        vtemp=0-value
        (0x8000 | vtemp)`16 @0x32 @rd`4 @rs`4
    }
    ;______________________________________________________________________
    ;lpm {rd:registers},[{rs:registers}] =>
    ;{
    ;        0x33 @rd`4 @rs`4
    ;}
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
    jump {value: i16} => ;relative
    {   relad=(value-pc-1)
		assert(relad <= 129)		
		assert(relad >= -129)

		0x3d @relad`8
    }
    jump {value: i16} => ;absolute
    {   lv=value[15:15]
        (0x8000 | value)`16 @0x3c @0`4 @lv`4
    }
	
    out {value: u4},{rd:registers}  => 
    {   
        0x3f @value`4 @rd`4
    }
    out {value: i16},{rd:registers}  => 
    {   lv=value[15:15]
        (0x8000 | value)`16 @0x3e @lv`4 @rd`4
    }
   
    outr [{rd:registers}],{rs:registers}  => 
    {   
        0x40 @rd`4 @rs`4
    }
    getinput {rd:registers} => 
    {   
        0x42 @rd`4 @0x4`4
    }
    in {rd:registers},  {value: i16}  => 
    {   lv=value[15:15]
        (0x8000 | value)`16 @0x41 @rd`4 @lv`4
    }
    in {rd:registers}, {value: u4}=> 
    {   
        0x42 @rd`4 @value`4
    }
    inr {rd:registers},[{rs:registers}]  => 
    {   
        0x43 @rd`4 @rs`4
    }
    reti => 0x44 @0`4 @0`4

    ;rdflg {rd:registers} => 0x45 @rd`4 @0`4
    
    ;wrflg {rs:registers} => 0x46 @0`4 @rs`4

    ;Read from random number generator to register Rd.
    ;Rand {rd:registers} => 0x47 @rd`4 @0`4
    
    readflags {rd:registers} => 0x48 @rd`4 @0`4
    
    writeflags {rd:registers} => 0x49 @rd`4 @0`4

    ; Divides Rd, by Rs or an immediate constant [value], storing the quotient in Rd.
    div {rd:registers},{rs:registers} => 0x4A @rd`4 @rs`4
    div {rd:registers},{value: u4} => 
    {   
        0x4D @rd`4 @value`4
    }
    div {rd:registers},{value:i16} => 
    {   lv=value[15:15]
        (0x8000 | value)`16 @0x4C @rd`4 @lv`4
    }

    ; Divides Rd, by Rs or an immediate constant [value], storing the remainder in Rd.
    mod {rd:registers},{rs:registers} => 0x4B @rd`4 @rs`4
    mod {rd:registers},{value: u4} => 
    {   
        0x4F @rd`4 @value`4
    }
    mod {rd:registers},{value:i16} => 
    {   lv=value[15:15]
        (0x8000 | value)`16 @0x4E @rd`4 @lv`4
    }

    ;jumpAbs {value: i16} => 
    ;{   lv=value[15:15]
    ;    (0x8000 | value)`16 @0x50 @0`4 @lv`4
    ;}
    ;--------------macros-----------------------
    readTimer {value: timers},{rd:registers}  => asm{
      in rd, value+1
        ;0x48 @rd`4 @(value+1)`4

    }
    zero {rd:registers} => asm{
        ldi {rd},0
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
        sub {rd},1
    }
    inc {rd:registers} => asm{
        add {rd},1
    }
	loadStr {string:i16},{startAdr:i32} => asm{

		ld r0,{startAdr}
		st {string},r0

	}
	
	pop {rd:registers}=> asm{
		ld {rd},[SP]
		add SP,1
	}
	
	push{rd:registers}=> asm{
		sub SP,1
		st [SP],{rd}
	}
	
	ret {value}=> asm{
		ld RA,[SP]
		add SP, {value+1}
		rcall RA
	}
	call {value}=> asm{
		sub SP,1
		ld RA,[$+2]
		st [SP],RA
		jmp {value}
		
	}
	enter {value}=>asm{
		sub SP,1
		st [SP],BP
		mov BP,SP
		sub SP, {value}
	}
	enteri {value}=>asm{
		std[SP-1],r0
		in r0,0
		std [SP-2],r0
		sub SP,2
	}
	leave => asm{
		mov SP,BP
		ld BP,[SP]
		add SP,1
	}
	leavei => asm{
		add SP,2
		ld r0, [SP-2]
		out 0,r0
		ld r0,[SP-1]
	}
	_scall {value} =>asm{
		sub SP,1
		st [SP],RA
		rcall RA,{value}
		ld RA,[SP]
		add SP,1
	}
    enableOutput {rd:registers} => asm{
        out OutputEnable,{rd}}

    putoutput {rd:registers} => asm{
        out OutputReg,{rd}
    }
    readRandomRange {rd:registers},{min:i16},{max:i16},{rDummy1:registers},{rDummy2:registers} => asm{
        ldi rDummy1,{min}
        ldi rDummy2,{max}
        sub rDummy2,rDummy1
        in rd,RandomAdr
        and rd,rDummy2
        add rd,rDummy1
    }
    RandomSeed {value : i16} => asm{
        ldi r12 ,{value}
        out RandomSeedAddr,r12
    }
  
    enableInterrupt => asm{
        ldi r12,1
        out CpuinterruptEnable,r12
    }
    disableInterrupt => asm{
        ldi r12,0
        out CpuinterruptEnable,r12
    }
    configureTimer {timer:timers}, {reload:u1},{prescaler:u3},{enable:u1} =>{
        tempval= (reload<<4) | (prescaler<<1) | enable
        tempval2=timerConfig+( timer *3)
        
        lv=tempval[15:15]
        ((0x8000 | tempval)`16 @0x09 @12`4 @lv`4)@ 0x3f @tempval2`4 @12`4

        ;ldi r12,tempval
        ;out (tempval2),r12
    }
   setTimerTarget {timer:timers} ,{value:i16} => {
        tempval=timerTarget+( timer *3)
        
        lv=value[15:15]
        
        ((0x8000 | value)`16 @0x09 @12`4 @lv`4 ) @ 0x3f @tempval`4 @12`4
        ;ldi r12,value
        ;out tempval,r12

    }
    resetTimer {timer:timers} => {
        
        tempval=timerReset+( timer *3)
        (0x0a @12`4 @1`4)@ 0x3f @tempval`4 @12`4
        ; ldi r12,1
        ;out (tempval),r12

    }
 

                                        
} 



