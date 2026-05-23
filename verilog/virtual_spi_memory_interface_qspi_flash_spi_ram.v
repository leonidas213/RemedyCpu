// Simulation-only SPI-RAM + continuous-QSPI-flash bridge.
//
// This is a Verilog counterpart of the cocotb spimemory.py models:
//   RAM   : plain SPI, command 0x03 read / 0x02 write, 24-bit byte address,
//           16-bit word payload used by qspi_memory_interface.
//   Flash : init/config is plain 1-bit SPI commands. Runtime read starts only
//           after opcode 0xEB has been seen; after that each new flash-CS-low
//           transaction is decoded as commandless continuous QSPI read:
//              6 address nibbles, 2 mode nibbles, 4 dummy clocks, 4 data nibbles.
//
// Not synthesizable. Intended for RTL/schematic simulation only.

module spi_mem_bridge_sim (
    input  wire        clk,          // main sim clock, used for RAM write commit
    input  wire        rst_n,        // active-low reset

    // from qspi_memory_interface
    input  wire        cs_flash,     // active low
    input  wire        cs_ram,       // active low
    input  wire        sclk,
    input  wire [3:0]  spi_data_out, // master -> memory IO pins
    input  wire [3:0]  spi_data_oe,  // master output enable; informational/debug
    output reg  [3:0]  spi_data_in,  // memory -> master IO pins

    // to ROM / flash contents module, word-addressed
    output reg  [15:0] rom_addr,
    output reg         rom_sel,
    input  wire [15:0] rom_data,

    // to RAM module, word-addressed
    output reg  [15:0] ram_addr,
    output reg  [15:0] ram_din,
    output reg         ram_ld,
    output reg         ram_str,
    input  wire [15:0] ram_data
);

  // ------------------------------------------------------------
  // Common helpers
  // ------------------------------------------------------------
  wire flash_active = ~cs_flash;
  wire ram_active   = ~cs_ram;
  wire any_active   = flash_active | ram_active;
  wire mosi         = spi_data_out[0];

  function [15:0] byte_to_word_addr;
    input [23:0] baddr;
    begin
      // qspi_memory_interface emits byte addresses with bit0 = 0.
      // Internal sim RAM/ROM ports are word-addressed.
      byte_to_word_addr = baddr[16:1];
    end
  endfunction

  // ------------------------------------------------------------
  // Flash model state
  // ------------------------------------------------------------
  localparam F_CMD    = 3'd0;
  localparam F_ADDR   = 3'd1;
  localparam F_MODE   = 3'd2;
  localparam F_DUMMY  = 3'd3;
  localparam F_DATA   = 3'd4;
  localparam F_IGNORE = 3'd5;

  reg        flash_continuous_enabled;
  reg [2:0]  flash_state;
  reg [2:0]  flash_count;
  reg [7:0]  flash_cmd_shift;
  reg [23:0] flash_addr_shift;
  reg [7:0]  flash_mode_shift;
  reg [15:0] flash_rd_shift;
  reg        flash_read_arm;
  reg        flash_read_active;
  reg [1:0]  flash_data_count;

  reg [7:0]  next_flash_cmd;
  reg [23:0] next_flash_addr;
  reg [7:0]  next_flash_mode;

  // ------------------------------------------------------------
  // RAM SPI model state
  // ------------------------------------------------------------
  localparam R_CMD    = 2'd0;
  localparam R_ADDR   = 2'd1;
  localparam R_DATA   = 2'd2;
  localparam R_IGNORE = 2'd3;

  reg [1:0]  ram_state;
  reg [6:0]  ram_bit_count;
  reg [7:0]  ram_cmd_shift;
  reg [7:0]  ram_cmd;
  reg [23:0] ram_addr_shift;
  reg [23:0] ram_byte_addr;
  reg [15:0] ram_wr_shift;
  reg [15:0] ram_rd_shift;
  reg        ram_read_arm;
  reg        ram_read_active;

  reg [7:0]  next_ram_cmd;
  reg [23:0] next_ram_addr;
  reg [15:0] next_ram_wr;

  // RAM write is committed on clk so external RAM modules see a clean pulse.
  reg        write_commit_pending;
  reg [15:0] write_commit_addr;
  reg [15:0] write_commit_data;

  initial begin
    spi_data_in = 4'h0;

    rom_addr = 16'h0000;
    rom_sel  = 1'b0;

    ram_addr = 16'h0000;
    ram_din  = 16'h0000;
    ram_ld   = 1'b0;
    ram_str  = 1'b0;

    flash_continuous_enabled = 1'b0;
    flash_state = F_CMD;
    flash_count = 3'd0;
    flash_cmd_shift = 8'h00;
    flash_addr_shift = 24'h000000;
    flash_mode_shift = 8'h00;
    flash_rd_shift = 16'h0000;
    flash_read_arm = 1'b0;
    flash_read_active = 1'b0;
    flash_data_count = 2'd0;

    ram_state = R_CMD;
    ram_bit_count = 7'd0;
    ram_cmd_shift = 8'h00;
    ram_cmd = 8'h00;
    ram_addr_shift = 24'h000000;
    ram_byte_addr = 24'h000000;
    ram_wr_shift = 16'h0000;
    ram_rd_shift = 16'h0000;
    ram_read_arm = 1'b0;
    ram_read_active = 1'b0;

    write_commit_pending = 1'b0;
    write_commit_addr = 16'h0000;
    write_commit_data = 16'h0000;
  end

  // ------------------------------------------------------------
  // Reset / CS-high transaction cleanup.
  // Important: do NOT clear write_commit_pending on CS high, otherwise a write
  // that completed just before CS rises can be lost before clk commits it.
  // ------------------------------------------------------------
  always @(negedge rst_n or posedge cs_flash or posedge cs_ram) begin
    if (!rst_n) begin
      spi_data_in <= 4'h0;
      rom_sel <= 1'b0;
      ram_ld  <= 1'b0;
      ram_str <= 1'b0;

      flash_continuous_enabled <= 1'b0;
      flash_state <= F_CMD;
      flash_count <= 3'd0;
      flash_cmd_shift <= 8'h00;
      flash_addr_shift <= 24'h000000;
      flash_mode_shift <= 8'h00;
      flash_rd_shift <= 16'h0000;
      flash_read_arm <= 1'b0;
      flash_read_active <= 1'b0;
      flash_data_count <= 2'd0;

      ram_state <= R_CMD;
      ram_bit_count <= 7'd0;
      ram_cmd_shift <= 8'h00;
      ram_cmd <= 8'h00;
      ram_addr_shift <= 24'h000000;
      ram_byte_addr <= 24'h000000;
      ram_wr_shift <= 16'h0000;
      ram_rd_shift <= 16'h0000;
      ram_read_arm <= 1'b0;
      ram_read_active <= 1'b0;

      write_commit_pending <= 1'b0;
      write_commit_addr <= 16'h0000;
      write_commit_data <= 16'h0000;
    end else if (cs_flash && cs_ram) begin
      spi_data_in <= 4'h0;
      rom_sel <= 1'b0;
      ram_ld  <= 1'b0;

      // Prepare flash state for next transaction.
      if (flash_continuous_enabled)
        flash_state <= F_ADDR;
      else
        flash_state <= F_CMD;
      flash_count <= 3'd0;
      flash_cmd_shift <= 8'h00;
      flash_addr_shift <= 24'h000000;
      flash_mode_shift <= 8'h00;
      flash_rd_shift <= 16'h0000;
      flash_read_arm <= 1'b0;
      flash_read_active <= 1'b0;
      flash_data_count <= 2'd0;

      ram_state <= R_CMD;
      ram_bit_count <= 7'd0;
      ram_cmd_shift <= 8'h00;
      ram_cmd <= 8'h00;
      ram_addr_shift <= 24'h000000;
      ram_byte_addr <= 24'h000000;
      ram_wr_shift <= 16'h0000;
      ram_rd_shift <= 16'h0000;
      ram_read_arm <= 1'b0;
      ram_read_active <= 1'b0;
    end
  end

  // ------------------------------------------------------------
  // Capture MOSI/QSPI on rising SCLK, matching spimemory.py behavior.
  // ------------------------------------------------------------
  always @(posedge sclk) begin
    if (rst_n && any_active) begin
      // -------------------- RAM: plain SPI --------------------
      if (ram_active) begin
        case (ram_state)
          R_CMD: begin
            next_ram_cmd = {ram_cmd_shift[6:0], mosi};
            ram_cmd_shift <= next_ram_cmd;

            if (ram_bit_count == 7'd7) begin
              ram_cmd <= next_ram_cmd;
              ram_bit_count <= 7'd0;
              ram_addr_shift <= 24'h000000;

              if ((next_ram_cmd == 8'h02) || (next_ram_cmd == 8'h03)) begin
                ram_state <= R_ADDR;
`ifdef SPI_MEM_BRIDGE_DEBUG
                $display("[%0t] BRIDGE RAM CMD %02h", $time, next_ram_cmd);
`endif
              end else begin
                ram_state <= R_IGNORE;
`ifdef SPI_MEM_BRIDGE_DEBUG
                $display("[%0t] BRIDGE RAM unsupported opcode %02h", $time, next_ram_cmd);
`endif
              end
            end else begin
              ram_bit_count <= ram_bit_count + 7'd1;
            end
          end

          R_ADDR: begin
            next_ram_addr = {ram_addr_shift[22:0], mosi};
            ram_addr_shift <= next_ram_addr;

            if (ram_bit_count == 7'd23) begin
              ram_byte_addr <= next_ram_addr;
              ram_addr <= byte_to_word_addr(next_ram_addr);
              ram_bit_count <= 7'd0;
              ram_wr_shift <= 16'h0000;
              ram_state <= R_DATA;

              if (ram_cmd == 8'h03) begin
                ram_ld <= 1'b1;
                ram_read_arm <= 1'b1;
`ifdef SPI_MEM_BRIDGE_DEBUG
                $display("[%0t] BRIDGE RAM READ addr24=%06h word_addr=%04h", $time, next_ram_addr, byte_to_word_addr(next_ram_addr));
`endif
              end
            end else begin
              ram_bit_count <= ram_bit_count + 7'd1;
            end
          end

          R_DATA: begin
            if (ram_cmd == 8'h02) begin
              next_ram_wr = {ram_wr_shift[14:0], mosi};
              ram_wr_shift <= next_ram_wr;

              if (ram_bit_count == 7'd15) begin
                write_commit_addr <= byte_to_word_addr(ram_byte_addr);
                write_commit_data <= next_ram_wr;
                write_commit_pending <= 1'b1;
`ifdef SPI_MEM_BRIDGE_DEBUG
                $display("[%0t] BRIDGE RAM WRITE CAPTURE addr24=%06h word_addr=%04h data=%04h",
                         $time, ram_byte_addr, byte_to_word_addr(ram_byte_addr), next_ram_wr);
`endif
                ram_bit_count <= 7'd0;
                ram_state <= R_IGNORE;
              end else begin
                ram_bit_count <= ram_bit_count + 7'd1;
              end
            end else if (ram_cmd == 8'h03) begin
              // Read bits are driven in the negedge block. Count clocks only.
              if (ram_bit_count == 7'd15) begin
                ram_bit_count <= 7'd0;
                ram_state <= R_IGNORE;
              end else begin
                ram_bit_count <= ram_bit_count + 7'd1;
              end
            end else begin
              ram_state <= R_IGNORE;
            end
          end

          default: begin
            // ignore until CS high
          end
        endcase
      end

      // -------------------- Flash --------------------
      else if (flash_active) begin
        case (flash_state)
          F_CMD: begin
            // Before continuous mode, each flash transaction is treated as a
            // 1-bit SPI init/config command. Only opcode 0xEB enables runtime.
            next_flash_cmd = {flash_cmd_shift[6:0], mosi};
            flash_cmd_shift <= next_flash_cmd;

            if (flash_count == 3'd7) begin
`ifdef SPI_MEM_BRIDGE_DEBUG
              $display("[%0t] BRIDGE FLASH INIT/SPI opcode %02h", $time, next_flash_cmd);
`endif
              if (next_flash_cmd == 8'hEB) begin
                flash_continuous_enabled <= 1'b1;
`ifdef SPI_MEM_BRIDGE_DEBUG
                $display("[%0t] BRIDGE FLASH continuous QSPI enabled", $time);
`endif
              end
              flash_count <= 3'd0;
              flash_state <= F_IGNORE; // like Python: ignore rest until CS high
            end else begin
              flash_count <= flash_count + 3'd1;
            end
          end

          F_ADDR: begin
            next_flash_addr = {flash_addr_shift[19:0], spi_data_out};
            flash_addr_shift <= next_flash_addr;

            if (flash_count == 3'd5) begin
              rom_addr <= byte_to_word_addr(next_flash_addr);
              rom_sel  <= 1'b1;
              flash_count <= 3'd0;
              flash_mode_shift <= 8'h00;
              flash_state <= F_MODE;
`ifdef SPI_MEM_BRIDGE_DEBUG
              $display("[%0t] BRIDGE FLASH RUNTIME addr24=%06h word_addr=%04h", $time, next_flash_addr, byte_to_word_addr(next_flash_addr));
`endif
            end else begin
              flash_count <= flash_count + 3'd1;
            end
          end

          F_MODE: begin
            next_flash_mode = {flash_mode_shift[3:0], spi_data_out};
            flash_mode_shift <= next_flash_mode;

            if (flash_count == 3'd1) begin
              flash_count <= 3'd0;
              flash_state <= F_DUMMY;
`ifdef SPI_MEM_BRIDGE_DEBUG
              if (next_flash_mode != 8'hA0)
                $display("[%0t] BRIDGE FLASH warning: mode=%02h, expected A0", $time, next_flash_mode);
`endif
            end else begin
              flash_count <= flash_count + 3'd1;
            end
          end

          F_DUMMY: begin
            // 4 dummy QSPI clocks, then prepare first data nibble on following negedge.
            if (flash_count == 3'd3) begin
              flash_count <= 3'd0;
              flash_data_count <= 2'd0;
              flash_read_arm <= 1'b1;
              flash_state <= F_DATA;
            end else begin
              flash_count <= flash_count + 3'd1;
            end
          end

          F_DATA: begin
            // data driven in negedge block
          end

          default: begin
            // ignore init payload / reset commands until CS high
          end
        endcase
      end
    end
  end

  // ------------------------------------------------------------
  // Drive MISO/QSPI data on falling SCLK so master samples on next rising/high.
  // ------------------------------------------------------------
  always @(negedge sclk) begin
    if (rst_n && any_active) begin
      if (ram_active) begin
        if (ram_read_arm) begin
          // RAM MISO is IO1. Other bits are irrelevant here.
          spi_data_in <= {2'b00, ram_data[15], 1'b0};
          ram_rd_shift <= {ram_data[14:0], 1'b0};
          ram_read_arm <= 1'b0;
          ram_read_active <= 1'b1;
        end else if (ram_read_active) begin
          spi_data_in <= {2'b00, ram_rd_shift[15], 1'b0};
          ram_rd_shift <= {ram_rd_shift[14:0], 1'b0};
        end else begin
          spi_data_in <= 4'h0;
        end
      end else if (flash_active && flash_state == F_DATA) begin
        if (flash_read_arm) begin
          spi_data_in <= rom_data[15:12];
          flash_rd_shift <= {rom_data[11:0], 4'h0};
          flash_read_arm <= 1'b0;
          flash_read_active <= 1'b1;
          flash_data_count <= 2'd0;
        end else if (flash_read_active) begin
          spi_data_in <= flash_rd_shift[15:12];
          flash_rd_shift <= {flash_rd_shift[11:0], 4'h0};
          flash_data_count <= flash_data_count + 2'd1;
        end else begin
          spi_data_in <= 4'h0;
        end
      end else begin
        spi_data_in <= 4'h0;
      end
    end else begin
      spi_data_in <= 4'h0;
    end
  end

  // ------------------------------------------------------------
  // Commit RAM write on main simulation clock.
  // ------------------------------------------------------------
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      ram_str <= 1'b0;
      ram_din <= 16'h0000;
      ram_addr <= 16'h0000;
      write_commit_pending <= 1'b0;
    end else begin
      ram_str <= 1'b0;

      if (write_commit_pending) begin
        ram_addr <= write_commit_addr;
        ram_din  <= write_commit_data;
        ram_str  <= 1'b1;
`ifdef SPI_MEM_BRIDGE_DEBUG
        $display("[%0t] BRIDGE RAM WRITE addr=%04h data=%04h", $time, write_commit_addr, write_commit_data);
`endif
        write_commit_pending <= 1'b0;
      end
    end
  end

endmodule
