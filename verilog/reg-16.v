module Register16
  (
    input [15:0]D,
    input C,
    input en,
    input rst,
    output [15:0]Q
  );

  reg [15:0] state = 'h0;

  assign Q = state;

  always @ (posedge C)
  begin
    if(rst)
    begin
      state <= 16'h0;
    end
    if (en)
      state <= D;
  end
endmodule
