module uart_rx_fsm (
    input wire clk,
    input wire rst,
    input wire data_ready,       // From uart_rx
    input wire fifo_full,        // From rx_fifo
    output reg data_read,        // Goes to uart_rx (1 cycle)
    output reg fifo_wr_en        // Goes to rx_fifo (1 cycle)
);

    reg [1:0] state = 0;

    // State encoding
    localparam IDLE   = 2'd0;
    localparam WRITE  = 2'd1;
    localparam CLEAR  = 2'd2;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= IDLE;
            data_read <= 0;
            fifo_wr_en <= 0;
        end else begin
            data_read <= 0;
            fifo_wr_en <= 0;

            case (state)
                IDLE: begin
                    if (data_ready && !fifo_full) begin
                        fifo_wr_en <= 1;
                        data_read <= 1;
                        state <= CLEAR;
                    end
                end
                CLEAR: begin
                    // One cycle pause before returning to idle
                    state <= IDLE;
                end
            endcase
        end
    end
endmodule
