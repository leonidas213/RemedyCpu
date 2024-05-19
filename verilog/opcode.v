
module OpCode
  (
    input clk,
    input rst,
    input instructionInput ,
    input [15:0]ProgramCounter,
    output reg [15:0] opcoder,
    output PcClock,
    output PcShifter
  );

  reg[15:0] instructionRegister=15'h0;
  reg[5:0] CounterRegister=5'h0;
  reg pcClockHold=1'h0;
  reg pcwireshifter;
  reg [4:0] shiftIndex=5'h10;

  reg state=1'b0;
  reg clockon= 1'b0;
  assign PcClock =pcClockHold;
  assign PcShifter=pcwireshifter;

  always @( posedge clk)
  begin
    if(pcClockHold ==0)
    begin
      if (rst)
      begin
        pcClockHold<=1;
        instructionRegister<= 15'h0;
        CounterRegister<= 5'h0;
        shiftIndex<= 5'h10;
        opcoder<=15'h0;
        state<=1'b0;
        clockon<=0;
        pcwireshifter<=0;
      end
      else
      begin
        if(clockon)
        begin
          pcClockHold<=1;
          clockon<=0;
        end
        else
        begin
          if(state)
          begin

            pcwireshifter<= 0;
            instructionRegister <= (instructionRegister >> 1) | instructionInput<<15;
            CounterRegister <= CounterRegister + 1;
            if(CounterRegister == 5'h10)
            begin
              opcoder<=instructionRegister;
              CounterRegister<=5'h0;
              clockon<= 1;
              state<=1'b0;
              instructionRegister<=15'h0;
            end
          end
          else
          begin
            pcwireshifter<=  ProgramCounter [shiftIndex-1] ;
            shiftIndex<=shiftIndex-1;
            if(shiftIndex==5'h1)
            begin
              shiftIndex<=5'h10;
              state<=1'b1;
            end
          end

        end
      end

    end
    else
    begin
      opcoder<=15'h0;
      pcClockHold<=0;
    end
  end




endmodule
