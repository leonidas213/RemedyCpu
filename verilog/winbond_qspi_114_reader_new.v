module winbond_qspi_114_reader  (
    input  wire        clk,
    input  wire        rst,

    input  wire        start,
    input  wire [15:0] addr,      // CPU word address; flash byte address = addr << ADDR_SHIFT

    output reg  [15:0] data_out,
    output reg         busy,
    output reg         done,

    input  wire [3:0]  qspi_dq_i, // {IO3, IO2, IO1, IO0}
    output reg  [3:0]  qspi_dq_o,
    output reg  [3:0]  qspi_dq_oe,
    output reg         qspi_cs_n,
    output reg         qspi_clk
  );

  localparam integer CLK_DIV       = 2;
  localparam integer DUMMY_CYCLES  = 8;
  localparam integer ADDR_SHIFT    = 1;

  // Winbond Fast Read Quad Output (1-1-4)
  // Command/address on IO0, data returned on IO[3:0].
  localparam [7:0] CMD_FAST_READ_QUAD_OUT = 8'h6B;

  localparam [2:0] S_IDLE      = 3'd0;
  localparam [2:0] S_SEND_CMD  = 3'd1;
  localparam [2:0] S_SEND_ADDR = 3'd2;
  localparam [2:0] S_DUMMY     = 3'd3;
  localparam [2:0] S_READ      = 3'd4;
  localparam [2:0] S_FINISH    = 3'd5;

  reg [2:0]  state;
  reg [7:0]  cmd_shift;
  reg [23:0] addr_shift_reg;
  reg [15:0] recv_shift;
  reg [4:0]  bit_count;
  reg [3:0]  dummy_count;
  reg [2:0]  nibble_count;
  reg [15:0] div_count;

  wire tick;
  wire [23:0] flash_byte_addr;

  assign tick = (div_count == (CLK_DIV - 1));
  assign flash_byte_addr = {{8{1'b0}}, addr} << ADDR_SHIFT;

  always @(posedge clk)
  begin
    if (rst)
    begin
      state         <= S_IDLE;
      cmd_shift     <= 8'h00;
      addr_shift_reg<= 24'h000000;
      recv_shift    <= 16'h0000;
      bit_count     <= 5'd0;
      dummy_count   <= 4'd0;
      nibble_count  <= 3'd0;
      div_count     <= 16'd0;

      data_out      <= 16'h0000;
      busy          <= 1'b0;
      done          <= 1'b0;

      qspi_dq_o     <= 4'b0000;
      qspi_dq_oe    <= 4'b0000;
      qspi_cs_n     <= 1'b1;
      qspi_clk      <= 1'b0;
    end
    else
    begin
      done <= 1'b0;

      if (state == S_IDLE)
      begin
        div_count <= 16'd0;
      end
      else if (tick)
      begin
        div_count <= 16'd0;
      end
      else
      begin
        div_count <= div_count + 16'd1;
      end

      case (state)
        S_IDLE:
        begin
          busy       <= 1'b0;
          qspi_cs_n  <= 1'b1;
          qspi_clk   <= 1'b0;
          qspi_dq_oe <= 4'b0000;
          qspi_dq_o  <= 4'b0000;

          if (start)
          begin
            busy           <= 1'b1;
            qspi_cs_n      <= 1'b0;
            qspi_clk       <= 1'b0;
            qspi_dq_oe     <= 4'b0001; // drive IO0 only
            cmd_shift      <= CMD_FAST_READ_QUAD_OUT;
            addr_shift_reg <= flash_byte_addr;
            recv_shift     <= 16'h0000;
            bit_count      <= 5'd7;    // remaining bits after current MSB
            dummy_count    <= DUMMY_CYCLES[3:0];
            nibble_count   <= 3'd4;    // 16 bits / 4 bits per clock
            qspi_dq_o      <= {3'b000, CMD_FAST_READ_QUAD_OUT[7]};
            state          <= S_SEND_CMD;
          end
        end

        S_SEND_CMD:
        begin
          qspi_dq_oe <= 4'b0001;
          qspi_dq_o  <= {3'b000, cmd_shift[7]};

          if (tick)
          begin
            if (!qspi_clk)
            begin
              // Rising edge: flash samples IO0.
              qspi_clk <= 1'b1;
            end
            else
            begin
              // Falling edge: advance to next bit.
              qspi_clk  <= 1'b0;
              cmd_shift <= {cmd_shift[6:0], 1'b0};

              if (bit_count == 0)
              begin
                bit_count     <= 5'd23;
                qspi_dq_o     <= {3'b000, addr_shift_reg[23]};
                state         <= S_SEND_ADDR;
              end
              else
              begin
                bit_count <= bit_count - 5'd1;
              end
            end
          end
        end

        S_SEND_ADDR:
        begin
          qspi_dq_oe <= 4'b0001;
          qspi_dq_o  <= {3'b000, addr_shift_reg[23]};

          if (tick)
          begin
            if (!qspi_clk)
            begin
              qspi_clk <= 1'b1;
            end
            else
            begin
              qspi_clk       <= 1'b0;
              addr_shift_reg <= {addr_shift_reg[22:0], 1'b0};

              if (bit_count == 0)
              begin
                qspi_dq_oe <= 4'b0000;
                qspi_dq_o  <= 4'b0000;
                state      <= S_DUMMY;
              end
              else
              begin
                bit_count <= bit_count - 5'd1;
              end
            end
          end
        end

        S_DUMMY:
        begin
          qspi_dq_oe <= 4'b0000;
          qspi_dq_o  <= 4'b0000;

          if (tick)
          begin
            if (!qspi_clk)
            begin
              qspi_clk <= 1'b1;
            end
            else
            begin
              qspi_clk <= 1'b0;

              if (dummy_count == 0 || dummy_count == 1)
              begin
                state <= S_READ;
              end

              if (dummy_count != 0)
                dummy_count <= dummy_count - 4'd1;
            end
          end
        end

        S_READ:
        begin
          qspi_dq_oe <= 4'b0000;
          qspi_dq_o  <= 4'b0000;

          if (tick)
          begin
            if (!qspi_clk)
            begin
              // Rising edge: sample 4 return bits.
              qspi_clk   <= 1'b1;
              recv_shift <= {recv_shift[11:0], qspi_dq_i};

              if (nibble_count == 1)
              begin
                data_out <= {recv_shift[11:0], qspi_dq_i};
                state    <= S_FINISH;
              end

              if (nibble_count != 0)
                nibble_count <= nibble_count - 3'd1;
            end
            else
            begin
              qspi_clk <= 1'b0;
            end
          end
        end

        S_FINISH:
        begin
          qspi_clk   <= 1'b0;
          qspi_cs_n  <= 1'b1;
          qspi_dq_oe <= 4'b0000;
          qspi_dq_o  <= 4'b0000;
          busy       <= 1'b0;
          done       <= 1'b1;
          state      <= S_IDLE;
        end

        default:
        begin
          state <= S_IDLE;
        end
      endcase
    end
  end

endmodule
