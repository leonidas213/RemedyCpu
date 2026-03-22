// xip_ifetch_single.v  (pure Verilog-2001, no submodule instantiation)
// Execute-in-place instruction fetch from SPI flash using 0x0B FAST_READ.
// Direct-mapped 32-byte line buffer. CPU stalls on a miss until the line fills.
// Assumes flash stores little-endian 16-bit words (low byte first).

module xip_ifetch_single

  (
    input  wire        clk,
    input  wire        rst_n,

    // CPU fetch handshake
    input  wire        if_consume,       // CPU requests next word (PC++)
    input  wire        if_flush,         // branch/jump taken
    input  wire [15:0] if_new_pc,        // word address target
    output reg         if_ready,         // 1 => if_word valid this cycle
    output reg  [15:0] if_word,          // fetched instruction word

    // SPI pins
    output reg         spi_cs_n,
    output reg         spi_sck,
    output reg         spi_mosi,
    input  wire        spi_miso
  );
  localparam ADDR_BITS      = 24; // flash address width (commonly 24)
  localparam LINE_BYTES     = 32; // bytes per line (power of two)
  localparam LINE_WORDS     = 16; // words per line (LINE_BYTES/2)
  localparam LINE_WORD_BITS = 4;  // log2(LINE_WORDS)
  localparam NUM_LINES      = 64; // number of lines (power of two)
  localparam IDX_BITS       = 6;  // log2(NUM_LINES)
  localparam LINE_SHIFT     = 5;  // log2(LINE_BYTES)
  localparam DUMMY_BYTES    = 1;  // 0x0B typically needs 1 dummy byte
  localparam DIV            = 4;   // SPI SCK divider: sck = clk/(2*DIV)
  // ---------------- PC and addressing ----------------
  reg [15:0] pc;
  wire       advance = if_ready & if_consume;

  wire [ADDR_BITS-1:0] byte_addr;        // PC (words) -> byte address
  assign byte_addr = {pc, 1'b0};

  localparam TAG_BITS = ADDR_BITS - LINE_SHIFT - IDX_BITS;

  wire [IDX_BITS-1:0] idx;
  assign idx = byte_addr[LINE_SHIFT + IDX_BITS - 1 : LINE_SHIFT];

  wire [4:0] off;
  assign off = byte_addr[4:0]; // 0..(LINE_BYTES-1)

  wire [LINE_WORD_BITS-1:0] woff;
  assign woff = off[4:1]; // word offset 0..(LINE_WORDS-1)

  wire [TAG_BITS-1:0] tag;
  assign tag = byte_addr[ADDR_BITS-1 : LINE_SHIFT + IDX_BITS];

  wire [ADDR_BITS-1:0] line_base;
  assign line_base = {byte_addr[ADDR_BITS-1:LINE_SHIFT], {LINE_SHIFT{1'b0}}};

  // ---------------- tags/valid + line RAM ----------------
  reg [TAG_BITS-1:0] tag_ram   [0:NUM_LINES-1];
  reg                valid_ram [0:NUM_LINES-1];

  localparam LINE_MEM_DEPTH = NUM_LINES * LINE_WORDS;
  reg [15:0] line_ram [0:LINE_MEM_DEPTH-1];

  wire [LINE_WORD_BITS+IDX_BITS-1:0] line_rd_addr;
  assign line_rd_addr = {idx, woff};

  wire hit;
  assign hit = (valid_ram[idx] == 1'b1) && (tag_ram[idx] == tag);

  // ---------------- init walker ----------------
  reg                init_busy;
  reg [IDX_BITS-1:0] init_idx;

  // ---------------- SPI byte engine (inline) ----------------
  // Mode-0 (CPOL=0, CPHA=0). One-byte TX/RX shifter with clock divider.
  reg [7:0] sh_tx, sh_rx;
  reg [7:0] divc;
  reg [3:0] bitc;
  reg       spi_busy;     // currently shifting a byte
  reg       spi_done;     // 1-cycle pulse when a byte completes
  reg       rx_valid;     // 1-cycle pulse when rx_byte is valid
  reg [7:0] rx_byte;      // last received byte
  reg [7:0] tx_byte;      // next byte to transmit
  reg       start_byte;   // 1-cycle strobe to start a byte
  reg       sck_phase;    // toggles to make SCK edges

  // ---------------- XIP fill FSM ----------------
  localparam ST_IDLE   = 3'd0;
  localparam ST_CMD    = 3'd1;
  localparam ST_A2     = 3'd2;
  localparam ST_A1     = 3'd3;
  localparam ST_A0     = 3'd4;
  localparam ST_DUMMY  = 3'd5;
  localparam ST_STREAM = 3'd6;

  reg [2:0] state;

  reg [ADDR_BITS-1:0] fill_base;
  reg [IDX_BITS-1:0]  fill_idx;
  reg [TAG_BITS-1:0]  fill_tag;

  reg [5:0]  fill_byte; // 0..(LINE_BYTES-1) (supports up to 64B lines)
  reg [7:0]  low_byte;
  reg        have_low;
  reg [3:0]  dummy_cnt;
  reg        abort_req;

  wire [LINE_WORD_BITS+IDX_BITS-1:0] line_wr_addr;
  assign line_wr_addr = {fill_idx, fill_byte[4:1]};

  integer i;

  // ================= SPI BYTE ENGINE =================
  // Generates spi_sck, shifts MOSI, samples MISO, delivers rx_byte at end of byte.
  always @(posedge clk or negedge rst_n)
  begin
    if (!rst_n)
    begin
      spi_sck    <= 1'b0;
      spi_mosi   <= 1'b0;
      spi_busy   <= 1'b0;
      spi_done   <= 1'b0;
      rx_valid   <= 1'b0;
      rx_byte    <= 8'h00;
      sh_tx      <= 8'h00;
      sh_rx      <= 8'h00;
      divc       <= 8'd0;
      bitc       <= 4'd0;
      sck_phase  <= 1'b0;
      start_byte <= 1'b0; // ignored on reset
    end
    else
    begin
      // defaults
      spi_done <= 1'b0;
      rx_valid <= 1'b0;

      // start a new byte (1-cycle strobe)
      if (start_byte && !spi_busy)
      begin
        spi_busy  <= 1'b1;
        sh_tx     <= tx_byte;
        sh_rx     <= 8'h00;
        bitc      <= 4'd8;
        divc      <= 8'd0;
        sck_phase <= 1'b0;
        spi_sck   <= 1'b0;
        spi_mosi  <= tx_byte[7];
      end

      if (spi_busy)
      begin
        if (divc == (DIV-1))
        begin
          divc      <= 8'd0;
          sck_phase <= ~sck_phase;
          spi_sck   <= ~spi_sck;

          if (sck_phase == 1'b0)
          begin
            // rising edge: sample MISO
            sh_rx <= {sh_rx[6:0], spi_miso};
          end
          else
          begin
            // falling edge: shift next bit out
            bitc   <= bitc - 1'b1;
            sh_tx  <= {sh_tx[6:0], 1'b0};
            spi_mosi <= sh_tx[6];

            if (bitc == 4'd1)
            begin
              spi_busy <= 1'b0;
              spi_done <= 1'b1;
              rx_byte  <= {sh_rx[6:0], spi_miso};
              rx_valid <= 1'b1;
              spi_sck  <= 1'b0; // park low
            end
          end
        end
        else
        begin
          divc <= divc + 1'b1;
        end
      end
    end
  end

  // ================= TOP-LEVEL CONTROL =================
  always @(posedge clk or negedge rst_n)
  begin
    if (!rst_n)
    begin
      pc        <= 16'h0000;
      if_ready  <= 1'b0;
      if_word   <= 16'h0000;

      spi_cs_n  <= 1'b1;
      tx_byte   <= 8'h00;
      start_byte<= 1'b0;

      state     <= ST_IDLE;
      fill_base <= {ADDR_BITS{1'b0}};
      fill_idx  <= {IDX_BITS{1'b0}};
      fill_tag  <= {TAG_BITS{1'b0}};
      fill_byte <= 6'd0;
      low_byte  <= 8'h00;
      have_low  <= 1'b0;
      dummy_cnt <= 4'd0;
      abort_req <= 1'b0;

      init_busy <= 1'b1;
      init_idx  <= {IDX_BITS{1'b0}};
      for (i=0; i<NUM_LINES; i=i+1)
      begin
        valid_ram[i] <= 1'b0;
        tag_ram[i]   <= {TAG_BITS{1'b0}};
      end
    end
    else
    begin
      // default: don't start a byte unless commanded below
      start_byte <= 1'b0;

      // init walker: clear valid/tag entries over NUM_LINES cycles
      if (init_busy)
      begin
        valid_ram[init_idx] <= 1'b0;
        tag_ram[init_idx]   <= {TAG_BITS{1'b0}};
        if (init_idx == NUM_LINES-1)
        begin
          init_busy <= 1'b0;
        end
        init_idx <= init_idx + 1'b1;

        if_ready <= 1'b0;
      end
      else
      begin
        // PC management
        if (if_flush)
        begin
          pc       <= if_new_pc;
          if_ready <= 1'b0;
          abort_req<= 1'b1; // request to abort ongoing fill after current byte
        end
        else if (advance)
        begin
          pc <= pc + 16'd1;
        end

        // serve hits from line RAM
        if (hit)
        begin
          if_word  <= line_ram[line_rd_addr];
          if_ready <= 1'b1;
        end
        else
        begin
          if_ready <= 1'b0;
        end

        // On miss, kick a new line fill when idle (and not aborting)
        if (!hit && (state == ST_IDLE) && !abort_req)
        begin
          spi_cs_n  <= 1'b0;
          state     <= ST_CMD;
          tx_byte   <= 8'h0B;   // FAST_READ opcode
          start_byte<= 1'b1;

          fill_base <= line_base;
          fill_idx  <= idx;
          fill_tag  <= tag;
          fill_byte <= 6'd0;
          have_low  <= 1'b0;
          dummy_cnt <= (DUMMY_BYTES[3:0]);
        end

        // Fill FSM using the inline SPI engine
        case (state)
          ST_IDLE:
          begin
            // nothing
          end

          ST_CMD:
          begin
            if (spi_done)
            begin
              state      <= ST_A2;
              tx_byte    <= fill_base[23:16];
              start_byte <= 1'b1;
            end
          end

          ST_A2:
          begin
            if (spi_done)
            begin
              state      <= ST_A1;
              tx_byte    <= fill_base[15:8];
              start_byte <= 1'b1;
            end
          end

          ST_A1:
          begin
            if (spi_done)
            begin
              state      <= ST_A0;
              tx_byte    <= fill_base[7:0];
              start_byte <= 1'b1;
            end
          end

          ST_A0:
          begin
            if (spi_done)
            begin
              if (DUMMY_BYTES != 0)
              begin
                state      <= ST_DUMMY;
                tx_byte    <= 8'h00;
                start_byte <= 1'b1;
              end
              else
              begin
                state      <= ST_STREAM;
                tx_byte    <= 8'h00;
                start_byte <= 1'b1;
              end
            end
          end

          ST_DUMMY:
          begin
            if (spi_done)
            begin
              if (dummy_cnt > 4'd1)
              begin
                dummy_cnt  <= dummy_cnt - 1'b1;
                tx_byte    <= 8'h00;
                start_byte <= 1'b1;
              end
              else
              begin
                dummy_cnt  <= 4'd0;
                state      <= ST_STREAM;
                tx_byte    <= 8'h00;
                start_byte <= 1'b1;
              end
            end
          end

          ST_STREAM:
          begin
            // keep clocking: send 0x00 bytes back-to-back
            if (spi_done)
            begin
              tx_byte    <= 8'h00;
              start_byte <= 1'b1;
            end

            if (rx_valid)
            begin
              if (!have_low)
              begin
                // low byte first
                low_byte  <= rx_byte;
                have_low  <= 1'b1;
                fill_byte <= fill_byte + 1'b1;
              end
              else
              begin
                // high byte -> commit word
                line_ram[line_wr_addr] <= {rx_byte, low_byte};
                have_low  <= 1'b0;
                fill_byte <= fill_byte + 1'b1;

                // end of line?
                if (fill_byte == (LINE_BYTES-1))
                begin
                  valid_ram[fill_idx] <= 1'b1;
                  tag_ram[fill_idx]   <= fill_tag;
                  spi_cs_n            <= 1'b1;
                  state               <= ST_IDLE;
                end
              end
            end

            // abort (branch) handling: stop after current byte boundary
            if (abort_req)
            begin
              if (spi_done)
              begin
                spi_cs_n  <= 1'b1;
                state     <= ST_IDLE;
                abort_req <= 1'b0;
                have_low  <= 1'b0;
              end
            end
          end

          default:
            state <= ST_IDLE;
        endcase

        // clear abort flag when idle
        if (state == ST_IDLE)
          abort_req <= 1'b0;

      end // !init_busy
    end
  end

endmodule
