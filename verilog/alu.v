module Alu (
    input [15:0] A,
    input [15:0] B,
    input carryIn,
    input [5:0] AluOp,
    output [15:0] Out,
    output Neg,
    output Zero,
    output CarryOut
  );
  wire use_carry;
  wire [3:0] sel;
  reg  [15:0] out_r;
  reg         carry_r;
  reg  [16:0] math_ext;

  assign use_carry = AluOp[5] & carryIn;
  assign sel = AluOp[3:0];

  always @(*)
  begin
    out_r   = 16'h0000;
    carry_r = 1'b0;
    math_ext = 17'h00000;

    case (sel)
      4'h0:
      begin
        out_r = B;
      end

      4'h1:
      begin
        math_ext = {1'b0, A} + {1'b0, B} + {{16{1'b0}}, use_carry};
        out_r    = math_ext[15:0];
        carry_r  = math_ext[16];
      end

      4'h2:
      begin
        math_ext = {1'b0, A} - {1'b0, B} - {{16{1'b0}}, use_carry};
        out_r    = math_ext[15:0];
        carry_r  = math_ext[16];
      end

      4'h3:
      begin
        out_r = A & B;
      end

      4'h4:
      begin
        out_r = A | B;
      end

      4'h5:
      begin
        out_r = A ^ B;
      end

      4'h6:
      begin
        out_r = ~A;
      end

      4'h7:
      begin
        math_ext = {1'b0, 16'h0000} - {1'b0, A};
        out_r    = math_ext[15:0];
      end

      4'h8:
      begin
        out_r   = {A[14:0], use_carry};
        carry_r = A[15];
      end

      4'h9:
      begin
        out_r   = {use_carry, A[15:1]};
        carry_r = A[0];
      end

      4'hA:
      begin
        out_r   = {A[15], A[15], A[14:1]};
        carry_r = A[0];
      end

      4'hB:
      begin
        out_r = {A[7:0], A[15:8]};
      end

      4'hC:
      begin
        out_r = {A[11:8], A[15:12], A[3:0], A[7:4]};
      end

      4'hD:
      begin
        out_r = A;
      end

      default:
      begin
        out_r   = 16'h0000;
        carry_r = 1'b0;
      end
    endcase
  end

  assign Out      = out_r;
  assign CarryOut = carry_r;
  assign Neg      = out_r[15];
  assign Zero     = ~|out_r;
endmodule
