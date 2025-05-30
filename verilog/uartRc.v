module UART_Receiver (
    input wire clk,
    input wire rst,
    input wire rx,
    output reg [7:0] data_out,
    output reg rx_valid

  );

  parameter BAUD_RATE = 2;
  parameter CLK_FREQ = 10;  // 50 MHz clock
  parameter BIT_PERIOD = CLK_FREQ / BAUD_RATE;

  reg [15:0] sample_count=0;
  reg [3:0] bit_count=0;
  reg [7:0] rx_shift_reg=0;
  reg receiving=0;
  reg rx_d1=0, rx_d2=0;
  reg didStarted=0;

  assign sample_countdeb = sample_count;
  assign bit_countdeb = bit_count;
  assign rx_shift_regdeb = rx_shift_reg;
  assign receivingdeb = receiving;
  assign rx_d2deb = rx_d2;


  always @(posedge clk or posedge rst)
  begin
    if (rst==1)
    begin
      sample_count <= 0;
      bit_count <= 0;
      rx_shift_reg <= 0;
      receiving <= 0;
      rx_valid <= 0;
      rx_d2 <= 1;
      didStarted<=0;
    end
    else
    begin
      rx_d2 <= rx;
      if(rx_valid)
      begin
        rx_valid <= 0;
        didStarted<=0;
      end


      if(didStarted)

      begin
        if (!receiving)
        begin
          if (rx_d2 == 0)
          begin  // Detect start bit
            receiving <= 1;
            sample_count <= BIT_PERIOD / 2;  // Start sampling in the middle of the bit period
            bit_count <= 0;
          end
        end
        else
        begin
          if (sample_count == BIT_PERIOD - 1)
          begin
            sample_count <= 0;
            bit_count <= bit_count + 1;

            if (bit_count == 0)
            begin
              // Ignore the start bit
            end
            else if (bit_count < 9)
            begin
              // Receive data bits
              rx_shift_reg <= {rx_d2, rx_shift_reg[7:1]};
            end
            else
            begin
              // Stop bit, end of reception
              receiving <= 0;
              bit_count <= 0;
              data_out <= rx_shift_reg;
              rx_valid <= 1;
            end
          end
          else
          begin
            sample_count <= sample_count + 1;
          end
        end
      end

      else
        if(rx)
          didStarted<=1;

    end
  end

endmodule
