module pulse_on_rise(
    input  wire clk,
    input  wire rst,
    input  wire sig,
    output wire pulse
);
    reg sig_d;

    always @(posedge clk) begin
        if (rst)
            sig_d <= 1'b0;
        else
            sig_d <= sig;
    end

    assign pulse = sig & ~sig_d;
endmodule