module sim_pico_loader  (
    input  wire                  clk,
    input  wire                  rst,
    input  wire                  start,

    output reg                   busy,
    output reg                   done,

    // 16-bit source memory / register block
    output reg  [15:0] prog_addr,
    input  wire [15:0]           prog_data,

    // 8-bit bus to DUT
    output reg  [7:0]            pico_data_out,
    output reg                   pico_wr,
    output reg                   pico_rd,
    output reg                   pico_reset_if,

    input  wire [7:0]            pico_data_in,
    input  wire                  pico_ready
);
    localparam ADDR_WIDTH = 16  ;
    localparam WORD_COUNT = 124;
    localparam CMD_WRITE_WORD = 8'h01;
    localparam CMD_HALT       = 8'h03;
    localparam CMD_RUN        = 8'h04;

    localparam S_IDLE         = 4'd0;
    localparam S_RESET_0      = 4'd1;
    localparam S_RESET_1      = 4'd2;
    localparam S_HALT         = 4'd3;
    localparam S_SET_ADDR     = 4'd4;
    localparam S_LATCH_WORD   = 4'd5;
    localparam S_SEND_CMD     = 4'd6;
    localparam S_SEND_AH      = 4'd7;
    localparam S_SEND_AL      = 4'd8;
    localparam S_SEND_DH      = 4'd9;
    localparam S_SEND_DL      = 4'd10;
    localparam S_NEXT         = 4'd11;
    localparam S_RUN          = 4'd12;
    localparam S_DONE         = 4'd13;
    localparam S_WAIT         = 4'd14;

    reg [3:0] state;
    reg [15:0] current_word;
    reg [15:0] word_index;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state         <= S_IDLE;
            busy          <= 1'b0;
            done          <= 1'b0;

            prog_addr     <= {ADDR_WIDTH{1'b0}};
            current_word  <= 16'h0000;
            word_index    <= 16'h0000;

            pico_data_out <= 8'h00;
            pico_wr       <= 1'b0;
            pico_rd       <= 1'b0;
            pico_reset_if <= 1'b0;
        end else begin
            pico_wr <= 1'b0;
            pico_rd <= 1'b0;

            case (state)
                S_IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        busy          <= 1'b1;
                        word_index    <= 16'd0;
                        pico_reset_if <= 1'b1;
                        state         <= S_RESET_0;
                    end
                end

                S_RESET_0: begin
                    state <= S_RESET_1;
                end

                S_RESET_1: begin
                    pico_reset_if <= 1'b0;
                    state         <= S_HALT;
                end

                S_HALT: begin
                    if (pico_ready) begin
                        pico_data_out <= CMD_HALT;
                        pico_wr       <= 1'b1;
                        state         <= S_SET_ADDR;
                    end
                end

                S_SET_ADDR: begin
                    if (word_index < WORD_COUNT) begin
                        prog_addr <= word_index[ADDR_WIDTH-1:0];
                        state     <= S_LATCH_WORD;
                    end else begin
                        state <= S_WAIT;
                    end
                end

                S_LATCH_WORD: begin
                    // if your source is synchronous, add one extra wait state before this
                    current_word <= prog_data;
                    state        <= S_SEND_CMD;
                end

                S_SEND_CMD: begin
                    if (pico_ready) begin
                        pico_data_out <= CMD_WRITE_WORD;
                        pico_wr       <= 1'b1;
                        state         <= S_SEND_AH;
                    end
                end

                S_SEND_AH: begin
                    if (pico_ready) begin
                        pico_data_out <= word_index[15:8];
                        pico_wr       <= 1'b1;
                        state         <= S_SEND_AL;
                    end
                end

                S_SEND_AL: begin
                    if (pico_ready) begin
                        pico_data_out <= word_index[7:0];
                        pico_wr       <= 1'b1;
                        state         <= S_SEND_DH;
                    end
                end

                S_SEND_DH: begin
                    if (pico_ready) begin
                        pico_data_out <= current_word[15:8];
                        pico_wr       <= 1'b1;
                        state         <= S_SEND_DL;
                    end
                end

                S_SEND_DL: begin
                    if (pico_ready) begin
                        pico_data_out <= current_word[7:0];
                        pico_wr       <= 1'b1;
                        state         <= S_NEXT;
                    end
                end

                S_NEXT: begin
                    word_index <= word_index + 16'd1;
                    state      <= S_SET_ADDR;
                end

                S_RUN: begin
                    if (pico_ready) begin
                        pico_data_out <= CMD_RUN;
                        pico_wr       <= 1'b1;
                        state         <= S_DONE;
                    end
                end

                S_DONE: begin
                    busy <= 1'b0;
                    done <= 1'b1;
                end

                S_WAIT: begin
                    if (pico_ready) begin
                        pico_wr <= 1'b0;
                        state <= S_RUN;
                    end
                end

                default: begin
                    state <= S_IDLE;
                end
            endcase
        end
    end

endmodule