module interrupt_controller (
    input  wire        clk,
    input  wire        rst,

    input  wire [3:0]  irq_in,      // [0]=gpio, [1]=timer0, [2]=timer1, [3]=timer2
    input  wire        imm,         // block interrupt entry during imm
    input  wire        reti,        // return from interrupt
    input  wire        pc_en,       // PC updates on this cycle

    // simple register interface
    // reg_addr:
    // 0 -> control/status
    // 1 -> irq enable
    // 2 -> irq pending (write 1 to clear)
    input  wire        reg_we,
    input  wire [1:0]  reg_addr,
    input  wire [15:0] reg_wdata,
    output reg  [15:0] reg_rdata,

    output wire        intr,
    output wire        irq_lock
);

    reg        global_enable;
    reg        irq_lock_r;
    reg [3:0]  irq_enable;
    reg [3:0]  irq_pending;

    wire [3:0] active_irq;
    wire       intr_take;
    wire [3:0] pending_with_new_irq;

    assign pending_with_new_irq = irq_pending | irq_in;
    assign active_irq           = irq_pending & irq_enable;
    assign intr                 = global_enable & (~irq_lock_r) & (~imm) & (|active_irq);
    assign irq_lock             = irq_lock_r;

    // interrupt is considered taken when PC actually updates while intr is high
    assign intr_take = intr & pc_en;

    always @(posedge clk) begin
        if (rst) begin
            global_enable <= 1'b0;
            irq_lock_r    <= 1'b0;
            irq_enable    <= 4'b0000;
            irq_pending   <= 4'b0000;
        end
        else begin
            // default: latch any new interrupt requests
            irq_pending <= pending_with_new_irq;

            // register writes
            if (reg_we) begin
                case (reg_addr)
                    2'b00: begin
                        // bit0 = global interrupt enable
                        global_enable <= reg_wdata[0];
                    end

                    2'b01: begin
                        // bit[3:0] = source enables
                        irq_enable <= reg_wdata[3:0];
                    end

                    2'b10: begin
                        // write 1 to clear pending bits
                        irq_pending <= pending_with_new_irq & (~reg_wdata[3:0]);
                    end

                    default: begin
                    end
                endcase
            end

            // once PC takes the interrupt, lock until RETI
            if (intr_take) begin
                irq_lock_r <= 1'b1;
            end

            // unlock only on RETI
            if (reti) begin
                irq_lock_r <= 1'b0;
            end
        end
    end

    always @(*) begin
        case (reg_addr)
            // bit0 = global_enable
            // bit1 = irq_lock
            // bit2 = intr
            2'b00: reg_rdata = {13'b0, intr, irq_lock_r, global_enable};

            // bit[3:0] = irq_enable
            2'b01: reg_rdata = {12'b0, irq_enable};

            // bit[3:0] = irq_pending
            2'b10: reg_rdata = {12'b0, irq_pending};

            default: reg_rdata = 16'h0000;
        endcase
    end

endmodule