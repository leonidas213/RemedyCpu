module is_different (
    input  [15:0] in1,
    input  [15:0] in2,

    output        different
  );
  assign different = (in1 != in2);

endmodule
