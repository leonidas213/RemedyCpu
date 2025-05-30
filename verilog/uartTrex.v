module uart_tx(
    input wire clk,             // System clock
    input wire rst,             // Reset signal
    input wire tx_start,        // Start transmission signal
    input wire [7:0] tx_data,   // Data to be transmitted
    output reg tx,              // UART transmit pin
    output reg tx_done          // Transmission done signal
);

    // UART configuration parameters
    parameter CLK_FREQ = 50000000; // System clock frequency (50 MHz)
    parameter BAUD_RATE = 9600;    // Baud rate (9600 baud)
    
    // Calculate clock ticks per bit
    localparam TICKS_PER_BIT = CLK_FREQ / BAUD_RATE;

    // FSM states
    localparam IDLE    = 3'b000,
               START   = 3'b001,
               DATA    = 3'b010,
               STOP    = 3'b011,
               CLEANUP = 3'b100;

    reg [2:0] state, next_state;

    reg [7:0] tx_shift_reg;     // Shift register for data transmission
    reg [15:0] tick_counter;    // Counter for clock ticks
    reg [2:0] bit_counter;      // Counter for bits transmitted

    // FSM state transitions
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    // FSM next state logic
    always @* begin
        next_state = state;
        case (state)
            IDLE: begin
                if (tx_start) begin
                    next_state = START;
                end
            end
            START: begin
                if (tick_counter == TICKS_PER_BIT - 1) begin
                    next_state = DATA;
                end
            end
            DATA: begin
                if (tick_counter == TICKS_PER_BIT - 1) begin
                    if (bit_counter == 7) begin
                        next_state = STOP;
                    end
                end
            end
            STOP: begin
                if (tick_counter == TICKS_PER_BIT - 1) begin
                    next_state = CLEANUP;
                end
            end
            CLEANUP: begin
                next_state = IDLE;
            end
        endcase
    end

    // FSM output logic and counters
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            tx <= 1'b1;
            tx_done <= 1'b0;
            tick_counter <= 16'd0;
            bit_counter <= 3'd0;
            tx_shift_reg <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    tx <= 1'b1;
                    tx_done <= 1'b0;
                    tick_counter <= 16'd0;
                    bit_counter <= 3'd0;
                    if (tx_start) begin
                        tx_shift_reg <= tx_data;
                    end
                end
                START: begin
                    tx <= 1'b0;
                    if (tick_counter == TICKS_PER_BIT - 1) begin
                        tick_counter <= 16'd0;
                    end else begin
                        tick_counter <= tick_counter + 16'd1;
                    end
                end
                DATA: begin
                    tx <= tx_shift_reg[0];
                    if (tick_counter == TICKS_PER_BIT - 1) begin
                        tick_counter <= 16'd0;
                        bit_counter <= bit_counter + 3'd1;
                        tx_shift_reg <= tx_shift_reg >> 1;
                    end else begin
                        tick_counter <= tick_counter + 16'd1;
                    end
                end
                STOP: begin
                    tx <= 1'b1;
                    if (tick_counter == TICKS_PER_BIT - 1) begin
                        tick_counter <= 16'd0;
                        tx_done <= 1'b1;
                    end else begin
                        tick_counter <= tick_counter + 16'd1;
                    end
                end
                CLEANUP: begin
                    tx_done <= 1'b0;
                end
            endcase
        end
    end

endmodule
