module int_to_float16 (
    input  wire [15:0] in,
    output reg  [15:0] out
);
    integer i;
    reg signed [15:0] signed_in;
    reg [15:0] abs_in;
    reg [15:0] shifted;
    reg [4:0] exp;
    reg [9:0] frac;

    always @* begin
        signed_in = in;

        if (signed_in == 0) begin
            out = 16'd0;
        end else begin
            abs_in = (signed_in < 0) ? -signed_in : signed_in;

            // Find position of highest set bit
            i = 15;
            while (i >= 0 && abs_in[i] == 0) i = i - 1;

            // Compute biased exponent
            exp = i + 5'd15;

            // Shift left so that MSB is at bit 10
            shifted = abs_in << (10 - i);
            frac = shifted[9:0]; // Get lower 10 bits (rounded down)

            out = {signed_in[15], exp, frac};
        end
    end
endmodule
