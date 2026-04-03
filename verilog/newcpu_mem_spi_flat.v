module cpu_mem_spi_flat
(
    input  wire        clk,
    input  wire        rst,

    // CPU side
    input  wire        ld,
    input  wire        st,
    input  wire [15:0] programAddr,
    input  wire [15:0] AddrOut,
    input  wire [15:0] DataOut,

    // Memory result back to CPU
    output reg  [15:0] mem_rdata,

    // Optional debug / existing control signals
    output wire        fetch_req,
    output wire        execute_now,
    output wire        wait_data,
    output wire        execute_pulse,
    output reg         fetch_done,
    output reg         data_done,
    output reg         mem_stall,
    output wire        pc_en,

    // Raw SPI pins
    input  wire        spi_miso,
    output reg         spi_clk,
    output reg         spi_mosi,
    output wire        spics_flash,
    output wire        spics_ram,
    output reg         busy
);

    localparam [15:0] FETCH_STRIDE = 16'h0001;

    localparam [1:0] C_REQ_FETCH  = 2'd0;
    localparam [1:0] C_WAIT_FETCH = 2'd1;
    localparam [1:0] C_EXECUTE    = 2'd2;
    localparam [1:0] C_WAIT_DATA  = 2'd3;

    localparam [1:0] OP_NONE  = 2'd0;
    localparam [1:0] OP_FETCH = 2'd1;
    localparam [1:0] OP_LOAD  = 2'd2;
    localparam [1:0] OP_STORE = 2'd3;

    localparam [3:0] M_IDLE        = 4'd0;
    localparam [3:0] M_ASSERT_CS   = 4'd1;
    localparam [3:0] M_SEND_CMD    = 4'd2;
    localparam [3:0] M_SEND_ADDR_H = 4'd3;
    localparam [3:0] M_SEND_ADDR_L = 4'd4;
    localparam [3:0] M_WRITE_H     = 4'd5;
    localparam [3:0] M_WRITE_L     = 4'd6;
    localparam [3:0] M_READ_H      = 4'd7;
    localparam [3:0] M_READ_L      = 4'd8;
    localparam [3:0] M_CLK_HIGH    = 4'd9;
    localparam [3:0] M_FINISH      = 4'd10;
    localparam [3:0] M_RELEASE_CS  = 4'd11;

    reg [1:0] cycle_state;
    reg       execute_now_d;

    reg [3:0] mem_state;
    reg [3:0] return_state;
    reg       sample_miso;

    reg [1:0] op;
    reg       spi_target;      // 0 = flash, 1 = ram
    reg       core_cs_n;       // active-low internal CS

    reg [15:0] req_addr;
    reg [15:0] req_wdata;
    reg [15:0] recv_data;
    reg [7:0]  shift_reg;
    reg [3:0]  bit_cnt;

    reg        flash_stream_open;
    reg [15:0] flash_stream_addr;

    wire ld_req;
    wire st_req;
    wire can_continue_fetch;

    assign fetch_req     = (cycle_state == C_REQ_FETCH);
    assign execute_now   = (cycle_state == C_EXECUTE);
    assign wait_data     = (cycle_state == C_WAIT_DATA);
    assign execute_pulse = execute_now & ~execute_now_d;

    assign ld_req = execute_pulse & ld;
    assign st_req = execute_pulse & st;

    assign can_continue_fetch = flash_stream_open &&
                                (programAddr == (flash_stream_addr + FETCH_STRIDE));

    assign pc_en = execute_pulse & ~mem_stall;

    assign spics_flash = core_cs_n |  spi_target;
    assign spics_ram   = core_cs_n | ~spi_target;

    // CPU cycle controller + embedded pulse_on_rise
    always @(posedge clk or posedge rst)
    begin
        if (rst)
        begin
            cycle_state    <= C_REQ_FETCH;
            execute_now_d  <= 1'b0;
        end
        else
        begin
            execute_now_d <= execute_now;

            case (cycle_state)
                C_REQ_FETCH:
                    cycle_state <= C_WAIT_FETCH;

                C_WAIT_FETCH:
                begin
                    if (fetch_done)
                        cycle_state <= C_EXECUTE;
                end

                C_EXECUTE:
                begin
                    if (ld || st)
                        cycle_state <= C_WAIT_DATA;
                    else
                        cycle_state <= C_REQ_FETCH;
                end

                C_WAIT_DATA:
                begin
                    if (data_done)
                        cycle_state <= C_REQ_FETCH;
                end

                default:
                    cycle_state <= C_REQ_FETCH;
            endcase
        end
    end

    // Memory wait controller + SPI engine + continuous fetch stream
    always @(posedge clk or posedge rst)
    begin
        if (rst)
        begin
            mem_rdata         <= 16'h0000;
            fetch_done        <= 1'b0;
            data_done         <= 1'b0;
            mem_stall         <= 1'b0;

            mem_state         <= M_IDLE;
            return_state      <= M_IDLE;
            sample_miso       <= 1'b0;

            op                <= OP_NONE;
            spi_target        <= 1'b0;
            core_cs_n         <= 1'b1;
            spi_clk           <= 1'b0;
            spi_mosi          <= 1'b0;
            busy              <= 1'b0;

            req_addr          <= 16'h0000;
            req_wdata         <= 16'h0000;
            recv_data         <= 16'h0000;
            shift_reg         <= 8'h00;
            bit_cnt           <= 4'd0;

            flash_stream_open <= 1'b0;
            flash_stream_addr <= 16'h0000;
        end
        else
        begin
            fetch_done <= 1'b0;
            data_done  <= 1'b0;

            case (mem_state)
                M_IDLE:
                begin
                    busy    <= 1'b0;
                    spi_clk <= 1'b0;
                    mem_stall <= 1'b0;

                    if (st_req)
                    begin
                        op        <= OP_STORE;
                        spi_target<= 1'b1;
                        req_addr  <= AddrOut;
                        req_wdata <= DataOut;
                        mem_stall <= 1'b1;
                        busy      <= 1'b1;

                        if (flash_stream_open)
                        begin
                            core_cs_n         <= 1'b1;
                            flash_stream_open <= 1'b0;
                        end

                        mem_state <= M_ASSERT_CS;
                    end
                    else if (ld_req)
                    begin
                        op        <= OP_LOAD;
                        spi_target<= 1'b1;
                        req_addr  <= AddrOut;
                        req_wdata <= 16'h0000;
                        mem_stall <= 1'b1;
                        busy      <= 1'b1;

                        if (flash_stream_open)
                        begin
                            core_cs_n         <= 1'b1;
                            flash_stream_open <= 1'b0;
                        end

                        mem_state <= M_ASSERT_CS;
                    end
                    else if (fetch_req)
                    begin
                        op        <= OP_FETCH;
                        spi_target<= 1'b0;
                        req_addr  <= programAddr;
                        req_wdata <= 16'h0000;
                        mem_stall <= 1'b1;
                        busy      <= 1'b1;
                        recv_data <= 16'h0000;
                        bit_cnt   <= 4'd0;
                        spi_mosi  <= 1'b0;

                        if (can_continue_fetch)
                        begin
                            // Keep CS low and just clock the next 16 bits.
                            mem_state <= M_READ_H;
                        end
                        else
                        begin
                            if (flash_stream_open)
                            begin
                                core_cs_n         <= 1'b1;
                                flash_stream_open <= 1'b0;
                            end
                            mem_state <= M_ASSERT_CS;
                        end
                    end
                end

                M_ASSERT_CS:
                begin
                    core_cs_n <= 1'b0;
                    spi_clk   <= 1'b0;
                    bit_cnt   <= 4'd0;
                    recv_data <= 16'h0000;

                    if (op == OP_STORE)
                        shift_reg <= 8'h02;
                    else
                        shift_reg <= 8'h03;

                    mem_state <= M_SEND_CMD;
                end

                M_SEND_CMD:
                begin
                    spi_clk <= 1'b0;
                    if (bit_cnt < 8)
                    begin
                        spi_mosi    <= shift_reg[7];
                        shift_reg   <= {shift_reg[6:0], 1'b0};
                        bit_cnt     <= bit_cnt + 1'b1;
                        sample_miso <= 1'b0;
                        return_state<= M_SEND_CMD;
                        mem_state   <= M_CLK_HIGH;
                    end
                    else
                    begin
                        shift_reg <= req_addr[15:8];
                        bit_cnt   <= 4'd0;
                        mem_state <= M_SEND_ADDR_H;
                    end
                end

                M_SEND_ADDR_H:
                begin
                    spi_clk <= 1'b0;
                    if (bit_cnt < 8)
                    begin
                        spi_mosi    <= shift_reg[7];
                        shift_reg   <= {shift_reg[6:0], 1'b0};
                        bit_cnt     <= bit_cnt + 1'b1;
                        sample_miso <= 1'b0;
                        return_state<= M_SEND_ADDR_H;
                        mem_state   <= M_CLK_HIGH;
                    end
                    else
                    begin
                        shift_reg <= req_addr[7:0];
                        bit_cnt   <= 4'd0;
                        mem_state <= M_SEND_ADDR_L;
                    end
                end

                M_SEND_ADDR_L:
                begin
                    spi_clk <= 1'b0;
                    if (bit_cnt < 8)
                    begin
                        spi_mosi    <= shift_reg[7];
                        shift_reg   <= {shift_reg[6:0], 1'b0};
                        bit_cnt     <= bit_cnt + 1'b1;
                        sample_miso <= 1'b0;
                        return_state<= M_SEND_ADDR_L;
                        mem_state   <= M_CLK_HIGH;
                    end
                    else
                    begin
                        bit_cnt  <= 4'd0;
                        recv_data<= 16'h0000;
                        spi_mosi <= 1'b0;

                        if (op == OP_STORE)
                        begin
                            shift_reg <= req_wdata[15:8];
                            mem_state <= M_WRITE_H;
                        end
                        else
                        begin
                            mem_state <= M_READ_H;
                        end
                    end
                end

                M_WRITE_H:
                begin
                    spi_clk <= 1'b0;
                    if (bit_cnt < 8)
                    begin
                        spi_mosi    <= shift_reg[7];
                        shift_reg   <= {shift_reg[6:0], 1'b0};
                        bit_cnt     <= bit_cnt + 1'b1;
                        sample_miso <= 1'b0;
                        return_state<= M_WRITE_H;
                        mem_state   <= M_CLK_HIGH;
                    end
                    else
                    begin
                        shift_reg <= req_wdata[7:0];
                        bit_cnt   <= 4'd0;
                        mem_state <= M_WRITE_L;
                    end
                end

                M_WRITE_L:
                begin
                    spi_clk <= 1'b0;
                    if (bit_cnt < 8)
                    begin
                        spi_mosi    <= shift_reg[7];
                        shift_reg   <= {shift_reg[6:0], 1'b0};
                        bit_cnt     <= bit_cnt + 1'b1;
                        sample_miso <= 1'b0;
                        return_state<= M_WRITE_L;
                        mem_state   <= M_CLK_HIGH;
                    end
                    else
                    begin
                        mem_state <= M_FINISH;
                    end
                end

                M_READ_H:
                begin
                    spi_clk <= 1'b0;
                    if (bit_cnt < 8)
                    begin
                        spi_mosi    <= 1'b0;
                        bit_cnt     <= bit_cnt + 1'b1;
                        sample_miso <= 1'b1;
                        return_state<= M_READ_H;
                        mem_state   <= M_CLK_HIGH;
                    end
                    else
                    begin
                        bit_cnt   <= 4'd0;
                        mem_state <= M_READ_L;
                    end
                end

                M_READ_L:
                begin
                    spi_clk <= 1'b0;
                    if (bit_cnt < 8)
                    begin
                        spi_mosi    <= 1'b0;
                        bit_cnt     <= bit_cnt + 1'b1;
                        sample_miso <= 1'b1;
                        return_state<= M_READ_L;
                        mem_state   <= M_CLK_HIGH;
                    end
                    else
                    begin
                        mem_state <= M_FINISH;
                    end
                end

                M_CLK_HIGH:
                begin
                    spi_clk <= 1'b1;
                    if (sample_miso)
                        recv_data <= {recv_data[14:0], spi_miso};
                    mem_state <= return_state;
                end

                M_FINISH:
                begin
                    spi_clk   <= 1'b0;
                    mem_stall <= 1'b0;
                    busy      <= 1'b0;

                    if (op == OP_FETCH || op == OP_LOAD)
                        mem_rdata <= recv_data;

                    if (op == OP_FETCH)
                    begin
                        fetch_done        <= 1'b1;
                        flash_stream_open <= 1'b1;
                        flash_stream_addr <= req_addr;
                        // Keep CS low so a sequential next fetch can continue.
                        mem_state         <= M_IDLE;
                    end
                    else
                    begin
                        data_done         <= 1'b1;
                        flash_stream_open <= 1'b0;
                        mem_state         <= M_RELEASE_CS;
                    end
                end

                M_RELEASE_CS:
                begin
                    core_cs_n <= 1'b1;
                    spi_clk   <= 1'b0;
                    spi_mosi  <= 1'b0;
                    mem_state <= M_IDLE;
                end

                default:
                begin
                    mem_state <= M_IDLE;
                end
            endcase
        end
    end

endmodule
