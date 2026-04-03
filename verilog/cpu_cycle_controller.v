module cpu_cycle_controller
(
    input  wire clk,
    input  wire rst,

    input  wire fetch_done,
    input  wire data_done,

    input  wire ld,
    input  wire st,

    output wire fetch_req,
    output wire execute_now,
    output wire wait_data
);

  localparam S_REQ_FETCH  = 2'd0;
  localparam S_WAIT_FETCH = 2'd1;
  localparam S_EXECUTE    = 2'd2;
  localparam S_WAIT_DATA  = 2'd3;

  reg [1:0] state = S_REQ_FETCH;

  assign fetch_req   = (state == S_REQ_FETCH);
  assign execute_now = (state == S_EXECUTE);
  assign wait_data   = (state == S_WAIT_DATA);

  always @(posedge clk )
  begin
    if (rst)
    begin
      state <= S_REQ_FETCH;
    end
    else
    begin
      case (state)
        S_REQ_FETCH:
          state <= S_WAIT_FETCH;

        S_WAIT_FETCH:
        begin
          if (fetch_done)
            state <= S_EXECUTE;
        end

        S_EXECUTE:
        begin
          if (ld || st)
            state <= S_WAIT_DATA;
          else
            state <= S_REQ_FETCH;
        end

        S_WAIT_DATA:
        begin
          if (data_done)
            state <= S_REQ_FETCH;
        end

        default:
          state <= S_REQ_FETCH;
      endcase
    end
  end

endmodule