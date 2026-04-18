module memory_wait_controller
(
    input  wire        clk,
    input  wire        rst_n,

    // CPU side
    input  wire        fetch_req,
    input  wire        ld_req,
    input  wire        st_req,
    input  wire        flash_req,

    input  wire [15:0] fetch_addr,
    input  wire [15:0] data_addr,
    input  wire [15:0] store_data,

    output reg  [15:0] mem_rdata,
    output reg         fetch_done,
    output reg         data_done,
    output reg         mem_stall,

    // SPI engine side
    output reg         spi_st,
    output reg         spi_ld,
    output reg  [15:0] spi_addr,
    output reg  [15:0] spi_data_in,
    output reg         spi_target,   // 0 = flash, 1 = ram

    // NEW
    output reg         spi_fast,     // fresh flash read uses fast-read (0x0B)
    output reg         spi_seq,      // continue current flash sequential burst

    input  wire [15:0] spi_data_out,
    input  wire        spi_busy
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
  localparam FLASH_SEQ_STEP = 16'd1;

  reg [2:0] state;
  reg [1:0] op;

  reg       use_flash_seq;
  reg       flash_stream_valid;
  reg [15:0] last_flash_addr;

  wire flash_seq_hit;
  assign flash_seq_hit =
      flash_stream_valid &&
      (fetch_addr == (last_flash_addr + FLASH_SEQ_STEP));

  always @(posedge clk or negedge rst_n)
  begin
    if (!rst_n)
    begin
      state             <= S_IDLE;
      op                <= OP_NONE;

      mem_rdata         <= 16'h0000;
      fetch_done        <= 1'b0;
      data_done         <= 1'b0;
      mem_stall         <= 1'b0;

      spi_st            <= 1'b0;
      spi_ld            <= 1'b0;
      spi_addr          <= 16'h0000;
      spi_data_in       <= 16'h0000;
      spi_target        <= 1'b0;
      spi_fast          <= 1'b0;
      spi_seq           <= 1'b0;

      use_flash_seq     <= 1'b0;
      flash_stream_valid<= 1'b0;
      last_flash_addr   <= 16'h0000;
    end
    else
    begin
      fetch_done <= 1'b0;
      data_done  <= 1'b0;
      spi_st     <= 1'b0;
      spi_ld     <= 1'b0;
      spi_fast   <= 1'b0;
      spi_seq    <= 1'b0;

      case (state)
        S_IDLE:
        begin
          mem_stall <= 1'b0;
          op        <= OP_NONE;

          if (st_req)
          begin
            op            <= OP_STORE;
            spi_target    <= 1'b1;      // RAM
            spi_addr      <= data_addr;
            spi_data_in   <= store_data;
            use_flash_seq <= 1'b0;
            mem_stall     <= 1'b1;
            state         <= S_START;
          end
          else if (ld_req)
          begin
            op            <= OP_LOAD;
            spi_target    <= 1'b1;      // RAM
            spi_addr      <= data_addr;
            spi_data_in   <= 16'h0000;
            use_flash_seq <= 1'b0;
            mem_stall     <= 1'b1;
            state         <= S_START;
          end
          else if (fetch_req)
          begin
            op            <= OP_FETCH;
            spi_target    <= 1'b0;      // FLASH
            spi_addr      <= fetch_addr;
            spi_data_in   <= 16'h0000;
            use_flash_seq <= flash_seq_hit;
            mem_stall     <= 1'b1;
            state         <= S_START;
          end
          else if(flash_req)
            begin
            op            <= OP_LOAD;
            spi_target    <= 1'b0;      // FLASH
            spi_addr      <= data_addr;
            spi_data_in   <= 16'h0000;
            use_flash_seq <= 1'b0;
            mem_stall     <= 1'b1;
            state         <= S_START;
          end
        end

        S_START:
        begin
          if (op == OP_STORE)
          begin
            spi_st <= 1'b1;
          end
          else if (op == OP_LOAD)
          begin
            spi_ld <= 1'b1;
          end
          else if (op == OP_FETCH)
          begin
            spi_ld <= 1'b1;

            if (use_flash_seq)
              spi_seq <= 1'b1;
            else
              spi_fast <= 1'b1;
          end

          state <= S_WAIT_BUSY_HIGH;
        end

        S_WAIT_BUSY_HIGH:
        begin
          if (spi_busy)
            state <= S_WAIT_BUSY_LOW;
        end

        S_WAIT_BUSY_LOW:
        begin
          if (!spi_busy)
          begin
            if (op == OP_LOAD || op == OP_FETCH)
              mem_rdata <= spi_data_out;

            state <= S_FINISH;
          end
        end

        S_FINISH:
        begin
          mem_stall <= 1'b0;

          if (op == OP_FETCH)
          begin
            fetch_done         <= 1'b1;
            flash_stream_valid <= 1'b1;
            last_flash_addr    <= spi_addr;
          end
          else
          begin
            data_done          <= 1'b1;
            flash_stream_valid <= 1'b0;
          end

          state <= S_IDLE;
        end

        default:
        begin
          state             <= S_IDLE;
          flash_stream_valid<= 1'b0;
        end
      endcase
    end
  end

endmodule