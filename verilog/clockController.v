module ClockCont
  (
    input Clk,
    input Enable,
    input rst,
    output instRead,
    output instFetch,
    output instDecode,
    output instExecute
  );

  reg[3:0]  Counter = 'h0;
  reg instReadReg = 1'b1;
  assign instRead = instReadReg;
  assign instFetch = (Counter == 5'h2);
  assign instDecode = (Counter == 5'h4);
  assign instExecute = (Counter == 5'h5);


  always @ (posedge Clk)
  begin
    if(rst)
    begin
      Counter <= 5'h0;
      instReadReg <=1'b1;
    end
    else
    begin
      if ( Enable=='h0)
        Counter <= Counter + 1;

      instReadReg<=Counter == 5'h0 | Counter == 5'h1;
    end
  end
endmodule
