module uart_tx (
    input wire clk,
    input wire rst,
    input wire baud_tick,
    input wire start,            // trigger new transmission
    input wire [7:0] data_in,
    output reg tx,
    output reg busy
);

    reg [3:0] bit_index = 0;
    reg [9:0] shift_reg = 10'b1111111111;

    
    localparam IDLE =2'b00;
    localparam START = 2'b01;
    localparam SEND = 2'b10;
    localparam STOP = 2'b11;

    reg[1:0] state = IDLE;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= IDLE;
            tx <= 1;
            busy <= 0;
        end else begin
            case (state)
                IDLE: begin
                    tx <= 1;
                    busy <= 0;
                    if (start) begin
                        shift_reg <= {1'b1, data_in, 1'b0};  // STOP + DATA + START
                        bit_index <= 0;
                        busy <= 1;
                        state <= SEND;
                    end
                end

                SEND: begin
                    if (baud_tick) begin
                        tx <= shift_reg[bit_index];
                        bit_index <= bit_index + 1;
                        if (bit_index == 9)
                            state <= IDLE;
                    end
                end
            endcase
        end
    end
endmodule
