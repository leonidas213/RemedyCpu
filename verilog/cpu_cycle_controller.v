module cpu_cycle_controller
  (
    input  wire clk,
    input  wire rst_n,

    input  wire fetch_done,
    input  wire data_done,

    input  wire ld,
    input  wire st,
    input  wire flash_ld,


    output wire fetch_req,
    output wire execute_now_pulse
  );

  localparam S_REQ_FETCH  = 2'd0;
  localparam S_WAIT_FETCH = 2'd1;
  localparam S_EXECUTE    = 2'd2;
  localparam S_WAIT_DATA  = 2'd3;

  reg [1:0] state;

  wire execute_now;
  assign execute_now = (state == S_EXECUTE);
  assign fetch_req   = (state == S_REQ_FETCH);

  always @(posedge clk , negedge rst_n)
  begin
    if (!rst_n)
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
          if (ld || st || flash_ld)
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

  // rise detector
  reg sig_d;
  always @(posedge clk, negedge rst_n)
  begin
    if (!rst_n)
      sig_d <= 1'b0;
    else
      sig_d <= execute_now;
  end

  assign execute_now_pulse = execute_now & ~sig_d;
endmodule
