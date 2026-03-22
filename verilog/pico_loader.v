module pico_loader(
    input  wire       clk,
    input  wire       rst,

    input  wire [7:0] rx_byte,
    input  wire       rx_valid,

    output reg  [7:0] tx_byte,
    output reg        tx_valid,

    output reg        ram_we,
    output reg [15:0] ram_addr,
    output reg [15:0] ram_din,
    input  wire [15:0] ram_dout,

    output reg        cpu_halt,
    output reg        cpu_reset
);

    reg [3:0] state;
    reg [7:0] cmd;
    reg [15:0] temp_addr;
    reg [15:0] temp_data;

    localparam S_IDLE      = 4'd0;
    localparam S_ADDR_H    = 4'd1;
    localparam S_ADDR_L    = 4'd2;
    localparam S_DATA_H    = 4'd3;
    localparam S_DATA_L    = 4'd4;
    localparam S_READ_H    = 4'd5;
    localparam S_READ_L    = 4'd6;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state     <= S_IDLE;
            cmd       <= 8'h00;
            temp_addr <= 16'h0000;
            temp_data <= 16'h0000;
            ram_we    <= 1'b0;
            ram_addr  <= 16'h0000;
            ram_din   <= 16'h0000;
            tx_byte   <= 8'h00;
            tx_valid  <= 1'b0;
            cpu_halt  <= 1'b1;
            cpu_reset <= 1'b1;
        end else begin
            ram_we   <= 1'b0;
            tx_valid <= 1'b0;

            if (rx_valid) begin
                case (state)
                    S_IDLE: begin
                        cmd <= rx_byte;
                        case (rx_byte)
                            8'h01: state <= S_ADDR_H; // WRITE_WORD
                            8'h02: state <= S_ADDR_H; // READ_WORD
                            8'h03: begin              // HALT
                                cpu_halt <= 1'b1;
                                state <= S_IDLE;
                            end
                            8'h04: begin              // RUN
                                ram_we    <= 1'b0;
                                cpu_reset <= 1'b0;
                                cpu_halt  <= 1'b0;
                                state <= S_IDLE;
                            end
                            8'h05: begin              // RESET
                                ram_we    <= 1'b0;
                                cpu_reset <= 1'b1;
                                cpu_halt  <= 1'b1;
                                state <= S_IDLE;
                            end
                            default: state <= S_IDLE;
                        endcase
                    end

                    S_ADDR_H: begin
                        temp_addr[15:8] <= rx_byte;
                        state <= S_ADDR_L;
                    end

                    S_ADDR_L: begin
                        temp_addr[7:0] <= rx_byte;
                        if (cmd == 8'h01)
                            state <= S_DATA_H;
                        else if (cmd == 8'h02) begin
                            ram_addr <= {temp_addr[15:8], rx_byte};
                            state <= S_READ_H;
                        end else
                            state <= S_IDLE;
                    end

                    S_DATA_H: begin
                        temp_data[15:8] <= rx_byte;
                        state <= S_DATA_L;
                    end

                    S_DATA_L: begin
                        temp_data[7:0] <= rx_byte;
                        ram_addr <= temp_addr;
                        ram_din  <= {temp_data[15:8], rx_byte};
                        ram_we   <= 1'b1;
                        state    <= S_IDLE;
                    end

                    S_READ_H: begin
                        tx_byte  <= ram_dout[15:8];
                        tx_valid <= 1'b1;
                        state    <= S_READ_L;
                    end

                    S_READ_L: begin
                        tx_byte  <= ram_dout[7:0];
                        tx_valid <= 1'b1;
                        state    <= S_IDLE;
                    end

                    default: state <= S_IDLE;
                endcase
            end
        end
    end

endmodule