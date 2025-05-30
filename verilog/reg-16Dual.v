module Register16 (
    input [15:0] D,
    input C,
    input en,
    input rst,
    input [1:0] half,
    output reg [15:0] Q  // Make Q a reg so it updates in always block
);

  reg [15:0] realstate = 16'h0;

  always @ (posedge C)
  begin
    if (rst) begin
      realstate <= 16'h0;
    end 
    else if (en) begin
      case (half)
        2'b00: realstate <= D;  // Write full 16-bit
        2'b01: realstate <= {realstate[15:8], D[7:0]}; // Write lower 8 bits only
        2'b10: realstate <= {D[7:0], realstate[7:0]}; // Write upper 8 bits only
        2'b11: realstate <= {D[15:8], realstate[7:0]}; // Write upper 8 bits only
      endcase
    end
  end

  always @(*) begin
    case (half)
      2'b00: Q = realstate; // Read full 16-bit
      2'b01: Q = {8'b00000000, realstate[7:0]}; // Read lower 8 bits
      2'b10: Q = {8'b00000000, realstate[15:8]}; // Read upper 8 bits
      default: Q = realstate; // Default case (full register)
    endcase
  end

endmodule
