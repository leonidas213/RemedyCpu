module baud_tick_generator (
    input wire clk,
    input wire rst,
    input wire [15:0] clock_div,  // e.g. 868 for 115200 baud @ 100MHz
    output reg tick
);

    reg [15:0] counter = 0;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            counter <= 0;
            tick <= 0;
        end else begin
            if (counter >= clock_div) begin
                counter <= 0;
                tick <= 1;
            end else begin
                counter <= counter + 1;
                tick <= 0;
            end
        end
    end
endmodule
