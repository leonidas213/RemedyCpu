module tx_fsm (
    input clk,
    input rst,
    input fifo_empty,
    input tx_busy,
    output reg rd_en,
    output reg start_tx
);
    reg [1:0] state = 0;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= 0;
            rd_en <= 0;
            start_tx <= 0;
        end else begin
            case (state)
                0: if (!fifo_empty && !tx_busy) begin
                        rd_en <= 1;
                        state <= 1;
                    end
                1: begin
                    rd_en <= 0;
                    start_tx <= 1;
                    state <= 2;
                end
                2: begin
                    start_tx <= 0;
                    state <= 0;
                end
            endcase
        end
    end
endmodule
