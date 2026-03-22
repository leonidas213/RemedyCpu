module muxEncoder
  (
    input a,
    input b,
    input c,
    input d,
    input e,
    input f,
    input g,
    input h,
    output reg [2:0]Q
  );

  always @ ( a,b,c,d,e,f,g,h)
  begin

    Q[0] = h | f | d | b ;
    Q[1] = h | g | d | c ;
    Q[2] = h | g | f | e ;

  end
endmodule
