module fpu_div_fixed (
    input  wire [15:0] a,
    input  wire [15:0] b,
    output wire [15:0] result
);
    // ───── Unpack A ─────
    wire signA = a[15];
    wire [4:0] expA = a[14:10];
    wire [9:0] fracA = a[9:0];
    wire [11:0] mantA = (expA != 0) ? {1'b1, fracA} : {1'b0, fracA};

    // ───── Unpack B ─────
    wire signB = b[15];
    wire [4:0] expB = b[14:10];
    wire [9:0] fracB = b[9:0];
    wire [11:0] mantB = (expB != 0) ? {1'b1, fracB} : {1'b0, fracB};

    // ───── Handle corner cases ─────
    wire b_is_zero = (expB == 0) && (fracB == 0);
    wire a_is_zero = (expA == 0) && (fracA == 0);

    // ───── Fixed-point division ─────
    wire [23:0] dividend = {mantA, 12'b0};         // shift A by 12
    wire [11:0] quotient = (mantB != 0) ? (dividend / mantB) : 12'd0;

    // ───── Exponent math ─────
    wire signed [6:0] expA_s = $signed({2'b00, expA});
    wire signed [6:0] expB_s = $signed({2'b00, expB});
    wire signed [6:0] expUnbiased = expA_s - expB_s + 7'sd15;

    // 🧠 No shift because quotient is already normalized
    wire signed [6:0] expNorm = expUnbiased;

    // Clamp exponent
    wire [4:0] expFinal = (expNorm <= 0)   ? 5'd0 :
                          (expNorm > 31)   ? 5'd31 :
                          expNorm[4:0];

    // Drop implicit 1
    wire [9:0] fracFinal = quotient[10:1]; // MSB is implied 1

    // Final float pack
    wire [15:0] resultCore = {signA ^ signB, expFinal, fracFinal};

    // Output
    assign result =
        b_is_zero ? 16'h7C00 :    // +inf
        a_is_zero ? 16'h0000 :    // zero
        resultCore;

endmodule
