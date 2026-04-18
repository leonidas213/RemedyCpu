module programCounter
  (
    input  wire [15:0] AluIn,
    input  wire        clk,
    input  wire        rst_n,
    input  wire        pc_en,
    input  wire        absJmp,
    input  wire        intr,
    input  wire        reti,
    input  wire        relJmp,
    output wire [15:0] Nextpc,
    output wire [15:0] PC
  );

  localparam [15:0] interuptFuncAdr = 16'h0002;
  reg [15:0] interruptAdress;

  reg [15:0] PCr;
  reg [15:0] Nextpcr;

  assign Nextpc = Nextpcr;
  assign PC     = PCr;

  always @(posedge clk , negedge rst_n)
  begin
    if (!rst_n)
    begin
      PCr     <= 16'h0000;
      Nextpcr <= 16'h0001;
      interruptAdress <= 16'h0000;
    end
    else if (pc_en)
    begin
      if (reti)
      begin
        PCr     <= interruptAdress + 16'd1;
        Nextpcr <= interruptAdress + 16'd2;
      end
      else if (intr)
      begin
        if (relJmp || absJmp)
          interruptAdress <= PCr - 16'd1;
        else
          interruptAdress <= PCr;

        PCr     <= interuptFuncAdr;
        Nextpcr <= interuptFuncAdr + 16'd1;
      end
      else if (relJmp)
      begin
        PCr     <= PCr + AluIn + 16'd1;
        Nextpcr <= Nextpcr + AluIn + 16'd1;
      end
      else if (absJmp)
      begin
        PCr     <= AluIn;
        Nextpcr <= AluIn + 16'd1;
      end
      else
      begin
        PCr     <= PCr + 16'd1;
        Nextpcr <= Nextpcr + 16'd1;
      end
    end
  end

endmodule
