module spi_mem_bridge_sim
(
    input  wire        clk,        // main sim clock, for RAM write commit
    input  wire        rst,

    // from real spi master
    input  wire        cs_flash,
    input  wire        cs_ram,
    input  wire        sclk,
    input  wire        mosi,
    output reg         miso,

    // to ROM module
    output reg  [15:0] rom_addr,
    output reg         rom_sel,
    input  wire [15:0] rom_data,

    // to RAM module
    output reg  [15:0] ram_addr,
    output reg  [15:0] ram_din,
    output reg         ram_ld,
    output reg         ram_str,
    input  wire [15:0] ram_data
);

  reg [7:0]  cmd_shift;
  reg [15:0] addr_shift;
  reg [15:0] wr_shift;
  reg [15:0] rd_shift;

  reg [7:0]  cmd;
  reg [15:0] addr;

  reg [5:0]  bit_count;
  reg [4:0]  read_bit_count;
  reg        active_dev;      // 0 = flash, 1 = ram

  reg        read_arm;
  reg        read_active;

  reg        write_commit_pending;
  reg [15:0] write_commit_addr;
  reg [15:0] write_commit_data;

  reg [7:0]  next_cmd;
  reg [15:0] next_addr;
  reg [15:0] next_wr;

  wire any_cs_active;
  assign any_cs_active = (~cs_flash) | (~cs_ram);

  initial begin
    miso                 = 1'b0;
    rom_addr             = 16'h0000;
    rom_sel              = 1'b0;
    ram_addr             = 16'h0000;
    ram_din              = 16'h0000;
    ram_ld               = 1'b0;
    ram_str              = 1'b0;

    cmd_shift            = 8'h00;
    addr_shift           = 16'h0000;
    wr_shift             = 16'h0000;
    rd_shift             = 16'h0000;
    cmd                  = 8'h00;
    addr                 = 16'h0000;
    bit_count            = 6'd0;
    read_bit_count       = 5'd0;
    active_dev           = 1'b0;
    read_arm             = 1'b0;
    read_active          = 1'b0;

    write_commit_pending = 1'b0;
    write_commit_addr    = 16'h0000;
    write_commit_data    = 16'h0000;
  end

  // reset / end-of-transaction cleanup
  always @(posedge rst or posedge cs_flash or posedge cs_ram) begin
    if (rst) begin
      miso                 <= 1'b0;
      rom_sel              <= 1'b0;
      ram_ld               <= 1'b0;
      ram_str              <= 1'b0;

      cmd_shift            <= 8'h00;
      addr_shift           <= 16'h0000;
      wr_shift             <= 16'h0000;
      rd_shift             <= 16'h0000;
      cmd                  <= 8'h00;
      addr                 <= 16'h0000;
      bit_count            <= 6'd0;
      read_bit_count       <= 5'd0;
      active_dev           <= 1'b0;
      read_arm             <= 1'b0;
      read_active          <= 1'b0;

      write_commit_pending <= 1'b0;
    end
    else if (cs_flash && cs_ram) begin
      miso           <= 1'b0;
      rom_sel        <= 1'b0;
      ram_ld         <= 1'b0;
      ram_str        <= 1'b0;

      cmd_shift      <= 8'h00;
      addr_shift     <= 16'h0000;
      wr_shift       <= 16'h0000;
      rd_shift       <= 16'h0000;
      cmd            <= 8'h00;
      addr           <= 16'h0000;
      bit_count      <= 6'd0;
      read_bit_count <= 5'd0;
      read_arm       <= 1'b0;
      read_active    <= 1'b0;
    end
  end

  // sample MOSI on rising edge of SPI clock
  always @(posedge sclk) begin
    if (!rst && any_cs_active) begin
      active_dev <= (~cs_flash) ? 1'b0 : 1'b1;

      // command byte
      if (bit_count < 6'd8) begin
        next_cmd  = {cmd_shift[6:0], mosi};
        cmd_shift <= next_cmd;
        bit_count <= bit_count + 6'd1;

        if (bit_count == 6'd7)
          cmd <= next_cmd;
      end
      // 16-bit address
      else if (bit_count < 6'd24) begin
        next_addr  = {addr_shift[14:0], mosi};
        addr_shift <= next_addr;
        bit_count  <= bit_count + 6'd1;

        if (bit_count == 6'd23) begin
          addr           <= next_addr;
          read_bit_count <= 5'd0;

          if (!cs_flash) begin
            rom_addr <= next_addr;

            if (cmd == 8'h03) begin
              rom_sel  <= 1'b1;
              read_arm <= 1'b1;
            end
          end
          else begin
            ram_addr <= next_addr;

            if (cmd == 8'h03) begin
              ram_ld   <= 1'b1;
              read_arm <= 1'b1;
            end
          end
        end
      end
      // write payload for RAM write
      else if ((cmd == 8'h02) && (bit_count < 6'd40)) begin
        next_wr  = {wr_shift[14:0], mosi};
        wr_shift <= next_wr;
        bit_count <= bit_count + 6'd1;

        if (bit_count == 6'd39) begin
          if (!cs_ram) begin
            write_commit_addr    <= addr;
            write_commit_data    <= next_wr;
            write_commit_pending <= 1'b1;
          end
        end
      end
      // continuous read streaming
      else if ((cmd == 8'h03) && read_active) begin
        if (read_bit_count == 5'd15) begin
          addr           <= addr + 16'd1;
          read_bit_count <= 5'd0;
          read_arm       <= 1'b1;

          if (!cs_flash) begin
            rom_addr <= addr + 16'd1;
            rom_sel  <= 1'b1;
          end
          else begin
            ram_addr <= addr + 16'd1;
            ram_ld   <= 1'b1;
          end
        end
        else begin
          read_bit_count <= read_bit_count + 5'd1;
        end
      end
    end
  end

  // drive MISO on falling edge so master can sample on following rising edge
  always @(negedge sclk) begin
    if (!rst && any_cs_active) begin
      if (read_arm) begin
        if (!cs_flash) begin
          miso     <= rom_data[15];
          rd_shift <= {rom_data[14:0], 1'b0};
        end
        else begin
          miso     <= ram_data[15];
          rd_shift <= {ram_data[14:0], 1'b0};
        end

        read_arm    <= 1'b0;
        read_active <= 1'b1;
      end
      else if (read_active) begin
        miso     <= rd_shift[15];
        rd_shift <= {rd_shift[14:0], 1'b0};
      end
      else begin
        miso <= 1'b0;
      end
    end
  end

  // commit RAM write on main sim clock
  always @(posedge clk or posedge rst) begin
    if (rst) begin
      ram_str              <= 1'b0;
      ram_din              <= 16'h0000;
      ram_addr             <= 16'h0000;
      write_commit_pending <= 1'b0;
    end
    else begin
      ram_str <= 1'b0;

      if (write_commit_pending) begin
        ram_addr             <= write_commit_addr;
        ram_din              <= write_commit_data;
        ram_str              <= 1'b1;
        write_commit_pending <= 1'b0;
      end
    end
  end

endmodule
