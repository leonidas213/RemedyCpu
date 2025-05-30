module RegisterBlock
  (
    input [15:0] Din,
    input we,
    input [3:0] Rw,
    input C,
    input [3:0] Ra,
    input [3:0] Rb,
    output [15:0] Da,
    output [15:0] Db,
    input res

  );

  reg [15:0] memory[0:15];
  integer i = 0 ;
  assign Da = memory[Ra];
  assign Db = memory[Rb];

  always @ (negedge C)
  begin
    if (we)
      memory[Rw] <= Din;
    if (res)
    begin
      for ( i = 0; i < 16; i++)
      begin

        memory[i] <= 0;
      end
    end

  end
endmodule
