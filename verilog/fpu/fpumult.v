module fpu_mult (
    input  wire [15:0] a,
    input  wire [15:0] b,
    output wire [11:0] manstisa,
    output wire [4:0]  exp,
    output wire        sign
);
    // Step 1: Unpack
    wire signA = a[15];
    wire signB = b[15];
    wire [4:0] expA = a[14:10];
    wire [4:0] expB = b[14:10];
    wire [9:0] fracA = a[9:0];
    wire [9:0] fracB = b[9:0];

    wire isSubnormalA = (expA == 0);
    wire isSubnormalB = (expB == 0);

    wire [11:0] mantA = isSubnormalA ? {1'b0, fracA} : {1'b1, fracA};
    wire [11:0] mantB = isSubnormalB ? {1'b0, fracB} : {1'b1, fracB};

    // Step 2: Multiply
    wire [23:0] mantMult = mantA * mantB;

    // Step 3: Add exponents (remove bias of 15)
    wire [6:0] expSum = expA + expB - 5'd15;

    // Step 4: Output sign
    wire signOut = signA ^ signB;


    assign manstisa = mantMult[22:11]; // Take the top 12 bits of the product
    assign exp = expSum[4:0]; // Take the lower 5 bits of the exponent sum
    assign sign = signOut;
endmodule
