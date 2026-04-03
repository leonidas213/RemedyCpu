module spi_memory_interface (
    input  wire        clk,
    input  wire        spi_rst,
    input  wire        st,
    input  wire        ld,
    input  wire [15:0] addr,
    input  wire [15:0] data_in,
    output reg  [15:0] data_out,
    input  wire        is_continous,
    output reg         spi_cs,
    output reg         spi_clk,
    output reg         busy,
    output reg         spi_mosi,
    input  wire        spi_miso
);

  localparam IDLE      = 4'd0;
  localparam START     = 4'd1;
  localparam SEND_CMD  = 4'd2;
  localparam SEND_ADDR = 4'd3;
  localparam WRITE_DATA= 4'd4;
  localparam READ_DATA = 4'd5;
  localparam CONT_WAIT = 4'd6;
  localparam STOP      = 4'd7;
  localparam CLK_HIGH  = 4'd8;

  localparam STcom = 1'b1;
  localparam LDcom = 1'b0;

  reg [3:0] state;
  reg [3:0] return_state;

  reg       command;
  reg       cont_en;
  reg [15:0] req_addr;
  reg [15:0] req_wdata;
  reg [15:0] next_cont_addr;

  reg [7:0]  shift_reg;
  reg [15:0] recv_data;
  reg [5:0]  bit_cnt;
  reg        byte_sel;

  always @(posedge clk or posedge spi_rst)
  begin
    if (spi_rst)
    begin
      state         <= IDLE;
      return_state  <= IDLE;
      command       <= LDcom;
      cont_en       <= 1'b0;
      req_addr      <= 16'h0000;
      req_wdata     <= 16'h0000;
      next_cont_addr<= 16'h0000;
      shift_reg     <= 8'h00;
      recv_data     <= 16'h0000;
      data_out      <= 16'h0000;
      bit_cnt       <= 6'd0;
      byte_sel      <= 1'b0;

      spi_cs        <= 1'b1;
      spi_clk       <= 1'b0;
      spi_mosi      <= 1'b0;
      busy          <= 1'b0;
    end
    else
    begin
      case (state)
        IDLE:
        begin
          spi_cs   <= 1'b1;
          spi_clk  <= 1'b0;
          spi_mosi <= 1'b0;
          busy     <= 1'b0;

          if (st || ld)
          begin
            command       <= st ? STcom : LDcom;
            cont_en       <= is_continous;
            req_addr      <= addr;
            req_wdata     <= data_in;
            shift_reg     <= st ? 8'h02 : 8'h03;
            recv_data     <= 16'h0000;
            bit_cnt       <= 6'd0;
            byte_sel      <= 1'b0;
            busy          <= 1'b1;
            state         <= START;
          end
        end

        START:
        begin
          spi_cs   <= 1'b0;
          spi_clk  <= 1'b0;
          bit_cnt  <= 6'd0;
          byte_sel <= 1'b0;
          state    <= SEND_CMD;
        end

        SEND_CMD:
        begin
          spi_clk <= 1'b0;
          if (bit_cnt < 6'd8)
          begin
            spi_mosi     <= shift_reg[7];
            shift_reg    <= {shift_reg[6:0], 1'b0};
            return_state <= SEND_CMD;
            bit_cnt      <= bit_cnt + 6'd1;
            state        <= CLK_HIGH;
          end
          else
          begin
            shift_reg <= req_addr[15:8];
            bit_cnt   <= 6'd0;
            byte_sel  <= 1'b0;
            state     <= SEND_ADDR;
          end
        end

        SEND_ADDR:
        begin
          spi_clk <= 1'b0;
          if (bit_cnt < 6'd8)
          begin
            spi_mosi     <= shift_reg[7];
            shift_reg    <= {shift_reg[6:0], 1'b0};
            return_state <= SEND_ADDR;
            bit_cnt      <= bit_cnt + 6'd1;
            state        <= CLK_HIGH;
          end
          else if (!byte_sel)
          begin
            shift_reg <= req_addr[7:0];
            bit_cnt   <= 6'd0;
            byte_sel  <= 1'b1;
          end
          else
          begin
            bit_cnt   <= 6'd0;
            byte_sel  <= 1'b0;
            recv_data <= 16'h0000;
            spi_mosi  <= 1'b0;

            if (command == STcom)
            begin
              shift_reg <= req_wdata[15:8];
              state     <= WRITE_DATA;
            end
            else
            begin
              state     <= READ_DATA;
            end
          end
        end

        WRITE_DATA:
        begin
          spi_clk <= 1'b0;
          if (bit_cnt < 6'd8)
          begin
            spi_mosi     <= shift_reg[7];
            shift_reg    <= {shift_reg[6:0], 1'b0};
            return_state <= WRITE_DATA;
            bit_cnt      <= bit_cnt + 6'd1;
            state        <= CLK_HIGH;
          end
          else if (!byte_sel)
          begin
            shift_reg <= req_wdata[7:0];
            bit_cnt   <= 6'd0;
            byte_sel  <= 1'b1;
          end
          else
          begin
            next_cont_addr <= req_addr + 16'h0001;
            if (cont_en)
              state <= CONT_WAIT;
            else
              state <= STOP;
          end
        end

        READ_DATA:
        begin
          spi_clk  <= 1'b0;
          spi_mosi <= 1'b0;

          if (bit_cnt < 6'd16)
          begin
            return_state <= READ_DATA;
            bit_cnt      <= bit_cnt + 6'd1;
            state        <= CLK_HIGH;
          end
          else
          begin
            data_out       <= recv_data;
            next_cont_addr <= req_addr + 16'h0001;
            if (cont_en)
              state <= CONT_WAIT;
            else
              state <= STOP;
          end
        end

        CONT_WAIT:
        begin
          // Current transfer is finished, but CS stays low so the next
          // sequential read can continue without resending command/address.
          spi_clk  <= 1'b0;
          spi_mosi <= 1'b0;
          busy     <= 1'b0;

          if (ld && !st && is_continous && (addr == next_cont_addr))
          begin
            command       <= LDcom;
            cont_en       <= is_continous;
            req_addr      <= addr;
            recv_data     <= 16'h0000;
            bit_cnt       <= 6'd0;
            byte_sel      <= 1'b0;
            busy          <= 1'b1;
            state         <= READ_DATA;
          end
          else if (st || ld)
          begin
            // A non-sequential request arrived. Close the old stream and start fresh.
            command       <= st ? STcom : LDcom;
            cont_en       <= is_continous;
            req_addr      <= addr;
            req_wdata     <= data_in;
            shift_reg     <= st ? 8'h02 : 8'h03;
            recv_data     <= 16'h0000;
            bit_cnt       <= 6'd0;
            byte_sel      <= 1'b0;
            spi_cs        <= 1'b1;
            busy          <= 1'b1;
            state         <= START;
          end
        end

        STOP:
        begin
          spi_clk <= 1'b0;
          spi_cs  <= 1'b1;
          busy    <= 1'b0;
          state   <= IDLE;
        end

        CLK_HIGH:
        begin
          spi_clk <= 1'b1;
          if (return_state == READ_DATA)
            recv_data <= {recv_data[14:0], spi_miso};
          state <= return_state;
        end

        default:
        begin
          state <= IDLE;
        end
      endcase
    end
  end

endmodule
