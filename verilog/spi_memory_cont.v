module spi_memory_interface (
    input  wire        clk,            // System clock
    input  wire        spi_rst,        // Reset
    input  wire        st,             // Store (write) signal
    input  wire        ld,             // Load (read) signal
    input  wire [15:0] addr,           // 16-bit memory address
    input  wire [15:0] data_in,        // 16-bit data input (for write)
    output reg  [15:0] data_out,       // 16-bit data output (for read)
    input  wire        is_continous,   // Keep flash read stream open
    input  wire        stop_continous, // Close current continuous read stream
    output reg         spi_cs,         // SPI Chip Select (Active Low)
    output reg         spi_clk,        // SPI Clock
    output reg         busy,           // Busy signal
    output reg         spi_mosi,       // SPI MOSI (Master Out Slave In)
    input  wire        spi_miso        // SPI MISO (Master In Slave Out)
  );

  localparam IDLE        = 4'd0;
  localparam START       = 4'd1;
  localparam SEND_CMD    = 4'd2;
  localparam SEND_ADDR   = 4'd3;
  localparam WRITE_DATA  = 4'd4;
  localparam READ_DATA   = 4'd5;
  localparam WAIT_NEXT   = 4'd6;
  localparam STOP        = 4'd7;
  localparam TOGGLECLKON = 4'd8;

  localparam STcom = 1'b1;
  localparam LDcom = 1'b0;

  reg [3:0]  state;
  reg [3:0]  last_state;
  reg        command;
  reg [7:0]  shift_reg;
  reg [5:0]  bit_cnt;
  reg [2:0]  byte_cnt;
  reg [15:0] recv_data;

  reg [15:0] active_addr;
  reg [15:0] active_data_in;
  reg        active_is_continous;

  always @(posedge clk)
  begin
    if (spi_rst)
    begin
      state               <= IDLE;
      spi_cs              <= 1'b1;
      spi_clk             <= 1'b0;
      spi_mosi            <= 1'b0;
      busy                <= 1'b0;
      bit_cnt             <= 6'd0;
      byte_cnt            <= 3'd0;
      recv_data           <= 16'h0000;
      data_out            <= 16'h0000;
      command             <= LDcom;
      active_addr         <= 16'h0000;
      active_data_in      <= 16'h0000;
      active_is_continous <= 1'b0;
      last_state          <= IDLE;
    end
    else
    begin
      case (state)
        IDLE:
        begin
          busy    <= 1'b0;
          spi_cs  <= 1'b1;
          spi_clk <= 1'b0;

          if (st || ld)
          begin
            state               <= START;
            busy                <= 1'b1;
            active_addr         <= addr;
            active_data_in      <= data_in;
            active_is_continous <= is_continous;

            if (st)
            begin
              shift_reg <= 8'h02;
              command   <= STcom;
            end
            else
            begin
              shift_reg <= 8'h03;
              command   <= LDcom;
            end
          end
        end

        START:
        begin
          spi_cs   <= 1'b0;
          spi_clk  <= 1'b0;
          bit_cnt  <= 6'd0;
          byte_cnt <= 3'd0;
          state    <= SEND_CMD;
        end

        SEND_CMD:
        begin
          spi_clk <= 1'b0;
          if (bit_cnt < 8)
          begin
            spi_mosi   <= shift_reg[7];
            shift_reg  <= shift_reg << 1;
            last_state <= state;
            state      <= TOGGLECLKON;
            bit_cnt    <= bit_cnt + 1'b1;
          end
          else
          begin
            state     <= SEND_ADDR;
            shift_reg <= active_addr[15:8];
            bit_cnt   <= 6'd0;
          end
        end

        SEND_ADDR:
        begin
          spi_clk <= 1'b0;
          if (bit_cnt < 8)
          begin
            spi_mosi   <= shift_reg[7];
            shift_reg  <= shift_reg << 1;
            last_state <= state;
            state      <= TOGGLECLKON;
            bit_cnt    <= bit_cnt + 1'b1;
          end
          else if (byte_cnt == 0)
          begin
            shift_reg <= active_addr[7:0];
            byte_cnt  <= 3'd1;
            bit_cnt   <= 6'd0;
          end
          else
          begin
            state     <= command ? WRITE_DATA : READ_DATA;
            shift_reg <= command ? active_data_in[15:8] : 8'h00;
            recv_data <= 16'h0000;
            bit_cnt   <= 6'd0;
            byte_cnt  <= 3'd0;
            spi_mosi  <= 1'b0;
          end
        end

        WRITE_DATA:
        begin
          spi_clk <= 1'b0;
          if (bit_cnt < 8)
          begin
            spi_mosi   <= shift_reg[7];
            shift_reg  <= shift_reg << 1;
            last_state <= state;
            state      <= TOGGLECLKON;
            bit_cnt    <= bit_cnt + 1'b1;
          end
          else if (byte_cnt == 0)
          begin
            shift_reg <= active_data_in[7:0];
            byte_cnt  <= 3'd1;
            bit_cnt   <= 6'd0;
          end
          else
          begin
            state <= STOP;
          end
        end

        READ_DATA:
        begin
          spi_clk <= 1'b0;
          if (bit_cnt < 16)
          begin
            last_state <= state;
            state      <= TOGGLECLKON;
            bit_cnt    <= bit_cnt + 1'b1;
            recv_data  <= {recv_data[14:0], spi_miso};
          end
          else
          begin
            data_out <= {recv_data[14:0], spi_miso};
            bit_cnt  <= 6'd0;

            if (active_is_continous)
            begin
              active_addr <= active_addr + 16'd1; // next expected sequential address
              busy        <= 1'b0;
              state       <= WAIT_NEXT;
            end
            else
            begin
              state <= STOP;
            end
          end
        end

        WAIT_NEXT:
        begin
          spi_clk <= 1'b0;
          busy    <= 1'b0;

          if (stop_continous || st)
          begin
            state <= STOP;
          end
          else if (ld && is_continous && (addr == active_addr))
          begin
            active_addr         <= addr;
            active_data_in      <= data_in;
            active_is_continous <= is_continous;
            recv_data           <= 16'h0000;
            bit_cnt             <= 6'd0;
            byte_cnt            <= 3'd0;
            spi_mosi            <= 1'b0;
            busy                <= 1'b1;
            state               <= READ_DATA;
          end
          else if (ld && ((!is_continous) || (addr != active_addr)))
          begin
            state <= STOP;
          end
        end

        STOP:
        begin
          spi_clk <= 1'b0;
          spi_cs  <= 1'b1;
          busy    <= 1'b0;
          state   <= IDLE;
        end

        TOGGLECLKON:
        begin
          spi_clk <= 1'b1;
          state   <= last_state;
        end

        default:
        begin
          state <= IDLE;
        end
      endcase
    end
  end

endmodule
