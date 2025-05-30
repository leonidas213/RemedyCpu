module Register1
  (
    input D,
    input C,
    input en,
    input rst,
    output Q
  );

  reg  state = 'h0;

  assign Q = state;

  always @ (negedge C)
  begin

    if(rst)
    begin
      state <= 1'h0;
    end
    if (en)
      state <= D;

  end
endmodule
