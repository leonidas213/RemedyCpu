module float16_to_int (
    input  wire [15:0] in,
    output reg  [15:0] out
);
    wire sign         = in[15];
    wire [4:0] exp    = in[14:10];
    wire [9:0] frac   = in[9:0];
    wire [11:0] mant  = {1'b1, frac};  // implicit 1

    reg [27:0] shifted;
    reg [15:0] result;

    always @* begin
        if (exp == 0) begin
            result = 16'd0;
        end else begin
            if (exp >= 15) begin
                shifted = mant << (exp - 15);
            end else begin
                shifted = mant >> (15 - exp);
            end

            result = sign ? (~shifted[15:0] + 1) : shifted[15:0];
        end

        // Clamp to int16 range
        if (exp >= 31)
            out = sign ? 16'h8000 : 16'h7FFF;
        else
            out = result;
    end
endmodule
