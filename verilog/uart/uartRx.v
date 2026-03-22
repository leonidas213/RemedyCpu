module uart_rx (
    input wire clk,
    input wire rst,
    input wire rx,
    input wire baud_tick,
    output reg [7:0] data_out,
    output reg data_ready,
    output reg framing_error,    // STOP bit error
    input wire data_read
);

    reg [3:0] bit_index = 0;
    reg [7:0] shift_reg = 0;
    reg [1:0] state = 0;

    parameter IDLE = 2'd0, START = 2'd1, DATA = 2'd2, STOP = 2'd3;

    reg [2:0] rx_history = 3'b111;
    wire rx_filtered;

    assign rx_filtered = (rx_history == 3'b000) ? 1'b0 :
                         (rx_history == 3'b111) ? 1'b1 :
                         rx_sync;

    reg rx_sync = 1;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            rx_history <= 3'b111;
            rx_sync <= 1;
            state <= IDLE;
            bit_index <= 0;
            data_ready <= 0;
            framing_error <= 0;
        end else begin
            rx_history <= {rx_history[1:0], rx};
            rx_sync <= rx_filtered;

            case (state)
                IDLE: begin
                    data_ready <= 0;
                    framing_error <= 0;
                    if (rx_sync == 0)
                        state <= START;
                end

                START: begin
                    if (baud_tick) begin
                        if (rx_sync == 0)
                            state <= DATA;
                        else
                            state <= IDLE;  // False start
                    end
                end

                DATA: begin
                    if (baud_tick) begin
                        shift_reg <= {rx_sync, shift_reg[7:1]};
                        bit_index <= bit_index + 1;
                        if (bit_index == 7)
                            state <= STOP;
                    end
                end

                STOP: begin
                    if (baud_tick) begin
                        data_out <= shift_reg;
                        data_ready <= 1;
                        if (rx_sync != 1)
                            framing_error <= 1;  // Stop bit error
                        state <= IDLE;
                        bit_index <= 0;
                    end
                end
            endcase

            if (data_read)
                data_ready <= 0;
        end
    end
endmodule
