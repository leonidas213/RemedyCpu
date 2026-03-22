// ifetch_stream_core.v  (pure Verilog-2001)
// Continuous FAST_READ stream from SPI flash.
// - No submodule instantiation: connect to external SPI byte engine.
// - 4-word FIFO on the output.
// - Jump handling: abort stream and restart at new PC when jump_req=1.
// Assumes flash stores little-endian 16-bit words (low byte first).

module ifetch_stream_core (
  input  wire        clk,
  input  wire        rst_n,

  // CPU fetch side
  input  wire        if_consume,       // CPU pops one word when if_ready=1
  output wire        if_ready,         // FIFO not empty
  output wire [15:0] if_word,          // FIFO front word

  // Control
  input  wire        start,            // pulse 1x to begin streaming from boot_pc
  input  wire [15:0] boot_pc,          // word address to start from
  input  wire        jump_req,         // pulse to jump
  input  wire [15:0] jump_pc,          // word address target

  // External SPI byte-engine interface (wire in schematic)
  output reg         spi_cs_n,         // drive flash CS# (active low)
  output reg         spi_tx_start,     // 1-cycle strobe to start sending a byte
  output reg  [7:0]  spi_tx_data,      // byte to send (0x0B, addr, dummy, or 0x00)
  input  wire        spi_tx_busy,      // engine busy
  input  wire        spi_tx_done,      // 1-cycle pulse at end of byte
  input  wire [7:0]  spi_rx_data,      // received byte at end
  input  wire        spi_rx_valid      // 1-cycle pulse alongside tx_done
);

  // ------------ fixed constants ------------
  localparam ADDR_BITS   = 24;
  localparam DUMMY_BYTES = 1;

  // FSM states
  localparam ST_IDLE   = 3'd0;
  localparam ST_CMD    = 3'd1;
  localparam ST_A2     = 3'd2;
  localparam ST_A1     = 3'd3;
  localparam ST_A0     = 3'd4;
  localparam ST_DUMMY  = 3'd5;
  localparam ST_STREAM = 3'd6;

  // ------------ address tracking ------------
  // cur_baddr is the NEXT byte address that will be clocked out by flash
  reg [ADDR_BITS-1:0] cur_baddr;      // byte address
  reg [ADDR_BITS-1:0] base_baddr;     // byte address used in current FAST_READ header

  // ------------ FIFO (4 words) ------------
  reg [15:0] fifo_mem [0:3];
  reg [1:0]  fifo_rd, fifo_wr;
  reg [2:0]  fifo_cnt;                // 0..4
  assign if_ready = (fifo_cnt != 3'd0);
  assign if_word  = fifo_mem[fifo_rd];

  // ------------ byte packer ------------
  reg        have_low;                // 0: expecting low byte, 1: expecting high
  reg [7:0]  low_byte;

  // ------------ control flags ------------
  reg [2:0]  state;
  reg [3:0]  dummy_cnt;
  reg        want_start;              // internal start latch
  reg        abort_req;               // request to abort after current byte

  // Throttle: can we accept more incoming BYTES without overflowing the FIFO?
  // - Each WORD needs 2 bytes. If have_low=1, one more byte completes a word.
  wire fifo_full     = (fifo_cnt == 3'd4);
  wire fifo_almost_f = (fifo_cnt == 3'd3);
  wire can_take_byte =
      (!fifo_full) &&
      !(fifo_almost_f && have_low);   // avoid starting a byte that would overflow when it completes a word

  // ------------ helpers ------------
  wire [ADDR_BITS-1:0] boot_baddr = {boot_pc,1'b0};
  wire [ADDR_BITS-1:0] jump_baddr = {jump_pc,1'b0};

  // ------------ main seq ------------
  integer i;
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      spi_cs_n     <= 1'b1;
      spi_tx_start <= 1'b0;
      spi_tx_data  <= 8'h00;

      state        <= ST_IDLE;
      dummy_cnt    <= 4'd0;
      have_low     <= 1'b0;
      low_byte     <= 8'h00;
      abort_req    <= 1'b0;

      cur_baddr    <= {ADDR_BITS{1'b0}};
      base_baddr   <= {ADDR_BITS{1'b0}};

      fifo_rd      <= 2'd0;
      fifo_wr      <= 2'd0;
      fifo_cnt     <= 3'd0;
      for (i=0;i<4;i=i+1) fifo_mem[i] <= 16'h0000;

      want_start   <= 1'b0;
    end else begin
      spi_tx_start <= 1'b0; // default

      // Latch external start pulse (one-shot)
      if (start) want_start <= 1'b1;

      // CPU pops a word
      if (if_ready && if_consume) begin
        fifo_rd  <= fifo_rd + 2'd1;
        fifo_cnt <= fifo_cnt - 3'd1;
      end

      // Jump request: set abort; update cur_baddr when we actually restart
      if (jump_req) begin
        abort_req <= 1'b1;  // abort after current byte boundary
        // cur_baddr will be updated when we re-send header
        cur_baddr <= jump_baddr; // pre-load for header calc
      end

      case (state)
        // ================= IDLE: wait for start =================
        ST_IDLE: begin
          have_low <= 1'b0;
          if (want_start) begin
            want_start   <= 1'b0;
            spi_cs_n     <= 1'b0;
            state        <= ST_CMD;
            spi_tx_data  <= 8'h0B; // FAST_READ
            spi_tx_start <= 1'b1;
            base_baddr   <= boot_baddr & ~24'h00001F; // align to 32B boundary (optional)
            cur_baddr    <= boot_baddr;
            dummy_cnt    <= DUMMY_BYTES[3:0];
            abort_req    <= 1'b0;
          end
        end

        // ================= send command & address =================
        ST_CMD: if (spi_tx_done) begin
          state        <= ST_A2;
          spi_tx_data  <= cur_baddr[23:16];
          spi_tx_start <= 1'b1;
        end

        ST_A2: if (spi_tx_done) begin
          state        <= ST_A1;
          spi_tx_data  <= cur_baddr[15:8];
          spi_tx_start <= 1'b1;
        end

        ST_A1: if (spi_tx_done) begin
          state        <= ST_A0;
          spi_tx_data  <= cur_baddr[7:0];
          spi_tx_start <= 1'b1;
        end

        ST_A0: if (spi_tx_done) begin
          if (DUMMY_BYTES != 0) begin
            state        <= ST_DUMMY;
            spi_tx_data  <= 8'h00;
            spi_tx_start <= 1'b1;
          end else begin
            state        <= ST_STREAM;
            // start only if we can accept bytes
            if (can_take_byte) begin
              spi_tx_data  <= 8'h00;
              spi_tx_start <= 1'b1;
            end
          end
        end

        // ================= dummy cycles =================
        ST_DUMMY: if (spi_tx_done) begin
          if (dummy_cnt > 4'd1) begin
            dummy_cnt    <= dummy_cnt - 1'b1;
            spi_tx_data  <= 8'h00;
            spi_tx_start <= 1'b1;
          end else begin
            dummy_cnt    <= 4'd0;
            state        <= ST_STREAM;
            // start streaming if we can take data
            if (can_take_byte) begin
              spi_tx_data  <= 8'h00;
              spi_tx_start <= 1'b1;
            end
          end
        end

        // ================= streaming =================
        ST_STREAM: begin
          // Throttle: only clock next byte if we can store it
          if (spi_tx_done && !abort_req && can_take_byte) begin
            spi_tx_data  <= 8'h00;
            spi_tx_start <= 1'b1;
          end

          // Receive bytes, pack to words, push to FIFO
          if (spi_rx_valid) begin
            if (!have_low) begin
              low_byte <= spi_rx_data;   // low byte first
              have_low <= 1'b1;
            end else begin
              // complete a word
              fifo_mem[fifo_wr] <= {spi_rx_data, low_byte};
              fifo_wr  <= fifo_wr + 2'd1;
              fifo_cnt <= fifo_cnt + 3'd1;
              have_low <= 1'b0;
            end
            cur_baddr <= cur_baddr + 24'd1; // byte advanced
          end

          // Jump/abort: drop CS# cleanly after current byte completes
          if (abort_req) begin
            // Wait until the current byte completes to avoid partial bit
            if (spi_tx_done) begin
              spi_cs_n  <= 1'b1;
              state     <= ST_CMD;
              // re-assert CS# and resend new header
              spi_cs_n     <= 1'b0;
              spi_tx_data  <= 8'h0B;
              spi_tx_start <= 1'b1;

              // align base to current cur_baddr (already set to jump_baddr above)
              base_baddr   <= cur_baddr & ~24'h00001F; // optional alignment
              have_low     <= 1'b0;
              dummy_cnt    <= DUMMY_BYTES[3:0];
              abort_req    <= 1'b0;
            end
          end

          // If FIFO is full/almost full, we simply stop issuing new tx_start.
          // CS# can remain low; most flashes tolerate SCK pauses in FAST_READ.
        end

        default: state <= ST_IDLE;
      endcase
    end
  end
endmodule
