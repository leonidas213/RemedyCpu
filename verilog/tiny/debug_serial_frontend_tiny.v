

module debug_serial_frontend_tiny
(
    input  wire        cpu_clk,
    input  wire        rst_n,

    input  wire        dbg_clk,
    input  wire        dbg_data_in,
    output reg         dbg_data_out,
    output reg         dbg_data_oe,

    output reg         reg_wr,
    output reg  [3:0]  reg_addr,
    output reg  [15:0] reg_wdata,
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

    reg [3:0]  cmd_latched;
    reg [3:0]  addr_latched;
    reg [15:0] data_latched;

    reg [15:0] tx_shift;
    reg [4:0]  tx_count;

    always @(posedge cpu_clk or negedge rst_n) begin
        if (!rst_n) begin
            state        <= S_RX;
            dbg_clk_sync <= 3'b000;
            dbg_data_sync<= 2'b11;
            dbg_data_out <= 1'b1;
            dbg_data_oe  <= 1'b0;
            reg_wr       <= 1'b0;
            reg_addr     <= 4'h0;
            reg_wdata    <= 16'h0000;
            rx_shift     <= 24'h000000;
            rx_count     <= 5'd0;
            cmd_latched  <= 4'h0;
            addr_latched <= 4'h0;
            data_latched <= 16'h0000;
            tx_shift     <= 16'h0000;
            tx_count     <= 5'd0;
        end else begin
            dbg_clk_sync  <= {dbg_clk_sync[1:0], dbg_clk};
            dbg_data_sync <= {dbg_data_sync[0], dbg_data_in};
            reg_wr <= 1'b0;

            case (state)
                S_RX: begin
                    dbg_data_oe <= 1'b0;
                    dbg_data_out <= 1'b1;
                    if (dbg_clk_rise) begin
                        if (rx_count == 5'd23) begin
                            cmd_latched  <= rx_shift[22:19];
                            addr_latched <= rx_shift[18:15];
                            data_latched <= {rx_shift[14:0], dbg_data_sync[1]};
                            rx_count     <= 5'd0;
                            state        <= S_EXEC;
                        end else begin
                            rx_shift <= {rx_shift[22:0], dbg_data_sync[1]};
                            rx_count <= rx_count + 5'd1;
                        end
                    end
                end

                S_EXEC: begin
                    reg_addr  <= addr_latched;
                    reg_wdata <= data_latched;
                    if (cmd_latched == CMD_WRITE)
                        reg_wr <= 1'b1;
                    state <= S_LOAD_TX;
                end

                S_LOAD_TX: begin
                    if (cmd_latched == CMD_PING)
                        tx_shift <= 16'hDB12;
                    else if (cmd_latched == CMD_READ)
                        tx_shift <= reg_rdata;
                    else if (cmd_latched == CMD_WRITE)
                        tx_shift <= 16'hACCE;
                    else
                        tx_shift <= 16'hEEEE;

                    tx_count    <= 5'd0;
                    dbg_data_oe <= 1'b0;
                    dbg_data_out<= 1'b1;
                    state       <= S_TURNAROUND;
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
                    state <= S_RX;
                    dbg_data_oe <= 1'b0;
                    dbg_data_out <= 1'b1;
                end
            endcase
        end
    end

endmodule


