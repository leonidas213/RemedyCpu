module programCounter
  (
    input  wire [15:0] AluIn,
    input  wire        clk,
    input  wire        rst_n,
    input  wire        pc_en,
    input  wire        absJmp,
    input  wire        intr,
    input  wire        reti,
    input  wire [15:0] deb_jump_addr,
    input  wire        deb_jump,
    input  wire        relJmp,
    output wire [15:0] PC
  );

  localparam [15:0] interuptFuncAdr = 16'h0002;
  reg [15:0] interruptAdress;

  reg [15:0] PCr;
  assign PC     = PCr;

  always @(posedge clk , negedge rst_n)
  begin
    if (!rst_n)
    begin
      PCr     <= 16'h0000;
      interruptAdress <= 16'h0000;
    end
    else if (pc_en)
    begin
      if (reti)
      begin
        PCr     <= interruptAdress + 16'd1;
      end
      else if (intr)
      begin
        if (relJmp || absJmp)
          interruptAdress <= PCr - 16'd1;
        else
          interruptAdress <= PCr;

        PCr     <= interuptFuncAdr;
      end
      else if (relJmp)
      begin
        PCr     <= PCr + AluIn + 16'd1;
      end
      else if (absJmp)
      begin
        PCr     <= AluIn;
      end
      else
      begin
        PCr     <= PCr + 16'd1;
      end
    end
    else if(deb_jump)
    begin
      PCr <= deb_jump_addr;
    end
  end

endmodule
