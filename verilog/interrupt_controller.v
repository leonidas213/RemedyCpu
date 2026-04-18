module interrupt_controller_small (
    input  [3:0] dOut,
    input  [15:0] Addr,
    input         ioW,
    input         C,
    input         rst_n,

    input  [3:0]  irq_in,
    input         imm,
    input         reti,
    input         pc_en,

    input  [15:0] CPUInterruptEnableAddr,
    input  [15:0] inputInterruptAddr,
    input  [15:0] interruptRegAddr,

    output [15:0] InterruptOut,
    output        intr,
    output        irq_lock
);

  reg       global_enable;
  reg       irq_lock_r   ;
  reg [3:0] irq_enable   ;
  reg [3:0] irq_pending  ;

  wire wr_ctrl;
  wire wr_enable;
  wire wr_pending;

  wire rd_ctrl;
  wire rd_enable;
  wire rd_pending;

  wire [3:0] pending_with_new_irq;
  wire [3:0] active_irq;
  wire       intr_take;

  assign wr_ctrl    = ioW && (Addr == CPUInterruptEnableAddr);
  assign wr_enable  = ioW && (Addr == inputInterruptAddr);
  assign wr_pending = ioW && (Addr == interruptRegAddr);

  assign rd_ctrl    =  (Addr == CPUInterruptEnableAddr);
  assign rd_enable  =  (Addr == inputInterruptAddr);
  assign rd_pending =  (Addr == interruptRegAddr);

  assign pending_with_new_irq = irq_pending | irq_in;
  assign active_irq           = irq_pending & irq_enable;

  assign intr      = global_enable && !irq_lock_r && !imm && (active_irq != 4'b0000);
  assign irq_lock  = irq_lock_r;
  assign intr_take = intr && pc_en;

  always @(posedge C or negedge rst_n)
  begin
    if (!rst_n)
    begin
      global_enable <= 1'b0;
      irq_lock_r    <= 1'b0;
      irq_enable    <= 4'b0000;
      irq_pending   <= 4'b0000;
    end
    else
    begin
      // default: latch new interrupt requests
      irq_pending <= pending_with_new_irq;

      // global interrupt enable
      if (wr_ctrl)
        global_enable <= dOut[0];

      // source enable bits [3:0]
      if (wr_enable)
        irq_enable <= dOut[3:0];

      // write 1 to clear pending bits
      if (wr_pending)
        irq_pending <= pending_with_new_irq & ~dOut[3:0];

      // lock once interrupt is actually taken
      if (intr_take)
        irq_lock_r <= 1'b1;

      // unlock only on RETI
      if (reti)
        irq_lock_r <= 1'b0;
    end
  end

  assign InterruptOut =
      rd_ctrl    ? {13'h0000, intr, irq_lock_r, global_enable} :
      rd_enable  ? {12'h000, irq_enable} :
      rd_pending ? {12'h000, irq_pending} :
      16'h0000;

endmodule