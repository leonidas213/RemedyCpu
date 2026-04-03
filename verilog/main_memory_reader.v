module memory_wait_controller
  (
    input  wire        clk,
    input  wire        rst,

    // CPU side
    input  wire        ld_req,
    input  wire        st_req,
    input  wire [15:0] fetch_addr,
    input  wire [15:0] data_addr,
    input  wire [15:0] store_data,

    output reg  [15:0] mem_rdata,
    output reg         fetch_done,
    output reg         data_done,

    // SPI engine side
    output reg         spi_st,
    output reg         spi_ld,
    output reg  [15:0] spi_addr,
    output reg  [15:0] spi_data_in,
    output reg         spi_target,   // 0 = flash, 1 = ram

    input  wire [15:0] spi_data_out,
    input  wire        spi_busy,

    // cpu cycler
    output reg execute_now,
    output wire pc_en
  );

  localparam OP_NONE  = 2'd0;
  localparam OP_FETCH = 2'd1;
  localparam OP_LOAD  = 2'd2;
  localparam OP_STORE = 2'd3;

  localparam S_IDLE           = 3'd0;
  localparam S_START          = 3'd1;
  localparam S_WAIT_BUSY_HIGH = 3'd2;
  localparam S_WAIT_BUSY_LOW  = 3'd3;
  localparam S_FINISH         = 3'd4;
  reg mem_stall;
  reg [2:0] state_memory = S_IDLE;
  reg [1:0] op    = OP_NONE;

  always @(posedge clk)
  begin
    if (rst)
    begin
      state_memory       <= S_IDLE;
      op          <= OP_NONE;

      mem_rdata   <= 16'h0000;
      fetch_done  <= 1'b0;
      data_done   <= 1'b0;
      mem_stall   <= 1'b0;

      spi_st      <= 1'b0;
      spi_ld      <= 1'b0;
      spi_addr    <= 16'h0000;
      spi_data_in <= 16'h0000;
      spi_target  <= 1'b0;
    end
    else
    begin
      fetch_done <= 1'b0;
      data_done  <= 1'b0;
      spi_st     <= 1'b0;
      spi_ld     <= 1'b0;

      case (state_memory)
        S_IDLE:
        begin
          mem_stall <= 1'b0;
          op        <= OP_NONE;

          if (st_req && execute_now)
          begin
            op          <= OP_STORE;
            spi_target  <= 1'b1;      // RAM
            spi_addr    <= data_addr;
            spi_data_in <= store_data;
            mem_stall   <= 1'b1;
            state_memory       <= S_START;
          end
          else if (ld_req && execute_now)
          begin
            op          <= OP_LOAD;
            spi_target  <= 1'b1;      // RAM
            spi_addr    <= data_addr;
            spi_data_in <= 16'h0000;
            mem_stall   <= 1'b1;
            state_memory       <= S_START;
          end
          else if (fetch_req)
          begin
            op          <= OP_FETCH;
            spi_target  <= 1'b0;      // FLASH
            spi_addr    <= fetch_addr;
            spi_data_in <= 16'h0000;
            mem_stall   <= 1'b1;
            state_memory       <= S_START;
          end
        end

        S_START:
        begin
          if (op == OP_STORE)
            spi_st <= 1'b1;
          else if (op == OP_LOAD || op == OP_FETCH)
            spi_ld <= 1'b1;

          state_memory <= S_WAIT_BUSY_HIGH;
        end

        S_WAIT_BUSY_HIGH:
        begin
          if (spi_busy)
            state_memory <= S_WAIT_BUSY_LOW;
        end

        S_WAIT_BUSY_LOW:
        begin
          if (!spi_busy)
          begin
            if (op == OP_LOAD || op == OP_FETCH)
              mem_rdata <= spi_data_out;

            state_memory <= S_FINISH;
          end
        end

        S_FINISH:
        begin
          mem_stall <= 1'b0;

          if (op == OP_FETCH)
            fetch_done <= 1'b1;
          else
            data_done <= 1'b1;

          state_memory <= S_IDLE;
        end

        default:
        begin
          state_memory <= S_IDLE;
        end
      endcase
    end
  end

  // cpu cycler
  localparam S_REQ_FETCH  = 2'd0;
  localparam S_WAIT_FETCH = 2'd1;
  localparam S_EXECUTE    = 2'd2;
  localparam S_WAIT_DATA  = 2'd3;

  reg [1:0] state_cycler = S_REQ_FETCH;
  reg fetch_req = 0;
  assign pc_en = (!mem_stall && execute_now);
  assign fetch_req_deb = fetch_req;
  always @(posedge clk )
  begin
    if (rst)
    begin
      fetch_req <= 1;
      state_cycler <= S_REQ_FETCH;
    end
    else
    begin
      case (state_cycler)
        S_REQ_FETCH:
        begin
          fetch_req <= 0;
          execute_now <= 0;
          state_cycler <= S_WAIT_FETCH;
        end
        S_WAIT_FETCH:
        begin
          if (fetch_done)
          begin
            state_cycler <= S_EXECUTE;
            fetch_req <= 0;
            execute_now <= 1;
          end
        end

        S_EXECUTE:
        begin
          if (ld_req || st_req)
          begin
            state_cycler <= S_WAIT_DATA;
            execute_now <= 0;
            fetch_req <= 0;
          end
          else
          begin
            state_cycler <= S_REQ_FETCH;
            execute_now <= 0;
            fetch_req <= 1;
          end

          execute_now <= 0;
        end

        S_WAIT_DATA:
        begin
          if (data_done)
          begin
            state_cycler <= S_REQ_FETCH;
            fetch_req <= 1;
            execute_now <= 0;
          end
        end

        default:
        begin
          state_cycler <= S_REQ_FETCH;
          fetch_req <= 1;
        end
      endcase
    end
  end

endmodule
