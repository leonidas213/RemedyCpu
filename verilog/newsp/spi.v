// spi_master_byte.v  (pure Verilog-2001)
// Mode 0 (CPOL=0, CPHA=0). Sends 1 byte and receives 1 byte.
// tx_start: 1-cycle strobe. tx_done/rx_valid: 1-cycle pulses.
// SCK = clk/(2*DIV). Use even DIV >= 2 initially.
module spi_master_byte

(
  input  wire clk,
  input  wire rst_n,

  input  wire       tx_start,
  input  wire [7:0] tx_byte,
  output reg        tx_busy,
  output reg        tx_done,

  output reg  [7:0] rx_byte,
  output reg        rx_valid,

  output reg        sck,
  output reg        mosi,
  input  wire       miso
);

  localparam DIV = 2;
  reg [7:0] sh_tx, sh_rx;
  reg [7:0] divc;
  reg [3:0] bitc;
  reg       phase; // toggles SCK

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      sck      <= 1'b0;
      mosi     <= 1'b0;
      tx_busy  <= 1'b0;
      tx_done  <= 1'b0;
      rx_byte  <= 8'h00;
      rx_valid <= 1'b0;
      sh_tx    <= 8'h00;
      sh_rx    <= 8'h00;
      divc     <= 8'd0;
      bitc     <= 4'd0;
      phase    <= 1'b0;
    end else begin
      tx_done  <= 1'b0;
      rx_valid <= 1'b0;

      if (tx_start && !tx_busy) begin
        tx_busy <= 1'b1;
        sh_tx   <= tx_byte;
        sh_rx   <= 8'h00;
        bitc    <= 4'd8;
        divc    <= 8'd0;
        phase   <= 1'b0;
        sck     <= 1'b0;
        mosi    <= tx_byte[7];
      end

      if (tx_busy) begin
        if (divc == (DIV-1)) begin
          divc  <= 8'd0;
          phase <= ~phase;
          sck   <= ~sck;

          if (phase == 1'b0) begin
            // rising: sample MISO
            sh_rx <= {sh_rx[6:0], miso};
          end else begin
            // falling: shift next bit out
            bitc  <= bitc - 1'b1;
            sh_tx <= {sh_tx[6:0], 1'b0};
            mosi  <= sh_tx[6];

            if (bitc == 4'd1) begin
              tx_busy  <= 1'b0;
              tx_done  <= 1'b1;
              rx_byte  <= {sh_rx[6:0], miso};
              rx_valid <= 1'b1;
              sck      <= 1'b0; // park low
            end
          end
        end else begin
          divc <= divc + 1'b1;
        end
      end
    end
  end
endmodule
