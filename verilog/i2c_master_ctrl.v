module i2c_master_ctrl (
    input              clk,
    input              rst_n,

    input              wr_en,
    input      [3:0]   reg_addr,
    input      [15:0]  cpu_din,
    output reg [15:0]  cpu_dout,

    input              sda_in,
    output             sda_out,
    output             scl_out,
    output reg         sda_oe,
    output reg         scl_oe,

    output             interrupt
  );

  assign sda_out = 1'b0;
  assign scl_out = 1'b0;
  assign interrupt = irq_enable & irq_pending;


  localparam ST_IDLE       = 4'd0;
  localparam ST_START_1    = 4'd1;
  localparam ST_START_2    = 4'd2;
  localparam ST_START_3    = 4'd3;
  localparam ST_BIT_SETUP  = 4'd4;
  localparam ST_BIT_HIGH   = 4'd5;
  localparam ST_BIT_LOW    = 4'd6;
  localparam ST_ACK_SETUPW = 4'd7;
  localparam ST_ACK_HIGHW  = 4'd8;
  localparam ST_ACK_LOWW   = 4'd9;
  localparam ST_ACK_SETUPR = 4'd10;
  localparam ST_ACK_HIGHR  = 4'd11;
  localparam ST_ACK_LOWR   = 4'd12;
  localparam ST_STOP_1     = 4'd13;
  localparam ST_STOP_2     = 4'd14;
  localparam ST_STOP_3     = 4'd15;

  reg        enable;
  reg        irq_enable;

  reg        op_busy;
  reg        bus_active;
  reg        done;
  reg        ack_error;
  reg        rx_valid;
  reg        irq_pending;

  reg [15:0] prescale_reg;
  reg [15:0] divcnt;
  reg        sm_tick;

  reg [7:0]  tx_data_reg;
  reg [7:0]  rx_data_reg;

  reg [7:0]  tx_shift;
  reg [7:0]  rx_shift;
  reg [3:0]  bit_count;

  reg        cmd_start;
  reg        cmd_stop;
  reg        cmd_write;
  reg        cmd_read;
  reg        cmd_read_nack;

  reg [3:0]  state;

  wire launch_cmd;
  assign launch_cmd = wr_en && (reg_addr == 4'h4) && !op_busy && enable &&
         (cpu_din[0] || cpu_din[1] || cpu_din[2] || cpu_din[3]);

  always @(posedge clk or negedge rst_n)
  begin
    if (!rst_n)
    begin
      enable         <= 1'b0;
      irq_enable     <= 1'b0;

      op_busy        <= 1'b0;
      bus_active     <= 1'b0;
      done           <= 1'b0;
      ack_error      <= 1'b0;
      rx_valid       <= 1'b0;
      irq_pending    <= 1'b0;

      prescale_reg   <= 16'd0;
      divcnt         <= 16'd0;
      sm_tick        <= 1'b0;

      tx_data_reg    <= 8'd0;
      rx_data_reg    <= 8'd0;
      tx_shift       <= 8'd0;
      rx_shift       <= 8'd0;
      bit_count      <= 4'd0;

      cmd_start      <= 1'b0;
      cmd_stop       <= 1'b0;
      cmd_write      <= 1'b0;
      cmd_read       <= 1'b0;
      cmd_read_nack  <= 1'b0;

      state          <= ST_IDLE;

      sda_oe         <= 1'b0;
      scl_oe         <= 1'b0;
    end
    else
    begin
      sm_tick <= 1'b0;

      if (op_busy)
      begin
        if (prescale_reg == 16'd0)
        begin
          sm_tick <= 1'b1;
        end
        else
        begin
          if (divcnt == 16'd0)
          begin
            divcnt  <= prescale_reg;
            sm_tick <= 1'b1;
          end
          else
          begin
            divcnt <= divcnt - 16'd1;
          end
        end
      end
      else
      begin
        divcnt <= 16'd0;
      end

      if (wr_en)
      begin
        case (reg_addr)
          4'h0:
          begin
            enable     <= cpu_din[0];
            irq_enable <= cpu_din[1];
          end

          4'h1:
          begin
            if (cpu_din[2])
              done        <= 1'b0;
            if (cpu_din[3])
              ack_error   <= 1'b0;
            if (cpu_din[4])
              rx_valid    <= 1'b0;
            if (cpu_din[5])
              irq_pending <= 1'b0;
          end

          4'h2:
          begin
            prescale_reg <= cpu_din;
          end

          4'h3:
          begin
            tx_data_reg <= cpu_din[7:0];
          end
          default:
          begin
          end

        endcase
      end

      if (launch_cmd)
      begin
        cmd_start     <= cpu_din[0];
        cmd_stop      <= cpu_din[1];
        cmd_write     <= cpu_din[2];
        cmd_read      <= cpu_din[3];
        cmd_read_nack <= cpu_din[4];

        done        <= 1'b0;
        ack_error   <= 1'b0;
        irq_pending <= 1'b0;

        tx_shift    <= tx_data_reg;
        rx_shift    <= 8'd0;
        bit_count   <= 4'd7;
        op_busy     <= 1'b1;

        if (cpu_din[0])
        begin
          state  <= ST_START_1;
          sda_oe <= 1'b0;
          scl_oe <= 1'b0;
        end
        else if (cpu_din[2] || cpu_din[3])
        begin
          state  <= ST_BIT_SETUP;
          scl_oe <= 1'b1;
        end
        else if (cpu_din[1])
        begin
          state  <= ST_STOP_1;
          sda_oe <= 1'b1;
          scl_oe <= 1'b1;
        end
        else
        begin
          op_busy     <= 1'b0;
          done        <= 1'b1;
          irq_pending <= 1'b1;
          state       <= ST_IDLE;
        end
      end

      if (sm_tick && op_busy)
      begin
        case (state)
          ST_IDLE:
          begin
            op_busy <= 1'b0;
          end

          ST_START_1:
          begin
            sda_oe <= 1'b0;
            scl_oe <= 1'b0;
            if (sda_in)
            begin
              state <= ST_START_2;
            end
          end

          ST_START_2:
          begin
            sda_oe <= 1'b1; // SDA low while SCL high
            scl_oe <= 1'b0;
            state  <= ST_START_3;
          end

          ST_START_3:
          begin
            scl_oe     <= 1'b1; // pull SCL low
            bus_active <= 1'b1;

            if (cmd_write || cmd_read)
            begin
              state <= ST_BIT_SETUP;
            end
            else if (cmd_stop)
            begin
              state <= ST_STOP_1;
            end
            else
            begin
              done        <= 1'b1;
              irq_pending <= 1'b1;
              op_busy     <= 1'b0;
              state       <= ST_IDLE;
            end
          end

          ST_BIT_SETUP:
          begin
            scl_oe <= 1'b1; // keep clock low during setup

            if (cmd_write)
            begin
              if (tx_shift[bit_count])
                sda_oe <= 1'b0; // release for logic 1
              else
                sda_oe <= 1'b1; // drive low for logic 0
            end
            else
            begin
              sda_oe <= 1'b0; // read bit: release SDA
            end

            state <= ST_BIT_HIGH;
          end

          ST_BIT_HIGH:
          begin
            scl_oe <= 1'b0; // release SCL high

            if (cmd_read)
              rx_shift[bit_count] <= sda_in;

            state <= ST_BIT_LOW;
          end

          ST_BIT_LOW:
          begin
            scl_oe <= 1'b1; // drive SCL low again

            if (bit_count != 4'd0)
            begin
              bit_count <= bit_count - 4'd1;
              state     <= ST_BIT_SETUP;
            end
            else
            begin
              if (cmd_write)
                state <= ST_ACK_SETUPW;
              else
                state <= ST_ACK_SETUPR;
            end
          end

          ST_ACK_SETUPW:
          begin
            sda_oe <= 1'b0; // slave drives ACK/NACK
            scl_oe <= 1'b1;
            state  <= ST_ACK_HIGHW;
          end

          ST_ACK_HIGHW:
          begin
            scl_oe <= 1'b0;

            if (sda_in)
              ack_error <= 1'b1;

            state <= ST_ACK_LOWW;
          end

          ST_ACK_LOWW:
          begin
            scl_oe <= 1'b1;
            sda_oe <= 1'b0;

            if (cmd_stop)
            begin
              state <= ST_STOP_1;
            end
            else
            begin
              done        <= 1'b1;
              irq_pending <= 1'b1;
              op_busy     <= 1'b0;
              state       <= ST_IDLE;
            end
          end

          ST_ACK_SETUPR:
          begin
            scl_oe <= 1'b1;

            if (cmd_read_nack)
              sda_oe <= 1'b0; // NACK = release high
            else
              sda_oe <= 1'b1; // ACK = drive low

            state <= ST_ACK_HIGHR;
          end

          ST_ACK_HIGHR:
          begin
            scl_oe <= 1'b0;
            state  <= ST_ACK_LOWR;
          end

          ST_ACK_LOWR:
          begin
            scl_oe      <= 1'b1;
            sda_oe      <= 1'b0;
            rx_data_reg <= rx_shift;
            rx_valid    <= 1'b1;

            if (cmd_stop)
            begin
              state <= ST_STOP_1;
            end
            else
            begin
              done        <= 1'b1;
              irq_pending <= 1'b1;
              op_busy     <= 1'b0;
              state       <= ST_IDLE;
            end
          end

          ST_STOP_1:
          begin
            sda_oe <= 1'b1; // SDA low
            scl_oe <= 1'b1; // SCL low
            state  <= ST_STOP_2;
          end

          ST_STOP_2:
          begin
            sda_oe <= 1'b1; // keep SDA low
            scl_oe <= 1'b0; // release SCL high
            state  <= ST_STOP_3;
          end

          ST_STOP_3:
          begin
            sda_oe      <= 1'b0; // release SDA high
            scl_oe      <= 1'b0;
            bus_active  <= 1'b0;
            done        <= 1'b1;
            irq_pending <= 1'b1;
            op_busy     <= 1'b0;
            state       <= ST_IDLE;
          end

          default:
          begin
            sda_oe      <= 1'b0;
            scl_oe      <= 1'b0;
            bus_active  <= 1'b0;
            done        <= 1'b1;
            ack_error   <= 1'b1;
            irq_pending <= 1'b1;
            op_busy     <= 1'b0;
            state       <= ST_IDLE;
          end
        endcase
      end
    end
  end

  always @(*)
  begin
    cpu_dout = 16'd0;

    case (reg_addr)
      4'h0:
      begin
        cpu_dout[0] = enable;
        cpu_dout[1] = irq_enable;
        cpu_dout[2] = 1'b0; // clock stretching removed
      end

      4'h1:
      begin
        cpu_dout[0] = op_busy;
        cpu_dout[1] = bus_active;
        cpu_dout[2] = done;
        cpu_dout[3] = ack_error;
        cpu_dout[4] = rx_valid;
        cpu_dout[5] = irq_pending;
      end

      4'h2:
      begin
        cpu_dout = prescale_reg;
      end

      4'h3:
      begin
        cpu_dout[7:0] = rx_data_reg;
      end

      4'h4:
      begin
        cpu_dout[0] = cmd_start;
        cpu_dout[1] = cmd_stop;
        cpu_dout[2] = cmd_write;
        cpu_dout[3] = cmd_read;
        cpu_dout[4] = cmd_read_nack;
      end

      default:
      begin
        cpu_dout = 16'd0;
      end
    endcase
  end

endmodule
