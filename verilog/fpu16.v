module fpu16
(
    input  wire        clk,
    input  wire        rst,
    input  wire        start,
    input  wire [1:0]  op,
    input  wire [15:0] a,
    input  wire [15:0] b,

    output reg  [15:0] result,
    output reg         busy,
    output reg         done
);

  parameter OP_ADD = 2'b00;
  parameter OP_SUB = 2'b01;
  parameter OP_MUL = 2'b10;

  parameter S_IDLE   = 2'd0;
  parameter S_CALC   = 2'd1;
  parameter S_FINISH = 2'd2;

  reg [1:0] state;
  reg [1:0] op_r;
  reg [15:0] a_r;
  reg [15:0] b_r;

  reg        s_a;
  reg        s_b;
  reg        s_big;
  reg        s_small;
  reg        s_r;

  reg [4:0]  e_a;
  reg [4:0]  e_b;
  reg [4:0]  e_big;
  reg [4:0]  e_small;

  reg [10:0] m_a;
  reg [10:0] m_b;
  reg [10:0] m_big;
  reg [10:0] m_small;
  reg [10:0] m_res;

  reg [12:0] big_ext;
  reg [12:0] small_ext;
  reg [12:0] sum_ext;

  reg [21:0] prod;

  reg [4:0]  shift_amt;

  integer exp_i;
  integer i;

  initial begin
    state  = S_IDLE;
    op_r   = 2'b00;
    a_r    = 16'h0000;
    b_r    = 16'h0000;
    result = 16'h0000;
    busy   = 1'b0;
    done   = 1'b0;
  end

  always @(posedge clk or posedge rst)
  begin
    if (rst)
    begin
      state  <= S_IDLE;
      op_r   <= 2'b00;
      a_r    <= 16'h0000;
      b_r    <= 16'h0000;
      result <= 16'h0000;
      busy   <= 1'b0;
      done   <= 1'b0;
    end
    else
    begin
      done <= 1'b0;

      case (state)
        S_IDLE:
        begin
          busy <= 1'b0;

          if (start)
          begin
            op_r  <= op;
            a_r   <= a;
            b_r   <= b;
            busy  <= 1'b1;
            state <= S_CALC;
          end
        end

        S_CALC:
        begin
          s_a     = a_r[15];
          s_b     = b_r[15];
          e_a     = a_r[14:10];
          e_b     = b_r[14:10];
          m_a     = (e_a == 5'd0) ? 11'd0 : {1'b1, a_r[9:0]};
          m_b     = (e_b == 5'd0) ? 11'd0 : {1'b1, b_r[9:0]};

          result <= 16'h0000;

          if (op_r == OP_MUL)
          begin
            if ((m_a == 11'd0) || (m_b == 11'd0))
            begin
              result <= 16'h0000;
            end
            else
            begin
              s_r  = s_a ^ s_b;
              prod = m_a * m_b;
              exp_i = e_a + e_b - 15;

              if (prod[21])
              begin
                exp_i = exp_i + 1;
                m_res = prod[21:11];
              end
              else
              begin
                m_res = prod[20:10];
              end

              if (exp_i <= 0)
                result <= 16'h0000;
              else if (exp_i >= 31)
                result <= {s_r, 5'b11111, 10'b0000000000};
              else
                result <= {s_r, exp_i[4:0], m_res[9:0]};
            end
          end
          else
          begin
            if (op_r == OP_SUB)
              s_b = ~s_b;

            if ((m_a == 11'd0) && (m_b == 11'd0))
            begin
              result <= 16'h0000;
            end
            else if (m_a == 11'd0)
            begin
              if (e_b == 5'd0)
                result <= 16'h0000;
              else
                result <= {s_b, e_b, b_r[9:0]};
            end
            else if (m_b == 11'd0)
            begin
              if (e_a == 5'd0)
                result <= 16'h0000;
              else
                result <= {s_a, e_a, a_r[9:0]};
            end
            else
            begin
              if ((e_a > e_b) || ((e_a == e_b) && (m_a >= m_b)))
              begin
                s_big   = s_a;
                s_small = s_b;
                e_big   = e_a;
                e_small = e_b;
                m_big   = m_a;
                m_small = m_b;
              end
              else
              begin
                s_big   = s_b;
                s_small = s_a;
                e_big   = e_b;
                e_small = e_a;
                m_big   = m_b;
                m_small = m_a;
              end

              shift_amt = e_big - e_small;
              if (shift_amt > 5'd11)
                m_small = 11'd0;
              else
                m_small = m_small >> shift_amt;

              big_ext   = {2'b00, m_big};
              small_ext = {2'b00, m_small};
              exp_i     = e_big;
              s_r       = s_big;

              if (s_big == s_small)
              begin
                sum_ext = big_ext + small_ext;

                if (sum_ext[11])
                begin
                  m_res = sum_ext[11:1];
                  exp_i = exp_i + 1;
                end
                else
                begin
                  m_res = sum_ext[10:0];
                end

                if (exp_i <= 0)
                  result <= 16'h0000;
                else if (exp_i >= 31)
                  result <= {s_r, 5'b11111, 10'b0000000000};
                else
                  result <= {s_r, exp_i[4:0], m_res[9:0]};
              end
              else
              begin
                sum_ext = big_ext - small_ext;

                if (sum_ext[10:0] == 11'd0)
                begin
                  result <= 16'h0000;
                end
                else
                begin
                  m_res = sum_ext[10:0];

                  for (i = 0; i < 11; i = i + 1)
                  begin
                    if ((m_res[10] == 1'b0) && (exp_i > 1))
                    begin
                      m_res = m_res << 1;
                      exp_i = exp_i - 1;
                    end
                  end

                  if ((exp_i <= 0) || (m_res[10] == 1'b0))
                    result <= 16'h0000;
                  else
                    result <= {s_r, exp_i[4:0], m_res[9:0]};
                end
              end
            end
          end

          state <= S_FINISH;
        end

        S_FINISH:
        begin
          busy  <= 1'b0;
          done  <= 1'b1;
          state <= S_IDLE;
        end

        default:
        begin
          state <= S_IDLE;
        end
      endcase
    end
  end

endmodule