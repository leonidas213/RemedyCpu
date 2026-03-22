module fpu_operator (
    input  wire [10:0] mantA,
    input  wire [10:0] mantB,
    input  wire        signA,
    input  wire        signB,
    output reg  [11:0] mantOut,
    output reg         signOut
);
    wire [11:0] extA = {1'b0, mantA};
    wire [11:0] extB = {1'b0, mantB};

    wire aBigger = (mantA >= mantB);

    always @* begin
        if (signA == signB) begin
            // Same sign: perform addition
            mantOut  = extA + extB;
            signOut  = signA;
        end else begin
            // Different signs: perform subtraction
            if (aBigger) begin
                mantOut = extA - extB;
                signOut = signA;
            end else begin
                mantOut = extB - extA;
                signOut = signB;
            end
        end
    end
endmodule
