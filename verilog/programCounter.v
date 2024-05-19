
module programCounter
  (
    input [15:0] AluIn,
    input clk,
    input rst,
    input absJmp,
    input intr,
    input reti,
    input relJmp,
    output [15:0] Nextpc,
    output [15:0] PC
  );
  reg[15:0] interuptFuncAdr = 16'h2;
  reg[15:0] interruptAdress = 16'b0000000000000000;

  reg[15:0] PCr = 16'b0000000000000000;
  reg [15:0] Nextpcr = 16'b0000000000000001;
  reg isStarted = 1'b0;
  assign Nextpc = Nextpcr;
  assign PC = PCr;




  always @( posedge clk)
  begin
    
      if(!isStarted)
      begin
        PCr <= 16'b0000000000000000;
        Nextpcr<=  16'b0000000000000001;
        isStarted <= 1'b1;
      end
      else
        if(rst)
        begin
          PCr <= 16'b0000000000000000;
          Nextpcr<=  16'b0000000000000001;
        end
        else
        begin
          if(absJmp)
          begin
            PCr <=AluIn;
            Nextpcr<=AluIn+1;
          end
          else if(relJmp)
          begin
            PCr <= PCr + AluIn+1;
            Nextpcr <=Nextpcr+AluIn+1;
          end
          else if(intr)
          begin
            interruptAdress <=PCr;
            PCr <= interuptFuncAdr;
            Nextpcr <=interuptFuncAdr+1;
          end
          else if(reti)
          begin
            PCr <= interruptAdress+1;
            Nextpcr <=interruptAdress+2;
          end

          else
          begin
            PCr <= PCr + 1;
            Nextpcr <= Nextpcr + 1;
          end
        end

  end




endmodule
