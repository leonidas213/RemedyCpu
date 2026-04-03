module cpu_mem_combined
  (
    input  wire        clk,
    input  wire        rst,

    // CPU decode side
    input  wire        ld,
    input  wire        st,
    input  wire [15:0] fetch_addr,
    input  wire [15:0] data_addr,
    input  wire [15:0] store_data,

    // Outputs back to CPU / debug
    output reg  [15:0] mem_rdata,
    output wire        fetch_req,
    output wire        ld_req,
    output wire        st_req,
    output wire        pc_en,
    output wire        execute_now_pulse,
    output reg         data_done,
    // SPI engine side
    output reg         spi_st,
    output reg         spi_ld,
    output reg  [15:0] spi_addr,
    output reg  [15:0] spi_data_in,
    output reg         spi_target,   // 0 = flash, 1 = ram

    input  wire [15:0] spi_data_out,
    input  wire        spi_busy
  );

  // --------------------------------------------------------------------------
  // CPU cycle controller state
  // --------------------------------------------------------------------------
  localparam CPU_S_REQ_FETCH  = 2'd0;
  localparam CPU_S_WAIT_FETCH = 2'd1;
  localparam CPU_S_EXECUTE    = 2'd2;
  localparam CPU_S_WAIT_DATA  = 2'd3;

  reg [1:0] cpu_state;
  reg       fetch_done;


  wire fetch_req_int;
  wire execute_now;

  assign fetch_req_int = (cpu_state == CPU_S_REQ_FETCH);
  assign execute_now   = (cpu_state == CPU_S_EXECUTE);
  // --------------------------------------------------------------------------
  // Pulse on rise of execute_now
  // --------------------------------------------------------------------------
  reg execute_now_d;
  wire pulse_rise;

  always @(posedge clk)
  begin
    if (rst)
      execute_now_d <= 1'b0;
    else
      execute_now_d <= execute_now;
  end

  assign pulse_rise = execute_now & ~execute_now_d;

  // Request shaping
  assign fetch_req = fetch_req_int;
  assign ld_req    = ld & pulse_rise;
  assign st_req    = st & pulse_rise;
  assign execute_now_pulse = pulse_rise;

  // --------------------------------------------------------------------------
  // Memory wait controller state
  // --------------------------------------------------------------------------
  localparam OP_NONE  = 2'd0;
  localparam OP_FETCH = 2'd1;
  localparam OP_LOAD  = 2'd2;
  localparam OP_STORE = 2'd3;

  localparam MEM_S_IDLE           = 3'd0;
  localparam MEM_S_START          = 3'd1;
  localparam MEM_S_WAIT_BUSY_HIGH = 3'd2;
  localparam MEM_S_WAIT_BUSY_LOW  = 3'd3;
  localparam MEM_S_FINISH         = 3'd4;

  reg [2:0] mem_state;
  reg [1:0] mem_op;
  reg       mem_stall;

  // PC enable = only on execute pulse, and only when memory is not stalling
  assign pc_en = (~mem_stall) & pulse_rise;

  // --------------------------------------------------------------------------
  // CPU cycle controller sequential logic
  // --------------------------------------------------------------------------
  always @(posedge clk)
  begin
    if (rst)
    begin
      cpu_state <= CPU_S_REQ_FETCH;
    end
    else
    begin
      case (cpu_state)
        CPU_S_REQ_FETCH:
          cpu_state <= CPU_S_WAIT_FETCH;

        CPU_S_WAIT_FETCH:
          if (fetch_done)
            cpu_state <= CPU_S_EXECUTE;

        CPU_S_EXECUTE:
          if (ld || st)
            cpu_state <= CPU_S_WAIT_DATA;
          else
            cpu_state <= CPU_S_REQ_FETCH;

        CPU_S_WAIT_DATA:
          if (data_done)
            cpu_state <= CPU_S_REQ_FETCH;

        default:
          cpu_state <= CPU_S_REQ_FETCH;
      endcase
    end
  end

  // --------------------------------------------------------------------------
  // Memory wait controller sequential logic
  // --------------------------------------------------------------------------
  always @(posedge clk)
  begin
    if (rst)
    begin
      mem_state    <= MEM_S_IDLE;
      mem_op       <= OP_NONE;

      mem_rdata    <= 16'h0000;
      fetch_done   <= 1'b0;
      data_done    <= 1'b0;
      mem_stall    <= 1'b0;

      spi_st       <= 1'b0;
      spi_ld       <= 1'b0;
      spi_addr     <= 16'h0000;
      spi_data_in  <= 16'h0000;
      spi_target   <= 1'b0;
    end
    else
    begin
      fetch_done <= 1'b0;
      data_done  <= 1'b0;
      spi_st     <= 1'b0;
      spi_ld     <= 1'b0;

      case (mem_state)
        MEM_S_IDLE:
        begin
          mem_stall <= 1'b0;
          mem_op    <= OP_NONE;

          if (st_req)
          begin
            mem_op       <= OP_STORE;
            spi_target   <= 1'b1;      // RAM
            spi_addr     <= data_addr;
            spi_data_in  <= store_data;
            mem_stall    <= 1'b1;
            mem_state    <= MEM_S_START;
          end
          else if (ld_req)
          begin
            mem_op       <= OP_LOAD;
            spi_target   <= 1'b1;      // RAM
            spi_addr     <= data_addr;
            spi_data_in  <= 16'h0000;
            mem_stall    <= 1'b1;
            mem_state    <= MEM_S_START;
          end
          else if (fetch_req_int)
          begin
            mem_op       <= OP_FETCH;
            spi_target   <= 1'b0;      // FLASH
            spi_addr     <= fetch_addr;
            spi_data_in  <= 16'h0000;
            mem_stall    <= 1'b1;
            mem_state    <= MEM_S_START;
          end
        end

        MEM_S_START:
        begin
          if (mem_op == OP_STORE)
            spi_st <= 1'b1;
          else if (mem_op == OP_LOAD || mem_op == OP_FETCH)
            spi_ld <= 1'b1;

          mem_state <= MEM_S_WAIT_BUSY_HIGH;
        end

        MEM_S_WAIT_BUSY_HIGH:
        begin
          if (spi_busy)
            mem_state <= MEM_S_WAIT_BUSY_LOW;
        end

        MEM_S_WAIT_BUSY_LOW:
        begin
          if (!spi_busy)
          begin
            if (mem_op == OP_LOAD || mem_op == OP_FETCH)
              mem_rdata <= spi_data_out;

            mem_state <= MEM_S_FINISH;
          end
        end

        MEM_S_FINISH:
        begin
          mem_stall <= 1'b0;

          if (mem_op == OP_FETCH)
            fetch_done <= 1'b1;
          else
            data_done <= 1'b1;

          mem_state <= MEM_S_IDLE;
        end

        default:
        begin
          mem_state <= MEM_S_IDLE;
        end
      endcase
    end
  end

endmodule
