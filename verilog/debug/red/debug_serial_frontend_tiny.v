

module debug_serial_frontend_tiny
(
    input  wire        cpu_clk,
    input  wire        rst_n,

    input  wire        dbg_clk,
    input  wire        dbg_data_in,
    output reg         dbg_data_out,
    output reg         dbg_data_oe,

    output wire        reg_wr,
    output wire [3:0]  reg_addr,
    output wire [15:0] reg_wdata,
    input  wire [15:0] reg_rdata
);

    localparam S_RX        = 3'd0;
    localparam S_EXEC      = 3'd1;
    localparam S_LOAD_TX   = 3'd2;
    localparam S_TURNAROUND= 3'd3;
    localparam S_TX        = 3'd4;

    localparam CMD_PING  = 4'h0;
    localparam CMD_READ  = 4'h1;
    localparam CMD_WRITE = 4'h2;

    reg [2:0]  state;

    reg [2:0]  dbg_clk_sync;
    reg [1:0]  dbg_data_sync;

    wire dbg_clk_rise;
    wire dbg_clk_fall;

    assign dbg_clk_rise = (dbg_clk_sync[2:1] == 2'b01);
    assign dbg_clk_fall = (dbg_clk_sync[2:1] == 2'b10);

    reg [23:0] rx_shift;
    reg [4:0]  rx_count;

    reg [15:0] tx_shift;
    reg [4:0]  tx_count;

    wire [3:0] cmd_decoded;

    assign cmd_decoded = rx_shift[23:20];
    assign reg_addr    = rx_shift[19:16];
    assign reg_wdata   = rx_shift[15:0];
    assign reg_wr      = (state == S_EXEC) && (cmd_decoded == CMD_WRITE);

    always @(posedge cpu_clk or negedge rst_n) begin
        if (!rst_n) begin
            state        <= S_RX;
            dbg_clk_sync <= 3'b000;
            dbg_data_sync<= 2'b11;
            dbg_data_out <= 1'b1;
            dbg_data_oe  <= 1'b0;
            rx_shift     <= 24'h000000;
            rx_count     <= 5'd0;
            tx_shift     <= 16'h0000;
            tx_count     <= 5'd0;
        end else begin
            dbg_clk_sync  <= {dbg_clk_sync[1:0], dbg_clk};
            dbg_data_sync <= {dbg_data_sync[0], dbg_data_in};

            case (state)
                S_RX: begin
                    dbg_data_oe  <= 1'b0;
                    dbg_data_out <= 1'b1;
                    if (dbg_clk_rise) begin
                        if (rx_count == 5'd23) begin
                            rx_shift <= {rx_shift[22:0], dbg_data_sync[1]};
                            rx_count <= 5'd0;
                            state    <= S_EXEC;
                        end else begin
                            rx_shift <= {rx_shift[22:0], dbg_data_sync[1]};
                            rx_count <= rx_count + 5'd1;
                        end
                    end
                end

                S_EXEC: begin
                    state <= S_LOAD_TX;
                end

                S_LOAD_TX: begin
                    if (cmd_decoded == CMD_PING)
                        tx_shift <= 16'hDB12;
                    else if (cmd_decoded == CMD_READ)
                        tx_shift <= reg_rdata;
                    else if (cmd_decoded == CMD_WRITE)
                        tx_shift <= 16'hACCE;
                    else
                        tx_shift <= 16'hEEEE;

                    tx_count     <= 5'd0;
                    dbg_data_oe  <= 1'b0;
                    dbg_data_out <= 1'b1;
                    state        <= S_TURNAROUND;
                end

                S_TURNAROUND: begin
                    dbg_data_oe <= 1'b0;
                    if (dbg_clk_fall) begin
                        dbg_data_oe  <= 1'b1;
                        dbg_data_out <= tx_shift[15];
                        state        <= S_TX;
                    end
                end

                S_TX: begin
                    if (dbg_clk_fall) begin
                        if (tx_count == 5'd15) begin
                            dbg_data_oe  <= 1'b0;
                            dbg_data_out <= 1'b1;
                            state        <= S_RX;
                        end else begin
                            tx_shift     <= {tx_shift[14:0], 1'b0};
                            dbg_data_out <= tx_shift[14];
                            tx_count     <= tx_count + 5'd1;
                        end
                    end
                end

                default: begin
                    state        <= S_RX;
                    dbg_data_oe  <= 1'b0;
                    dbg_data_out <= 1'b1;
                end
            endcase
        end
    end

endmodule


