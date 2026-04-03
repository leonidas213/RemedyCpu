module lfsr_RandomNumberGen (
    input  [15:0] adrrIn,
    input  [15:0] dataIn,
    input         ioW,
    input         clk,
    input         ioR,
    input  [15:0] SeedAdr,
    input  [15:0] RngAdr,
    output [15:0] Out
);

    reg [7:0] seed_reg = 8'h01;
    reg [7:0] lfsr     = 8'h01;

    wire seed_wr  = ioW && (adrrIn == SeedAdr);
    wire seed_rd  = ioR && (adrrIn == SeedAdr);
    wire rng_rd   = ioR && (adrrIn == RngAdr);

    // 8-bit maximal-length taps
    // polynomial: x^8 + x^6 + x^5 + x^4 + 1
    wire feedback = lfsr[7] ^ lfsr[5] ^ lfsr[4] ^ lfsr[3];

    always @(posedge clk) begin
        if (seed_wr) begin
            seed_reg <= dataIn[7:0];
            lfsr <= (dataIn[7:0] == 8'h00) ? 8'h01 : dataIn[7:0];
        end else begin
            lfsr <= {lfsr[6:0], feedback};
        end
    end

    assign Out = seed_rd ? {8'h00, seed_reg} :
                 rng_rd  ? {8'h00, lfsr}     :
                           16'h0000;

endmodule