module Register8
  (
    input [7:0]D,
    input C,
    input en,
    input rst,
    output [7:0]Q
  );

  reg [7:0] state = 'h0;

  assign Q = state;

  always @ (posedge C)
  begin
    if(rst)
    begin
      state <= 8'h0;
    end
    if (en)
      state <= D;


  end
endmodule
