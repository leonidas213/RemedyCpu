module i2c_reg_master (
    input  [15:0] dOut,
    input  [15:0] Addr,
    input         ioW,
    input         ioR,
    input         C,
    input         rst,

    input         sda_in,

    input  [15:0] devAddrRegAddr,
    input  [15:0] regAddrRegAddr,
    input  [15:0] writeDataRegAddr,
    input  [15:0] cmdStatusRegAddr,
    input  [15:0] readDataRegAddr,
    input  [15:0] clkDivRegAddr,

    output [15:0] OutVal,
    output        irq,

    // open-drain control
    // 1 = release line
    // 0 = drive low
    output reg    scl_release,
    output reg    sda_release
  );

  reg [6:0]  dev_addr;
  reg [7:0]  reg_addr;
  reg [7:0]  write_data;
  reg [7:0]  read_data;
  reg [15:0] clk_div;

  reg        irq_en;
  reg        busy;
  reg        done;
  reg        ack_error;
  reg        op_read;

  reg [7:0]  shift_reg;
  reg [2:0]  bit_cnt;
  reg [2:0]  stage;
  reg        ack_ok;
  reg [15:0] div_cnt;

  reg [4:0]  state;

  wire wr_dev     = ioW && (Addr == devAddrRegAddr)   && !busy;
  wire wr_reg     = ioW && (Addr == regAddrRegAddr)   && !busy;
  wire wr_wdata   = ioW && (Addr == writeDataRegAddr) && !busy;
  wire wr_cmd     = ioW && (Addr == cmdStatusRegAddr);
  wire wr_clkdiv  = ioW && (Addr == clkDivRegAddr)    && !busy;

  wire rd_dev     =  (Addr == devAddrRegAddr)   && ioR;
  wire rd_reg     =  (Addr == regAddrRegAddr)   && ioR;
  wire rd_wdata   =  (Addr == writeDataRegAddr) && ioR;
  wire rd_status  =  (Addr == cmdStatusRegAddr) && ioR;
  wire rd_rdata   =  (Addr == readDataRegAddr)  && ioR;
  wire rd_clkdiv  =  (Addr == clkDivRegAddr)    && ioR;

  wire cmd_start_write = wr_cmd && dOut[0] && !busy;
  wire cmd_start_read  = wr_cmd && dOut[1] && !busy;
  wire cmd_clear_flags = wr_cmd && dOut[7];

  localparam ST_IDLE      = 5'd0;
  localparam ST_START_A   = 5'd1;
  localparam ST_START_B   = 5'd2;
  localparam ST_START_C   = 5'd3;
  localparam ST_TX_0      = 5'd4;
  localparam ST_TX_1      = 5'd5;
  localparam ST_TX_2      = 5'd6;
  localparam ST_TX_3      = 5'd7;
  localparam ST_ACK_0     = 5'd8;
  localparam ST_ACK_1     = 5'd9;
  localparam ST_ACK_2     = 5'd10;
  localparam ST_ACK_3     = 5'd11;
  localparam ST_RSTART_0  = 5'd12;
  localparam ST_RSTART_1  = 5'd13;
  localparam ST_RSTART_2  = 5'd14;
  localparam ST_RSTART_3  = 5'd15;
  localparam ST_RX_0      = 5'd16;
  localparam ST_RX_1      = 5'd17;
  localparam ST_RX_2      = 5'd18;
  localparam ST_RX_3      = 5'd19;
  localparam ST_MACK_0    = 5'd20;
  localparam ST_MACK_1    = 5'd21;
  localparam ST_MACK_2    = 5'd22;
  localparam ST_MACK_3    = 5'd23;
  localparam ST_STOP_A    = 5'd24;
  localparam ST_STOP_B    = 5'd25;
  localparam ST_STOP_C    = 5'd26;

  assign irq = irq_en && (done || ack_error);

  assign OutVal =
         rd_dev    ? {9'b0, dev_addr} :
         rd_reg    ? {8'b0, reg_addr} :
         rd_wdata  ? {8'b0, write_data} :
         rd_status ? {7'b0, irq_en, 5'b0, ack_error, done, busy} :
         rd_rdata  ? {8'b0, read_data} :
         rd_clkdiv ? clk_div :
         16'h0000;

  always @(posedge C)
  begin
    if (rst)
    begin
      dev_addr    <= 7'h00;
      reg_addr    <= 8'h00;
      write_data  <= 8'h00;
      read_data   <= 8'h00;
      clk_div     <= 16'd124; // ~100kHz at 50MHz with this FSM pacing
      irq_en      <= 1'b0;
      busy        <= 1'b0;
      done        <= 1'b0;
      ack_error   <= 1'b0;
      op_read     <= 1'b0;
      shift_reg   <= 8'h00;
      bit_cnt     <= 3'd0;
      stage       <= 3'd0;
      ack_ok      <= 1'b0;
      div_cnt     <= 16'd0;
      state       <= ST_IDLE;
      scl_release <= 1'b1;
      sda_release <= 1'b1;
    end
    else
    begin
      if (wr_dev)
        dev_addr <= dOut[6:0];

      if (wr_reg)
        reg_addr <= dOut[7:0];

      if (wr_wdata)
        write_data <= dOut[7:0];

      if (wr_clkdiv)
        clk_div <= dOut;

      if (wr_cmd)
        irq_en <= dOut[8];

      if (cmd_clear_flags)
      begin
        done      <= 1'b0;
        ack_error <= 1'b0;
      end

      if (cmd_start_write)
      begin
        busy        <= 1'b1;
        done        <= 1'b0;
        ack_error   <= 1'b0;
        op_read     <= 1'b0;
        stage       <= 3'd0;
        state       <= ST_START_A;
        div_cnt     <= clk_div;
        scl_release <= 1'b1;
        sda_release <= 1'b1;
      end
      else if (cmd_start_read)
      begin
        busy        <= 1'b1;
        done        <= 1'b0;
        ack_error   <= 1'b0;
        op_read     <= 1'b1;
        stage       <= 3'd0;
        state       <= ST_START_A;
        div_cnt     <= clk_div;
        scl_release <= 1'b1;
        sda_release <= 1'b1;
      end
      else if (busy)
      begin
        if (div_cnt != 16'd0)
        begin
          div_cnt <= div_cnt - 16'd1;
        end
        else
        begin
          div_cnt <= clk_div;

          case (state)
            ST_START_A:
            begin
              scl_release <= 1'b1;
              sda_release <= 1'b1;
              state <= ST_START_B;
            end

            ST_START_B:
            begin
              scl_release <= 1'b1;
              sda_release <= 1'b0;
              state <= ST_START_C;
            end

            ST_START_C:
            begin
              scl_release <= 1'b0;
              sda_release <= 1'b0;
              shift_reg <= {dev_addr, 1'b0};
              bit_cnt <= 3'd7;
              state <= ST_TX_0;
            end

            ST_TX_0:
            begin
              sda_release <= shift_reg[7];
              state <= ST_TX_1;
            end

            ST_TX_1:
            begin
              scl_release <= 1'b1;
              state <= ST_TX_2;
            end

            ST_TX_2:
            begin
              state <= ST_TX_3;
            end

            ST_TX_3:
            begin
              scl_release <= 1'b0;
              if (bit_cnt == 3'd0)
              begin
                sda_release <= 1'b1;
                state <= ST_ACK_0;
              end
              else
              begin
                shift_reg <= {shift_reg[6:0], 1'b0};
                bit_cnt <= bit_cnt - 3'd1;
                state <= ST_TX_0;
              end
            end

            ST_ACK_0:
            begin
              sda_release <= 1'b1;
              state <= ST_ACK_1;
            end

            ST_ACK_1:
            begin
              scl_release <= 1'b1;
              state <= ST_ACK_2;
            end

            ST_ACK_2:
            begin
              ack_ok <= ~sda_in;
              state <= ST_ACK_3;
            end

            ST_ACK_3:
            begin
              scl_release <= 1'b0;

              if (!ack_ok)
              begin
                ack_error <= 1'b1;
                state <= ST_STOP_A;
              end
              else
              begin
                case (stage)
                  3'd0:
                  begin
                    stage <= 3'd1;
                    shift_reg <= reg_addr;
                    bit_cnt <= 3'd7;
                    state <= ST_TX_0;
                  end

                  3'd1:
                  begin
                    if (op_read)
                    begin
                      state <= ST_RSTART_0;
                    end
                    else
                    begin
                      stage <= 3'd2;
                      shift_reg <= write_data;
                      bit_cnt <= 3'd7;
                      state <= ST_TX_0;
                    end
                  end

                  3'd2:
                  begin
                    state <= ST_STOP_A;
                  end

                  3'd3:
                  begin
                    stage <= 3'd4;
                    shift_reg <= 8'h00;
                    bit_cnt <= 3'd7;
                    state <= ST_RX_0;
                  end

                  default:
                  begin
                    state <= ST_STOP_A;
                  end
                endcase
              end
            end

            ST_RSTART_0:
            begin
              scl_release <= 1'b0;
              sda_release <= 1'b1;
              state <= ST_RSTART_1;
            end

            ST_RSTART_1:
            begin
              scl_release <= 1'b1;
              sda_release <= 1'b1;
              state <= ST_RSTART_2;
            end

            ST_RSTART_2:
            begin
              scl_release <= 1'b1;
              sda_release <= 1'b0;
              state <= ST_RSTART_3;
            end

            ST_RSTART_3:
            begin
              scl_release <= 1'b0;
              sda_release <= 1'b0;
              stage <= 3'd3;
              shift_reg <= {dev_addr, 1'b1};
              bit_cnt <= 3'd7;
              state <= ST_TX_0;
            end

            ST_RX_0:
            begin
              sda_release <= 1'b1;
              state <= ST_RX_1;
            end

            ST_RX_1:
            begin
              scl_release <= 1'b1;
              state <= ST_RX_2;
            end

            ST_RX_2:
            begin
              shift_reg <= {shift_reg[6:0], sda_in};
              state <= ST_RX_3;
            end

            ST_RX_3:
            begin
              scl_release <= 1'b0;
              if (bit_cnt == 3'd0)
              begin
                read_data <= {shift_reg[6:0], sda_in};
                state <= ST_MACK_0;
              end
              else
              begin
                bit_cnt <= bit_cnt - 3'd1;
                state <= ST_RX_0;
              end
            end

            ST_MACK_0:
            begin
              // single-byte read -> NACK
              sda_release <= 1'b1;
              state <= ST_MACK_1;
            end

            ST_MACK_1:
            begin
              scl_release <= 1'b1;
              state <= ST_MACK_2;
            end

            ST_MACK_2:
            begin
              state <= ST_MACK_3;
            end

            ST_MACK_3:
            begin
              scl_release <= 1'b0;
              state <= ST_STOP_A;
            end

            ST_STOP_A:
            begin
              scl_release <= 1'b0;
              sda_release <= 1'b0;
              state <= ST_STOP_B;
            end

            ST_STOP_B:
            begin
              scl_release <= 1'b1;
              sda_release <= 1'b0;
              state <= ST_STOP_C;
            end

            ST_STOP_C:
            begin
              scl_release <= 1'b1;
              sda_release <= 1'b1;
              busy <= 1'b0;
              done <= 1'b1;
              state <= ST_IDLE;
            end

            default:
            begin
              busy        <= 1'b0;
              done        <= 1'b0;
              ack_error   <= 1'b0;
              state       <= ST_IDLE;
              scl_release <= 1'b1;
              sda_release <= 1'b1;
            end
          endcase
        end
      end
    end
  end

endmodule
