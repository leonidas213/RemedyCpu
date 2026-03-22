module fpu_normalize_pack (
    input  wire [11:0] mantIn,
    input  wire [4:0]  expIn,
    input  wire        signIn,
    input  wire        roundEn,       
    output reg  [15:0] result
);
    reg [4:0]  expOut;
    reg [9:0]  fracOut;
    reg [11:0] normMant;
    reg [4:0]  expWork;
    reg [3:0]  shiftCount;
    reg        roundBit;
    reg [10:0] mantWithGuard;

    always @* begin
        normMant = mantIn;
        expWork  = expIn;

        // Normalize
        if (mantIn[11]) begin
            normMant = mantIn >> 1;
            expWork  = expIn + 1;
        end else begin
            shiftCount = 0;
            while (normMant[10] == 1'b0 && expWork > 0 && shiftCount < 11) begin
                normMant = normMant << 1;
                expWork  = expWork - 1;
                shiftCount = shiftCount + 1;
            end
        end

        // Prepare mantissa with rounding only if enabled
        if (roundEn) begin
            mantWithGuard = normMant[10:0];   // 11 bits
            roundBit      = normMant[0];      // use LSB as round bit

            // Round to nearest-even
            if (roundBit && mantWithGuard[0])
                mantWithGuard = mantWithGuard + 1;

            // Overflow from rounding
            if (mantWithGuard[10])
                expWork = expWork + 1;

            fracOut = mantWithGuard[9:0];
        end else begin
            // No rounding, just truncate
            fracOut = normMant[9:0];
        end

        // Clamp exponent if overflow
        if (expWork >= 5'h1F) begin
            expOut  = 5'h1F;
            fracOut = 10'h3FF;
        end else if (expWork == 0) begin
            expOut  = 5'b00000;
            // Still output fraction even for subnormals
        end else begin
            expOut = expWork;
        end

        result = {signIn, expOut, fracOut};
    end
endmodule
