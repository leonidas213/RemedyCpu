module single_port_bram_16bit (
    input wire clk,
    input wire we_1,
    input wire rld_1,
    input wire [15:0] addr_1,
    input wire [15:0] din_1,
    input wire we_2,
    input wire rld_2,
    input wire [15:0] addr_2,
    input wire [15:0] din_2,
    output reg [15:0] dout_1,
    output reg [15:0] dout_2
  );

  (* ram_style = "block" *) reg [15:0] mem [0:(1 << 16)-1];

  always @(posedge clk , posedge rld_1)
  begin
    if (we_1)
      mem[addr_1] <= din_1;
    dout_1 <= mem[addr_1];
  end

  always @(negedge clk, negedge rld_1 )
  begin
    dout_1 <= mem[addr_1];
  end

  always @(posedge clk , posedge rld_2)
  begin
    if (we_2)
      mem[addr_2] <= din_2;
    dout_2 <= mem[addr_2];
  end

  always @(negedge clk, negedge rld_2 )
  begin
    dout_2 <= mem[addr_2];
  end
endmodule
