module UART_Transmitter (
    input wire clk,
    input wire rst,
    input wire [7:0] data,
    input wire start,
    output reg tx=1,
    output reg tx_busy=0


  );

  parameter CLK_FREQ = 50000;  // System clock frequency
  parameter BAUD_RATE = 9600;  // Desired baud rate
  parameter BIT_PERIOD = 5;  // Clock cycles per bit period

  reg [9:0] shift_reg=0;
  reg [3:0] bit_count=0;
  reg [15:0] baud_counter=0;
  reg transmitting=0;
  always @(posedge clk or posedge rst)
  begin
    if (rst==1)
    begin
      tx <= 1'b1;  // Line idle state
      tx_busy <= 0;
      transmitting <= 0;
      shift_reg <= 8'b0;
      bit_count <= 0;
      baud_counter <= 0;
    end
    else
    begin

      if ( start && !tx_busy)
      begin
        tx_busy <= 1;
        transmitting <= 1;
        shift_reg <= {1'b1, data, 1'b0};  // Start bit, data, stop bit
        bit_count <= 0;
        baud_counter <= 0;
      end

      if (transmitting)
      begin
        if (baud_counter == BIT_PERIOD - 1)
        begin
          baud_counter <= 0;
          tx <= shift_reg[0];
          shift_reg <= {1'b1, shift_reg[9:1]};  // Shift right with stop bit
          bit_count <= bit_count + 1;

          if (bit_count == 9)
          begin  // 1 start bit + 8 data bits + 1 stop bit = 10 bits total
            transmitting <= 0;
            tx_busy <= 0;
          end
        end
        else
        begin
          baud_counter <= baud_counter + 1;
        end
      end
    end
  end

endmodule
