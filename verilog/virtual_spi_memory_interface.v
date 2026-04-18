module spi_mem_bridge_sim
(
    input  wire        clk,
    input  wire        rst_n,

    input  wire        cs_flash,
    input  wire        cs_ram,
    input  wire        sclk,
    input  wire        mosi,
    output reg         miso,

    output reg  [15:0] rom_addr,
    output reg         rom_sel,
    input  wire [15:0] rom_data,

    output reg  [15:0] ram_addr,
    output reg  [15:0] ram_din,
    output reg         ram_ld,
    output reg         ram_str,
    input  wire [15:0] ram_data
);

  reg [7:0]  cmd_shift;
  reg [23:0] addr_shift;
  reg [15:0] wr_shift;
  reg [15:0] rd_shift;

  reg [7:0]  cmd;
  reg [23:0] addr_full;
  reg [15:0] addr;

  reg [5:0]  bit_count;

  reg        read_arm;
  reg        read_active;

  reg        write_commit_pending;
  reg [15:0] write_commit_addr;
  reg [15:0] write_commit_data;

  reg [7:0]  next_cmd;
  reg [23:0] next_addr;
  reg [15:0] next_wr;

  wire flash_active;
  wire ram_active;
  wire any_cs_active;

  assign flash_active  = ~cs_flash;
  assign ram_active    = ~cs_ram;
  assign any_cs_active = flash_active | ram_active;

  initial begin
    miso                 = 1'b0;
    rom_addr             = 16'h0000;
    rom_sel              = 1'b0;
    ram_addr             = 16'h0000;
    ram_din              = 16'h0000;
    ram_ld               = 1'b0;
    ram_str              = 1'b0;

    cmd_shift            = 8'h00;
    addr_shift           = 24'h000000;
    wr_shift             = 16'h0000;
    rd_shift             = 16'h0000;

    cmd                  = 8'h00;
    addr_full            = 24'h000000;
    addr                 = 16'h0000;
    bit_count            = 6'd0;

    read_arm             = 1'b0;
    read_active          = 1'b0;

    write_commit_pending = 1'b0;
    write_commit_addr    = 16'h0000;
    write_commit_data    = 16'h0000;
  end

  always @(negedge rst_n or posedge cs_flash or posedge cs_ram) begin
    if (!rst_n) begin
      miso                 <= 1'b0;
      rom_sel              <= 1'b0;
      ram_ld               <= 1'b0;
      ram_str              <= 1'b0;

      cmd_shift            <= 8'h00;
      addr_shift           <= 24'h000000;
      wr_shift             <= 16'h0000;
      rd_shift             <= 16'h0000;

      cmd                  <= 8'h00;
      addr_full            <= 24'h000000;
      addr                 <= 16'h0000;
      bit_count            <= 6'd0;

      read_arm             <= 1'b0;
      read_active          <= 1'b0;

      write_commit_pending <= 1'b0;
    end
    else if (cs_flash && cs_ram) begin
      miso        <= 1'b0;
      rom_sel     <= 1'b0;
      ram_ld      <= 1'b0;
      ram_str     <= 1'b0;

      cmd_shift   <= 8'h00;
      addr_shift  <= 24'h000000;
      wr_shift    <= 16'h0000;
      rd_shift    <= 16'h0000;

      cmd         <= 8'h00;
      addr_full   <= 24'h000000;
      addr        <= 16'h0000;
      bit_count   <= 6'd0;

      read_arm    <= 1'b0;
      read_active <= 1'b0;
    end
  end

  always @(posedge sclk) begin
    if (rst_n && any_cs_active) begin
      if (bit_count < 6'd8) begin
        next_cmd  = {cmd_shift[6:0], mosi};
        cmd_shift <= next_cmd;

        if (bit_count == 6'd7)
          cmd <= next_cmd;
      end
      else if (bit_count < 6'd32) begin
        next_addr  = {addr_shift[22:0], mosi};
        addr_shift <= next_addr;

        if (bit_count == 6'd31) begin
          addr_full <= next_addr;
          addr      <= next_addr[16:1];

          if (flash_active) begin
            rom_addr <= next_addr[16:1];

            if (cmd == 8'h03) begin
              rom_sel  <= 1'b1;
              read_arm <= 1'b1;
            end
          end
          else if (ram_active) begin
            ram_addr <= next_addr[16:1];

            if (cmd == 8'h03) begin
              ram_ld   <= 1'b1;
              read_arm <= 1'b1;
            end
          end
        end
      end
      else if ((cmd == 8'h02) && ram_active && (bit_count < 6'd48)) begin
        next_wr  = {wr_shift[14:0], mosi};
        wr_shift <= next_wr;

        if (bit_count == 6'd47) begin
          write_commit_addr    <= addr;
          write_commit_data    <= next_wr;
          write_commit_pending <= 1'b1;
        end
      end

      bit_count <= bit_count + 6'd1;
    end
  end

  always @(negedge sclk) begin
    if (rst_n && any_cs_active) begin
      if (read_arm) begin
        if (flash_active) begin
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
    else begin
      miso <= 1'b0;
    end
  end

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
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