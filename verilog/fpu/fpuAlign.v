module fpu_align (
    input  wire [4:0]  expA, expB,
    input  wire [10:0] mantA, mantB,
    output wire [10:0] alignedA, alignedB,
    output wire [4:0]  commonExp
);

    wire [4:0] expDiff;
    wire       aBigger;

    assign aBigger   = (expA >= expB);
    assign expDiff   = aBigger ? (expA - expB) : (expB - expA);
    assign commonExp = aBigger ? expA : expB;

    wire [10:0] mantShiftA = mantA >> expDiff;
    wire [10:0] mantShiftB = mantB >> expDiff;

    assign alignedA = aBigger ? mantA        : mantShiftA;
    assign alignedB = aBigger ? mantShiftB   : mantB;

endmodule
