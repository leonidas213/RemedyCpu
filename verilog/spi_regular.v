module spi_memory_interface (
    input  wire        clk,           // System clock
    input  wire        spi_rst,       // Reset
    input  wire        st,            // Store (write) signal
    input  wire        ld,            // Load (read) signal
    input  wire [15:0] addr,          // 16-bit memory address
    input  wire [15:0] data_in,       // 16-bit data input (for write)
    output reg  [15:0] data_out,      // 16-bit data output (for read)
    input  wire        is_continous,  // Continuous transaction flag
    output reg         spi_cs,        // SPI Chip Select (Active Low)
    output reg         spi_clk,       // SPI Clock
    output reg         busy,          // Busy signal
    output reg         spi_mosi,      // SPI MOSI (Master Out Slave In)
    input  wire        spi_miso,      // SPI MISO (Master In Slave Out)
    output reg [4:0]   stateDeb
  );

  // Define FSM states

  localparam  IDLE = 4'b0000;
  localparam  START = 4'b0001;
  localparam  SEND_CMD = 4'b0010;
  localparam  SEND_ADDR = 4'b0011;
  localparam  WRITE_DATA = 4'b0100;
  localparam  READ_DUMMY = 4'b0101;
  localparam  READ_DATA = 4'b0110;
  localparam  STOP = 4'b0111;
  localparam  TOGGLECLKON = 4'b1000;
  localparam  TOGGLECLKOFF = 4'b1001;
  localparam  decideFate = 4'b1010;
  
  localparam  STcom = 1;
  localparam  LDcom = 0;


  reg[4:0] state = IDLE;
  reg[4:0] last_state = IDLE;
  reg [0:0] command = STcom;
  reg [0:0] firstRead = 1;

  reg [7:0] shift_reg; // Shift register for SPI data
  reg [5:0] bit_cnt;   // Bit counter
  reg [2:0] byte_cnt;  // Byte counter
  reg [15:0] recv_data;// Temporary storage for received data

  reg [0:0] prev_command;
  reg [15:0] prev_addr;
  reg prev_is_continous;

  always @(posedge clk or posedge spi_rst)
  begin

    if (spi_rst)
    begin
      state   <= IDLE;
      spi_cs  <= 1'b1;
      spi_clk <= 1'b0;
      spi_mosi <= 1'b0;
      busy    <= 1'b0;
      bit_cnt <= 3'b000;
      byte_cnt <= 3'b000;
    end
    else
    begin
      case (state)
        IDLE:
        begin
          busy <= 1'b0;
          if (st || ld)
          begin
            state <= START;
            busy <= 1'b1;

            prev_command <= command;
            prev_addr <= addr;
            prev_is_continous <= is_continous;

            if (st)
            begin
              shift_reg <= 8'h02; // Write command
              command <= STcom;
            end

            else if (ld)
            begin
              shift_reg <= 8'h03; // Read command
              command <= LDcom;
            end

          end
        end

        START:
        begin
          spi_cs <=1'b0;
          bit_cnt <= 3'b000;
          byte_cnt <= 3'b000;
          state <= SEND_CMD;
        end

        SEND_CMD:
        begin
          spi_clk <= 0;
          if (bit_cnt < 8)
          begin
            spi_mosi <= shift_reg[7];  // Send MSB first
            shift_reg <= shift_reg << 1; // Shift left
            last_state <= state;

            state <= TOGGLECLKON;
            bit_cnt <= bit_cnt + 1;
          end
          else
          begin
            state <= SEND_ADDR;
            shift_reg <= addr[15:8]; // Load high byte of address
            bit_cnt <= 0;
          end
        end

        SEND_ADDR:
        begin

          spi_clk <= 0;
          if (bit_cnt < 8)
          begin
            spi_mosi <= shift_reg[7];
            shift_reg <= shift_reg << 1;
            spi_clk <= 0;
            last_state <= state;
            state <= TOGGLECLKON;
            bit_cnt <= bit_cnt + 1;
          end
          else if (byte_cnt == 0)
          begin
            shift_reg <= addr[7:0]; // Load low byte of addresscc
            byte_cnt <= 1;
            bit_cnt <= 0;
          end
          else
          begin
            state <= command ? WRITE_DATA : READ_DATA;
            shift_reg <= command ? data_in[15:8] : 8'h00; // Load high data or dummy
            recv_data[15:0] <= 16'h0000; // Clear received data
            firstRead <= 1;
            bit_cnt <= 0;
            byte_cnt <= 0;
            spi_mosi <= 1'b0;
          end
        end

        WRITE_DATA:
        begin

          spi_clk <= 0;
          if (bit_cnt < 8)
          begin
            spi_mosi <= shift_reg[7];
            shift_reg <= shift_reg << 1;

            last_state <= state;
            state <= TOGGLECLKON;
            bit_cnt <= bit_cnt + 1;
          end
          else if (byte_cnt == 0)
          begin
            shift_reg <= data_in[7:0]; // Load low byte
            byte_cnt <= 1;
            bit_cnt <= 0;
          end
          else
          begin
            state <= decideFate; // Decide next state based on command
          end
        end

        READ_DATA:
        begin

          spi_clk <= 0;
          if (bit_cnt < 17)
          begin
            last_state<=state;

            if (bit_cnt<16)
              state <= TOGGLECLKON;
            bit_cnt <= bit_cnt + 1;
            recv_data[15:0] <= {recv_data[14:0], spi_miso}; // Shift left


          end
          else
          begin
            recv_data[15:0] <= {recv_data[14:0], spi_miso};
            data_out <= recv_data;
            state <= decideFate; // Decide next state based on command
            bit_cnt <= 0;
          end
        end


        STOP:
        begin

          spi_clk <= 0;
          spi_cs <= 1'b1;
          busy <= 1'b0;
          state <= IDLE;
        end

        TOGGLECLKON:
        begin
          spi_clk <= 1;
          state <= last_state;
        end

        decideFate:
        begin
          if (command == prev_command &&
              addr == prev_addr + 1 &&
              is_continous == prev_is_continous)
          begin
            // Continue without releasing CS
            shift_reg <= command ? data_in[15:8] : 8'h00;
            bit_cnt <= 0;
            byte_cnt <= 0;
            recv_data <= 0;
            spi_mosi <= 0;
            state <= command ? WRITE_DATA : READ_DATA;

            // Update previous address
            prev_addr <= addr;
          end
          else
          begin
            // End transaction
            state <= STOP;
          end
        end
      
      endcase
    end

    stateDeb <= state;
  end

endmodule
