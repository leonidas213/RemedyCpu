module Fifo16
  (input  clk,
   input  [15:0] data,
   input  rst,
   input  writeEn,
   input  readEn,
   output FIFOEmpty,
   output FIFOFull,
   output [4:0] FIFOCount,
   output [15:0] readData);
  wire [271:0] fifobuffer;
  reg [4:0] fifocounter;
  reg isempty;
  reg isfull;
  wire [255:0] n26_o;
  wire [255:0] n27_o;
  wire [255:0] n28_o;
  wire [4:0] n30_o;
  wire n32_o;
  wire n34_o;
  wire n36_o;
  wire n37_o;
  wire [4:0] n40_o;
  wire [15:0] n42_o;
  wire [271:0] n43_o;
  wire [4:0] n46_o;
  wire n48_o;
  wire n50_o;
  wire [15:0] n51_o;
  wire [271:0] n52_o;
  wire [4:0] n54_o;
  wire n56_o;
  wire n57_o;
  wire n59_o;
  wire n60_o;
  wire [15:0] n61_o;
  wire [15:0] n62_o;
  wire [15:0] n63_o;
  wire [15:0] n64_o;
  wire [15:0] n65_o;
  wire [15:0] n66_o;
  wire [15:0] n67_o;
  wire [15:0] n68_o;
  wire [15:0] n69_o;
  wire [15:0] n70_o;
  wire [15:0] n71_o;
  wire [15:0] n72_o;
  wire [15:0] n73_o;
  wire [15:0] n74_o;
  wire [15:0] n75_o;
  wire [15:0] n76_o;
  wire [15:0] n77_o;
  wire [4:0] n79_o;
  wire n81_o;
  wire n83_o;
  wire [255:0] n85_o;
  wire [255:0] n86_o;
  wire [255:0] n87_o;
  wire [255:0] n88_o;
  wire [255:0] n89_o;
  wire [15:0] n90_o;
  wire [15:0] n91_o;
  wire [15:0] n92_o;
  wire [4:0] n93_o;
  wire n94_o;
  wire n96_o;
  wire [271:0] n98_o;
  reg [271:0] n104_q;
  reg [4:0] n105_q;
  reg n106_q;
  reg n107_q;
  wire [15:0] n108_o;
  reg [15:0] n109_q;
  wire n110_o;
  wire n111_o;
  wire n112_o;
  wire n113_o;
  wire n114_o;
  wire n115_o;
  wire n116_o;
  wire n117_o;
  wire n118_o;
  wire n119_o;
  wire n120_o;
  wire n121_o;
  wire n122_o;
  wire n123_o;
  wire n124_o;
  wire n125_o;
  wire n126_o;
  wire n127_o;
  wire n128_o;
  wire n129_o;
  wire n130_o;
  wire n131_o;
  wire n132_o;
  wire n133_o;
  wire n134_o;
  wire n135_o;
  wire n136_o;
  wire n137_o;
  wire n138_o;
  wire n139_o;
  wire n140_o;
  wire n141_o;
  wire n142_o;
  wire n143_o;
  wire n144_o;
  wire n145_o;
  wire n146_o;
  wire n147_o;
  wire n148_o;
  wire n149_o;
  wire n150_o;
  wire n151_o;
  wire n152_o;
  wire n153_o;
  wire [15:0] n154_o;
  wire [15:0] n155_o;
  wire [15:0] n156_o;
  wire [15:0] n157_o;
  wire [15:0] n158_o;
  wire [15:0] n159_o;
  wire [15:0] n160_o;
  wire [15:0] n161_o;
  wire [15:0] n162_o;
  wire [15:0] n163_o;
  wire [15:0] n164_o;
  wire [15:0] n165_o;
  wire [15:0] n166_o;
  wire [15:0] n167_o;
  wire [15:0] n168_o;
  wire [15:0] n169_o;
  wire [15:0] n170_o;
  wire [15:0] n171_o;
  wire [15:0] n172_o;
  wire [15:0] n173_o;
  wire [15:0] n174_o;
  wire [15:0] n175_o;
  wire [15:0] n176_o;
  wire [15:0] n177_o;
  wire [15:0] n178_o;
  wire [15:0] n179_o;
  wire [15:0] n180_o;
  wire [15:0] n181_o;
  wire [15:0] n182_o;
  wire [15:0] n183_o;
  wire [15:0] n184_o;
  wire [15:0] n185_o;
  wire [15:0] n186_o;
  wire [15:0] n187_o;
  wire [271:0] n188_o;
  assign FIFOEmpty = isempty;
  assign FIFOFull = isfull;
  assign FIFOCount = fifocounter;
  assign readData = n109_q;
  /* fifo.vhdl:30:10  */
  assign fifobuffer = n104_q; // (signal)
  /* fifo.vhdl:32:10  */
  always @*
    fifocounter = n105_q; // (isignal)
  initial
    fifocounter = 5'b00000;
  /* fifo.vhdl:34:10  */
  always @*
    isempty = n106_q; // (isignal)
  initial
    isempty = 1'b1;
  /* fifo.vhdl:35:10  */
  always @*
    isfull = n107_q; // (isignal)
  initial
    isfull = 1'b0;
  assign n26_o = {16'b0000000000000000, 16'b0000000000000000, 16'b0000000000000000, 16'b0000000000000000, 16'b0000000000000000, 16'b0000000000000000, 16'b0000000000000000, 16'b0000000000000000, 16'b0000000000000000, 16'b0000000000000000, 16'b0000000000000000, 16'b0000000000000000, 16'b0000000000000000, 16'b0000000000000000, 16'b0000000000000000, 16'b0000000000000000};
  assign n27_o = fifobuffer[271:16];
  /* fifo.vhdl:46:7  */
  assign n28_o = rst ? n26_o : n27_o;
  /* fifo.vhdl:46:7  */
  assign n30_o = rst ? 5'b00000 : fifocounter;
  /* fifo.vhdl:46:7  */
  assign n32_o = rst ? 1'b1 : isempty;
  /* fifo.vhdl:46:7  */
  assign n34_o = rst ? 1'b0 : isfull;
  /* fifo.vhdl:57:44  */
  assign n36_o = fifocounter != 5'b10000;
  /* fifo.vhdl:57:27  */
  assign n37_o = writeEn & n36_o;
  /* fifo.vhdl:59:20  */
  assign n40_o = 5'b10000 - fifocounter;
  assign n42_o = fifobuffer[15:0];
  assign n43_o = {n28_o, n42_o};
  /* fifo.vhdl:61:36  */
  assign n46_o = fifocounter + 5'b00001;
  /* fifo.vhdl:64:25  */
  assign n48_o = fifocounter == 5'b01111;
  /* fifo.vhdl:57:7  */
  assign n50_o = n57_o ? 1'b1 : n34_o;
  assign n51_o = fifobuffer[15:0];
  assign n52_o = {n28_o, n51_o};
  /* fifo.vhdl:57:7  */
  assign n54_o = n37_o ? n46_o : n30_o;
  /* fifo.vhdl:57:7  */
  assign n56_o = n37_o ? 1'b0 : n32_o;
  /* fifo.vhdl:57:7  */
  assign n57_o = n37_o & n48_o;
  /* fifo.vhdl:69:43  */
  assign n59_o = $unsigned(fifocounter) > $unsigned(5'b00000);
  /* fifo.vhdl:69:26  */
  assign n60_o = readEn & n59_o;
  /* fifo.vhdl:71:31  */
  assign n61_o = fifobuffer[271:256];
  /* fifo.vhdl:75:38  */
  assign n62_o = fifobuffer[255:240];
  /* fifo.vhdl:75:38  */
  assign n63_o = fifobuffer[239:224];
  /* fifo.vhdl:75:38  */
  assign n64_o = fifobuffer[223:208];
  /* fifo.vhdl:75:38  */
  assign n65_o = fifobuffer[207:192];
  /* fifo.vhdl:75:38  */
  assign n66_o = fifobuffer[191:176];
  /* fifo.vhdl:75:38  */
  assign n67_o = fifobuffer[175:160];
  /* fifo.vhdl:75:38  */
  assign n68_o = fifobuffer[159:144];
  /* fifo.vhdl:75:38  */
  assign n69_o = fifobuffer[143:128];
  /* fifo.vhdl:75:38  */
  assign n70_o = fifobuffer[127:112];
  /* fifo.vhdl:75:38  */
  assign n71_o = fifobuffer[111:96];
  /* fifo.vhdl:75:38  */
  assign n72_o = fifobuffer[95:80];
  /* fifo.vhdl:75:38  */
  assign n73_o = fifobuffer[79:64];
  /* fifo.vhdl:75:38  */
  assign n74_o = fifobuffer[63:48];
  /* fifo.vhdl:75:38  */
  assign n75_o = fifobuffer[47:32];
  /* fifo.vhdl:75:38  */
  assign n76_o = fifobuffer[31:16];
  /* fifo.vhdl:75:38  */
  assign n77_o = fifobuffer[15:0];
  /* fifo.vhdl:78:36  */
  assign n79_o = fifocounter - 5'b00001;
  /* fifo.vhdl:79:25  */
  assign n81_o = fifocounter == 5'b00001;
  /* fifo.vhdl:69:7  */
  assign n83_o = n94_o ? 1'b1 : n56_o;
  assign n85_o = {n62_o, n63_o, n64_o, n65_o, n66_o, n67_o, n68_o, n69_o, n70_o, n71_o, n72_o, n73_o, n74_o, n75_o, n76_o, n77_o};
  assign n86_o = n188_o[271:16];
  assign n87_o = n52_o[271:16];
  /* fifo.vhdl:57:7  */
  assign n88_o = n37_o ? n86_o : n87_o;
  /* fifo.vhdl:69:7  */
  assign n89_o = n60_o ? n85_o : n88_o;
  assign n90_o = n188_o[15:0];
  assign n91_o = n52_o[15:0];
  /* fifo.vhdl:57:7  */
  assign n92_o = n37_o ? n90_o : n91_o;
  /* fifo.vhdl:69:7  */
  assign n93_o = n60_o ? n79_o : n54_o;
  /* fifo.vhdl:69:7  */
  assign n94_o = n60_o & n81_o;
  /* fifo.vhdl:69:7  */
  assign n96_o = n60_o ? 1'b0 : n50_o;
  assign n98_o = {n89_o, n92_o};
  /* fifo.vhdl:45:5  */
  always @(posedge clk)
    n104_q <= n98_o;
  /* fifo.vhdl:45:5  */
  always @(posedge clk)
    n105_q <= n93_o;
  initial
    n105_q = 5'b00000;
  /* fifo.vhdl:45:5  */
  always @(posedge clk)
    n106_q <= n83_o;
  initial
    n106_q = 1'b1;
  /* fifo.vhdl:45:5  */
  always @(posedge clk)
    n107_q <= n96_o;
  initial
    n107_q = 1'b0;
  /* fifo.vhdl:45:5  */
  assign n108_o = n60_o ? n61_o : n109_q;
  /* fifo.vhdl:45:5  */
  always @(posedge clk)
    n109_q <= n108_o;
  /* fifo.vhdl:59:9  */
  assign n110_o = n40_o[4];
  /* fifo.vhdl:59:9  */
  assign n111_o = ~n110_o;
  /* fifo.vhdl:59:9  */
  assign n112_o = n40_o[3];
  /* fifo.vhdl:59:9  */
  assign n113_o = ~n112_o;
  /* fifo.vhdl:59:9  */
  assign n114_o = n111_o & n113_o;
  /* fifo.vhdl:59:9  */
  assign n115_o = n111_o & n112_o;
  /* fifo.vhdl:59:9  */
  assign n116_o = n110_o & n113_o;
  /* fifo.vhdl:59:9  */
  assign n117_o = n40_o[2];
  /* fifo.vhdl:59:9  */
  assign n118_o = ~n117_o;
  /* fifo.vhdl:59:9  */
  assign n119_o = n114_o & n118_o;
  /* fifo.vhdl:59:9  */
  assign n120_o = n114_o & n117_o;
  /* fifo.vhdl:59:9  */
  assign n121_o = n115_o & n118_o;
  /* fifo.vhdl:59:9  */
  assign n122_o = n115_o & n117_o;
  /* fifo.vhdl:59:9  */
  assign n123_o = n116_o & n118_o;
  /* fifo.vhdl:59:9  */
  assign n124_o = n40_o[1];
  /* fifo.vhdl:59:9  */
  assign n125_o = ~n124_o;
  /* fifo.vhdl:59:9  */
  assign n126_o = n119_o & n125_o;
  /* fifo.vhdl:59:9  */
  assign n127_o = n119_o & n124_o;
  /* fifo.vhdl:59:9  */
  assign n128_o = n120_o & n125_o;
  /* fifo.vhdl:59:9  */
  assign n129_o = n120_o & n124_o;
  /* fifo.vhdl:59:9  */
  assign n130_o = n121_o & n125_o;
  /* fifo.vhdl:59:9  */
  assign n131_o = n121_o & n124_o;
  /* fifo.vhdl:59:9  */
  assign n132_o = n122_o & n125_o;
  /* fifo.vhdl:59:9  */
  assign n133_o = n122_o & n124_o;
  /* fifo.vhdl:59:9  */
  assign n134_o = n123_o & n125_o;
  /* fifo.vhdl:59:9  */
  assign n135_o = n40_o[0];
  /* fifo.vhdl:59:9  */
  assign n136_o = ~n135_o;
  /* fifo.vhdl:59:9  */
  assign n137_o = n126_o & n136_o;
  /* fifo.vhdl:59:9  */
  assign n138_o = n126_o & n135_o;
  /* fifo.vhdl:59:9  */
  assign n139_o = n127_o & n136_o;
  /* fifo.vhdl:59:9  */
  assign n140_o = n127_o & n135_o;
  /* fifo.vhdl:59:9  */
  assign n141_o = n128_o & n136_o;
  /* fifo.vhdl:59:9  */
  assign n142_o = n128_o & n135_o;
  /* fifo.vhdl:59:9  */
  assign n143_o = n129_o & n136_o;
  /* fifo.vhdl:59:9  */
  assign n144_o = n129_o & n135_o;
  /* fifo.vhdl:59:9  */
  assign n145_o = n130_o & n136_o;
  /* fifo.vhdl:59:9  */
  assign n146_o = n130_o & n135_o;
  /* fifo.vhdl:59:9  */
  assign n147_o = n131_o & n136_o;
  /* fifo.vhdl:59:9  */
  assign n148_o = n131_o & n135_o;
  /* fifo.vhdl:59:9  */
  assign n149_o = n132_o & n136_o;
  /* fifo.vhdl:59:9  */
  assign n150_o = n132_o & n135_o;
  /* fifo.vhdl:59:9  */
  assign n151_o = n133_o & n136_o;
  /* fifo.vhdl:59:9  */
  assign n152_o = n133_o & n135_o;
  /* fifo.vhdl:59:9  */
  assign n153_o = n134_o & n136_o;
  assign n154_o = n43_o[15:0];
  /* fifo.vhdl:59:9  */
  assign n155_o = n137_o ? data : n154_o;
  assign n156_o = n43_o[31:16];
  /* fifo.vhdl:59:9  */
  assign n157_o = n138_o ? data : n156_o;
  assign n158_o = n43_o[47:32];
  /* fifo.vhdl:59:9  */
  assign n159_o = n139_o ? data : n158_o;
  assign n160_o = n43_o[63:48];
  /* fifo.vhdl:59:9  */
  assign n161_o = n140_o ? data : n160_o;
  assign n162_o = n43_o[79:64];
  /* fifo.vhdl:59:9  */
  assign n163_o = n141_o ? data : n162_o;
  assign n164_o = n43_o[95:80];
  /* fifo.vhdl:59:9  */
  assign n165_o = n142_o ? data : n164_o;
  assign n166_o = n43_o[111:96];
  /* fifo.vhdl:59:9  */
  assign n167_o = n143_o ? data : n166_o;
  assign n168_o = n43_o[127:112];
  /* fifo.vhdl:59:9  */
  assign n169_o = n144_o ? data : n168_o;
  assign n170_o = n43_o[143:128];
  /* fifo.vhdl:59:9  */
  assign n171_o = n145_o ? data : n170_o;
  assign n172_o = n43_o[159:144];
  /* fifo.vhdl:59:9  */
  assign n173_o = n146_o ? data : n172_o;
  assign n174_o = n43_o[175:160];
  /* fifo.vhdl:59:9  */
  assign n175_o = n147_o ? data : n174_o;
  assign n176_o = n43_o[191:176];
  /* fifo.vhdl:59:9  */
  assign n177_o = n148_o ? data : n176_o;
  assign n178_o = n43_o[207:192];
  /* fifo.vhdl:59:9  */
  assign n179_o = n149_o ? data : n178_o;
  assign n180_o = n43_o[223:208];
  /* fifo.vhdl:59:9  */
  assign n181_o = n150_o ? data : n180_o;
  assign n182_o = n43_o[239:224];
  /* fifo.vhdl:59:9  */
  assign n183_o = n151_o ? data : n182_o;
  assign n184_o = n43_o[255:240];
  /* fifo.vhdl:59:9  */
  assign n185_o = n152_o ? data : n184_o;
  assign n186_o = n43_o[271:256];
  /* fifo.vhdl:59:9  */
  assign n187_o = n153_o ? data : n186_o;
  assign n188_o = {n187_o, n185_o, n183_o, n181_o, n179_o, n177_o, n175_o, n173_o, n171_o, n169_o, n167_o, n165_o, n163_o, n161_o, n159_o, n157_o, n155_o};
endmodule

