module fpu_div_core_clamped (
    input  wire [15:0] a,
    input  wire [15:0] b,
    output wire [11:0] quotRawMant,
    output wire [4:0]  quotExp,
    output wire        quotSign,
    output wire [11:0] remRawMant,
    output wire [4:0]  remExp,
    output wire        remSign,
    output wire        roundEnable
);

    // ─── UNPACK ───
    wire signA = a[15];
    wire signB = b[15];
    wire [4:0] expA = a[14:10];
    wire [4:0] expB = b[14:10];
    wire [9:0] fracA = a[9:0];
    wire [9:0] fracB = b[9:0];

    wire [11:0] mantA = (expA != 0) ? {1'b1, fracA} : {1'b0, fracA};
    wire [11:0] mantB = (expB != 0) ? {1'b1, fracB} : {1'b0, fracB};

    // ─── DIVIDE ───
    wire [23:0] dividend = {mantA, 12'b0};
    wire [11:0] quotient = (mantB != 0) ? (dividend / mantB) : 12'd0;
    wire [11:0] remainder = (mantB != 0) ? (dividend % mantB) : 12'd0;

    // ─── EXPONENT ───
    wire signed [6:0] expA_s = $signed({2'b00, expA});
    wire signed [6:0] expB_s = $signed({2'b00, expB});
    wire signed [6:0] expRaw = expA_s - expB_s + 7'sd15;

    // ─── CLAMP EXPONENT TO 5 BITS ───
    wire [4:0] expClamped = (expRaw < 0)   ? 5'd0 :
                            (expRaw > 31)  ? 5'd31 :
                            expRaw[4:0];

    // ─── OUTPUTS ───
    assign quotRawMant = quotient;
    assign quotExp     = expClamped;
    assign quotSign    = signA ^ signB;

    assign remRawMant  = remainder;
    assign remExp      = expClamped;
    assign remSign     = signA;

    assign roundEnable = |remainder;

endmodule
