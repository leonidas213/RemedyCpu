module pico_bus_if(
    input  wire       clk,
    input  wire       rst,

    input  wire [7:0] pico_data_in,
    input  wire       pico_wr,
    input  wire       pico_rd,

    output reg  [7:0] rx_byte,
    output reg        rx_valid,

    input  wire [7:0] tx_byte,
    input  wire       tx_valid,
    output reg  [7:0] pico_data_out
);

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            rx_byte       <= 8'h00;
            rx_valid      <= 1'b0;
            pico_data_out <= 8'h00;
        end else begin
            rx_valid <= 1'b0;

            if (pico_wr) begin
                rx_byte  <= pico_data_in;
                rx_valid <= 1'b1;
            end

            if (pico_rd && tx_valid) begin
                pico_data_out <= tx_byte;
            end
        end
    end

endmodule