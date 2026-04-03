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
    output reg         spi_target,      // 0 = flash, 1 = ram
    output reg         spi_cont,        // 1 = keep flash read stream open
    output reg         spi_stop_cont,   // pulse 1 clk to close flash stream

    input  wire [15:0] spi_data_out,
    input  wire        spi_busy,

    // cpu cycler
    output reg         execute_now,
    output wire        pc_en
  );

  localparam OP_NONE  = 2'd0;
  localparam OP_FETCH = 2'd1;
  localparam OP_LOAD  = 2'd2;
  localparam OP_STORE = 2'd3;

  localparam S_IDLE           = 3'd0;
  localparam S_CLOSE_STREAM   = 3'd1;
  localparam S_WAIT_CLOSE     = 3'd2;
  localparam S_START          = 3'd3;
  localparam S_WAIT_BUSY_HIGH = 3'd4;
  localparam S_WAIT_BUSY_LOW  = 3'd5;
  localparam S_FINISH         = 3'd6;

  reg        mem_stall;
  reg [2:0]  state_memory;
  reg [1:0]  op;
  reg        flash_stream_open;
  reg [15:0] last_fetch_addr;

  wire next_fetch_is_seq;
  assign next_fetch_is_seq = (fetch_addr == (last_fetch_addr + 16'd1));
  assign pc_en = (!mem_stall && execute_now);

  always @(posedge clk)
  begin
    if (rst)
    begin
      state_memory       <= S_IDLE;
      op                 <= OP_NONE;
      mem_stall          <= 1'b0;
      mem_rdata          <= 16'h0000;
      fetch_done         <= 1'b0;
      data_done          <= 1'b0;
      spi_st             <= 1'b0;
      spi_ld             <= 1'b0;
      spi_addr           <= 16'h0000;
      spi_data_in        <= 16'h0000;
      spi_target         <= 1'b0;
      spi_cont           <= 1'b0;
      spi_stop_cont      <= 1'b0;
      flash_stream_open  <= 1'b0;
      last_fetch_addr    <= 16'h0000;
    end
    else
    begin
      fetch_done    <= 1'b0;
      data_done     <= 1'b0;
      spi_st        <= 1'b0;
      spi_ld        <= 1'b0;
      spi_stop_cont <= 1'b0;

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
            spi_cont    <= 1'b0;
            mem_stall   <= 1'b1;

            if (flash_stream_open)
              state_memory <= S_CLOSE_STREAM;
            else
              state_memory <= S_START;
          end
          else if (ld_req && execute_now)
          begin
            op          <= OP_LOAD;
            spi_target  <= 1'b1;      // RAM
            spi_addr    <= data_addr;
            spi_data_in <= 16'h0000;
            spi_cont    <= 1'b0;
            mem_stall   <= 1'b1;

            if (flash_stream_open)
              state_memory <= S_CLOSE_STREAM;
            else
              state_memory <= S_START;
          end
          else if (fetch_req)
          begin
            op          <= OP_FETCH;
            spi_target  <= 1'b0;      // FLASH
            spi_addr    <= fetch_addr;
            spi_data_in <= 16'h0000;
            spi_cont    <= 1'b1;
            mem_stall   <= 1'b1;

            if (flash_stream_open && !next_fetch_is_seq)
              state_memory <= S_CLOSE_STREAM;
            else
              state_memory <= S_START;
          end
        end

        S_CLOSE_STREAM:
        begin
          spi_stop_cont     <= 1'b1;
          spi_cont    <= 1'b0;
          flash_stream_open <= 1'b0;
          state_memory      <= S_WAIT_CLOSE;
        end

        S_WAIT_CLOSE:
        begin
          // give SPI one cycle to move WAIT_NEXT -> STOP -> IDLE
          state_memory <= S_START;
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
          begin
            fetch_done        <= 1'b1;
            flash_stream_open <= spi_cont;
            last_fetch_addr   <= spi_addr;
          end
          else
          begin
            data_done         <= 1'b1;
            flash_stream_open <= 1'b0;
          end

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
  localparam C_REQ_FETCH  = 2'd0;
  localparam C_WAIT_FETCH = 2'd1;
  localparam C_EXECUTE    = 2'd2;
  localparam C_WAIT_DATA  = 2'd3;

  reg [1:0] state_cycler;
  reg       fetch_req;

  always @(posedge clk)
  begin
    if (rst)
    begin
      fetch_req     <= 1'b1;
      execute_now   <= 1'b0;
      state_cycler  <= C_REQ_FETCH;
    end
    else
    begin
      case (state_cycler)
        C_REQ_FETCH:
        begin
          fetch_req    <= 1'b1;
          execute_now  <= 1'b0;
          state_cycler <= C_WAIT_FETCH;
        end

        C_WAIT_FETCH:
        begin
          fetch_req <= 1'b0;
          if (fetch_done)
          begin
            execute_now  <= 1'b1;
            state_cycler <= C_EXECUTE;
          end
        end

        C_EXECUTE:
        begin
          execute_now <= 1'b0;

          if (ld_req || st_req)
            state_cycler <= C_WAIT_DATA;
          else
            state_cycler <= C_REQ_FETCH;
        end

        C_WAIT_DATA:
        begin
          if (data_done)
            state_cycler <= C_REQ_FETCH;
        end

        default:
        begin
          fetch_req    <= 1'b1;
          execute_now  <= 1'b0;
          state_cycler <= C_REQ_FETCH;
        end
      endcase
    end
  end

endmodule
