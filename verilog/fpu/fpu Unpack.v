module fpu_unpack (
    input  wire [15:0] in,
    output wire        sign,
    output wire [4:0]  exp,
    output wire [10:0] mantissa
);

    assign sign = in[15];
    assign exp  = in[14:10];
    assign mantissa = (exp != 5'b00000) ? {1'b1, in[9:0]} : {1'b0, in[9:0]};

endmodule
