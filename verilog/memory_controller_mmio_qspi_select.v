module memory_controller_mmio_qspi_select (
    input  wire        clk,
    input  wire        rst,

    // CPU side memory requests
    input  wire        ld_req,
    input  wire        st_req,
    input  wire [15:0] fetch_addr,
    input  wire [15:0] data_addr,
    input  wire [15:0] store_data,

    output reg  [15:0] mem_rdata,
    output reg         fetch_done,
    output reg         data_done,

    // CPU IO/MMIO side
    input  wire [15:0] dOut,
    input  wire [15:0] Addr,
    input  wire        ioW,
    input  wire        ioR,

    input  wire [15:0] memCtrlAddr,
    input  wire [15:0] memCmdAddr,
    input  wire [15:0] memStatusAddr,
    output wire [15:0] MemOut,

    // Legacy SPI engine (flash in normal SPI mode, RAM for now)
    output reg         spi_st,
    output reg         spi_ld,
    output reg  [15:0] spi_addr,
    output reg  [15:0] spi_data_in,
    output reg         spi_target,      // 0 = flash, 1 = ram
    input  wire [15:0] spi_data_out,
    input  wire        spi_busy,

    // QSPI flash fetch path (read-only for now)
    output reg         qspi_fetch_start,
    output reg  [15:0] qspi_fetch_addr,
    input  wire [15:0] qspi_fetch_data_out,
    input  wire        qspi_fetch_busy,
    input  wire        qspi_fetch_done,

    // external status / later command engines
    input  wire        flash_qe_ok_in,
    input  wire        ram_qpi_active_in,
    input  wire        ext_mem_error_in,

    // desired policy bits (from MMIO control register)
    output wire        req_flash_quad_read,
    output wire        req_cont_fetch,
    output wire        req_ram_qpi,

    // actually active inside memory subsystem right now
    output reg         flash_quad_active,
    output reg         cont_fetch_active,

    // safe command pulses, emitted only while memory controller is idle
    output reg         cmd_flash_set_qe,
    output reg         cmd_flash_clear_qe,
    output reg         cmd_ram_enter_qpi,
    output reg         cmd_ram_exit_qpi,
    output reg         cmd_flash_if_reset,
    output reg         cmd_ram_if_reset,

    // cpu cycler
    output reg         execute_now,
    output wire        pc_en
);

  // ------------------------------------------------------------
  // Memory operation FSM
  // ------------------------------------------------------------
  localparam OP_NONE  = 2'd0;
  localparam OP_FETCH = 2'd1;
  localparam OP_LOAD  = 2'd2;
  localparam OP_STORE = 2'd3;

  localparam S_IDLE               = 3'd0;
  localparam S_START              = 3'd1;
  localparam S_WAIT_SPI_BUSY_HIGH = 3'd2;
  localparam S_WAIT_SPI_BUSY_LOW  = 3'd3;
  localparam S_WAIT_QSPI_BUSY     = 3'd4;
  localparam S_WAIT_QSPI_DONE     = 3'd5;
  localparam S_FINISH             = 3'd6;

  reg [2:0] state_memory;
  reg [1:0] op;
  reg       mem_stall;
  reg       use_qspi_path;

  // ------------------------------------------------------------
  // MMIO control / status
  // ------------------------------------------------------------
  reg [15:0] mem_ctrl;
  reg [5:0]  cmd_pending;
  reg        ctrl_apply_pending;
  reg        mem_error_latched;

  wire wr_memctrl   = ioW && (Addr == memCtrlAddr);
  wire wr_memcmd    = ioW && (Addr == memCmdAddr);
  wire rd_memctrl   = ioR && (Addr == memCtrlAddr);
  wire rd_memcmd    = ioR && (Addr == memCmdAddr);
  wire rd_memstatus = ioR && (Addr == memStatusAddr);

  assign req_flash_quad_read = mem_ctrl[0];
  assign req_cont_fetch      = mem_ctrl[1];
  assign req_ram_qpi         = mem_ctrl[2];

  wire mem_busy_status;
  wire [15:0] mem_status;

  assign mem_busy_status = (state_memory != S_IDLE) || mem_stall || spi_busy || qspi_fetch_busy || ctrl_apply_pending || (cmd_pending != 6'b000000);

  assign mem_status = {
      11'h000,
      (mem_error_latched | ext_mem_error_in),
      ram_qpi_active_in,
      flash_quad_active,
      flash_qe_ok_in,
      mem_busy_status
  };

  assign MemOut = rd_memctrl   ? mem_ctrl   :
                  rd_memcmd    ? 16'h0000   :
                  rd_memstatus ? mem_status :
                                  16'h0000;

  // ------------------------------------------------------------
  // Main memory control FSM + MMIO handling
  // ------------------------------------------------------------
  always @(posedge clk)
  begin
    if (rst)
    begin
      state_memory       <= S_IDLE;
      op                 <= OP_NONE;
      mem_stall          <= 1'b0;
      use_qspi_path      <= 1'b0;

      mem_rdata          <= 16'h0000;
      fetch_done         <= 1'b0;
      data_done          <= 1'b0;

      spi_st             <= 1'b0;
      spi_ld             <= 1'b0;
      spi_addr           <= 16'h0000;
      spi_data_in        <= 16'h0000;
      spi_target         <= 1'b0;

      qspi_fetch_start   <= 1'b0;
      qspi_fetch_addr    <= 16'h0000;

      mem_ctrl           <= 16'h0000;
      cmd_pending        <= 6'b000000;
      ctrl_apply_pending <= 1'b0;
      mem_error_latched  <= 1'b0;

      flash_quad_active  <= 1'b0;
      cont_fetch_active  <= 1'b0;

      cmd_flash_set_qe   <= 1'b0;
      cmd_flash_clear_qe <= 1'b0;
      cmd_ram_enter_qpi  <= 1'b0;
      cmd_ram_exit_qpi   <= 1'b0;
      cmd_flash_if_reset <= 1'b0;
      cmd_ram_if_reset   <= 1'b0;
    end
    else
    begin
      fetch_done         <= 1'b0;
      data_done          <= 1'b0;
      spi_st             <= 1'b0;
      spi_ld             <= 1'b0;
      qspi_fetch_start   <= 1'b0;

      cmd_flash_set_qe   <= 1'b0;
      cmd_flash_clear_qe <= 1'b0;
      cmd_ram_enter_qpi  <= 1'b0;
      cmd_ram_exit_qpi   <= 1'b0;
      cmd_flash_if_reset <= 1'b0;
      cmd_ram_if_reset   <= 1'b0;

      // latch desired control bits immediately; apply them only when safe
      if (wr_memctrl)
      begin
        mem_ctrl           <= dOut;
        ctrl_apply_pending <= 1'b1;
      end

      // queue commands; do not emit them immediately
      if (wr_memcmd)
        cmd_pending <= cmd_pending | dOut[5:0];

      case (state_memory)
        S_IDLE:
        begin
          mem_stall <= 1'b0;
          op        <= OP_NONE;

          // First priority: safely emit pending config commands / apply mode bits.
          // This keeps mode changes from happening in the middle of a fetch/data op.
          if (cmd_pending != 6'b000000)
          begin
            mem_stall <= 1'b1;

            if (cmd_pending[0])
            begin
              cmd_flash_set_qe <= 1'b1;
              cmd_pending[0]   <= 1'b0;
            end
            else if (cmd_pending[1])
            begin
              cmd_flash_clear_qe <= 1'b1;
              cmd_pending[1]     <= 1'b0;
              flash_quad_active  <= 1'b0;
            end
            else if (cmd_pending[2])
            begin
              cmd_ram_enter_qpi <= 1'b1;
              cmd_pending[2]    <= 1'b0;
            end
            else if (cmd_pending[3])
            begin
              cmd_ram_exit_qpi <= 1'b1;
              cmd_pending[3]   <= 1'b0;
            end
            else if (cmd_pending[4])
            begin
              cmd_flash_if_reset <= 1'b1;
              cmd_pending[4]     <= 1'b0;
              flash_quad_active  <= 1'b0;
              mem_error_latched  <= 1'b0;
            end
            else if (cmd_pending[5])
            begin
              cmd_ram_if_reset  <= 1'b1;
              cmd_pending[5]    <= 1'b0;
              mem_error_latched <= 1'b0;
            end
          end
          else if (ctrl_apply_pending)
          begin
            mem_stall <= 1'b1;

            // Apply only the parts that this controller really owns.
            // Flash quad fetch becomes active only when QE is reported good.
            if (mem_ctrl[0] && !flash_qe_ok_in)
            begin
              flash_quad_active <= 1'b0;
              mem_error_latched <= 1'b1;
            end
            else
            begin
              flash_quad_active <= mem_ctrl[0];
            end

            cont_fetch_active  <= mem_ctrl[1];
            ctrl_apply_pending <= 1'b0;
          end
          else if (st_req && execute_now)
          begin
            op          <= OP_STORE;
            spi_target  <= 1'b1;      // RAM
            spi_addr    <= data_addr;
            spi_data_in <= store_data;
            use_qspi_path <= 1'b0;
            mem_stall   <= 1'b1;
            state_memory <= S_START;
          end
          else if (ld_req && execute_now)
          begin
            op          <= OP_LOAD;
            spi_target  <= 1'b1;      // RAM for now
            spi_addr    <= data_addr;
            spi_data_in <= 16'h0000;
            use_qspi_path <= 1'b0;
            mem_stall   <= 1'b1;
            state_memory <= S_START;
          end
          else if (fetch_req)
          begin
            op          <= OP_FETCH;
            spi_target  <= 1'b0;      // FLASH on legacy SPI path
            spi_addr    <= fetch_addr;
            spi_data_in <= 16'h0000;
            qspi_fetch_addr <= fetch_addr;
            use_qspi_path <= flash_quad_active;
            mem_stall   <= 1'b1;
            state_memory <= S_START;
          end
        end

        S_START:
        begin
          if (use_qspi_path)
          begin
            qspi_fetch_start <= 1'b1;
            state_memory     <= S_WAIT_QSPI_BUSY;
          end
          else
          begin
            if (op == OP_STORE)
              spi_st <= 1'b1;
            else if (op == OP_LOAD || op == OP_FETCH)
              spi_ld <= 1'b1;

            state_memory <= S_WAIT_SPI_BUSY_HIGH;
          end
        end

        S_WAIT_SPI_BUSY_HIGH:
        begin
          if (spi_busy)
            state_memory <= S_WAIT_SPI_BUSY_LOW;
        end

        S_WAIT_SPI_BUSY_LOW:
        begin
          if (!spi_busy)
          begin
            if (op == OP_LOAD || op == OP_FETCH)
              mem_rdata <= spi_data_out;

            state_memory <= S_FINISH;
          end
        end

        S_WAIT_QSPI_BUSY:
        begin
          if (qspi_fetch_busy)
            state_memory <= S_WAIT_QSPI_DONE;
          else if (qspi_fetch_done)
          begin
            mem_rdata    <= qspi_fetch_data_out;
            state_memory <= S_FINISH;
          end
        end

        S_WAIT_QSPI_DONE:
        begin
          if (qspi_fetch_done)
          begin
            mem_rdata    <= qspi_fetch_data_out;
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

  // ------------------------------------------------------------
  // CPU cycler (kept close to your original timing)
  // ------------------------------------------------------------
  localparam S_REQ_FETCH  = 2'd0;
  localparam S_WAIT_FETCH = 2'd1;
  localparam S_EXECUTE    = 2'd2;
  localparam S_WAIT_DATA  = 2'd3;

  reg [1:0] state_cycler;
  reg       fetch_req;

  assign pc_en = (!mem_stall && execute_now);

  always @(posedge clk)
  begin
    if (rst)
    begin
      fetch_req    <= 1'b1;
      execute_now  <= 1'b0;
      state_cycler <= S_REQ_FETCH;
    end
    else
    begin
      case (state_cycler)
        S_REQ_FETCH:
        begin
          fetch_req    <= 1'b0;
          execute_now  <= 1'b0;
          state_cycler <= S_WAIT_FETCH;
        end

        S_WAIT_FETCH:
        begin
          if (fetch_done)
          begin
            state_cycler <= S_EXECUTE;
            fetch_req    <= 1'b0;
            execute_now  <= 1'b1;
          end
        end

        S_EXECUTE:
        begin
          if (ld_req || st_req)
          begin
            state_cycler <= S_WAIT_DATA;
            execute_now  <= 1'b0;
            fetch_req    <= 1'b0;
          end
          else
          begin
            state_cycler <= S_REQ_FETCH;
            execute_now  <= 1'b0;
            fetch_req    <= 1'b1;
          end

          execute_now <= 1'b0;
        end

        S_WAIT_DATA:
        begin
          if (data_done)
          begin
            state_cycler <= S_REQ_FETCH;
            fetch_req    <= 1'b1;
            execute_now  <= 1'b0;
          end
        end

        default:
        begin
          state_cycler <= S_REQ_FETCH;
          fetch_req    <= 1'b1;
          execute_now  <= 1'b0;
        end
      endcase
    end
  end

endmodule
