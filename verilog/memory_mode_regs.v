module memory_mode_regs (
    input  [15:0] dOut,
    input  [15:0] Addr,
    input         ioW,
    input         ioR,
    input         C,
    input         rst,

    input  [15:0] memCtrlAddr,
    input  [15:0] memCmdAddr,
    input  [15:0] memStatusAddr,

    // live status from memory subsystem
    input         mem_busy,
    input         flash_qe_ok,
    input         flash_quad_active,
    input         ram_qpi_active,
    input         mem_error,

    // MMIO readback bus
    output [15:0] MemOut,

    // persistent requested modes / policy bits
    output        req_flash_quad_read,
    output        req_cont_fetch,
    output        req_ram_qpi,

    // one-clock command pulses
    output reg    cmd_flash_set_qe,
    output reg    cmd_flash_clear_qe,
    output reg    cmd_ram_enter_qpi,
    output reg    cmd_ram_exit_qpi,
    output reg    cmd_flash_if_reset,
    output reg    cmd_ram_if_reset
);

  // ------------------------------------------------------------
  // Register map
  // ------------------------------------------------------------
  // MEM_CTRL (R/W)
  //   bit 0 : desired flash read mode      0=normal SPI, 1=quad read
  //   bit 1 : desired continuous fetch      0=off, 1=on
  //   bit 2 : desired RAM bus mode          0=SPI, 1=QPI
  //
  // MEM_CMD (W, pulse)
  //   bit 0 : send command to set flash QE
  //   bit 1 : send command to clear flash QE
  //   bit 2 : send command to enter RAM QPI
  //   bit 3 : send command to exit RAM QPI
  //   bit 4 : reset / resync flash interface
  //   bit 5 : reset / resync RAM interface
  //
  // MEM_STATUS (R)
  //   bit 0 : memory subsystem busy
  //   bit 1 : flash QE known enabled
  //   bit 2 : flash quad-read currently active
  //   bit 3 : RAM QPI currently active
  //   bit 4 : error flag from memory subsystem
  // ------------------------------------------------------------

  reg [15:0] mem_ctrl;

  wire wr_memctrl   = ioW && (Addr == memCtrlAddr);
  wire wr_memcmd    = ioW && (Addr == memCmdAddr);

  wire rd_memctrl   = ioR && (Addr == memCtrlAddr);
  wire rd_memcmd    = ioR && (Addr == memCmdAddr);
  wire rd_memstatus = ioR && (Addr == memStatusAddr);

  wire [15:0] mem_status;

  always @(posedge C)
  begin
    if (rst)
    begin
      mem_ctrl           <= 16'h0000;
      cmd_flash_set_qe   <= 1'b0;
      cmd_flash_clear_qe <= 1'b0;
      cmd_ram_enter_qpi  <= 1'b0;
      cmd_ram_exit_qpi   <= 1'b0;
      cmd_flash_if_reset <= 1'b0;
      cmd_ram_if_reset   <= 1'b0;
    end
    else
    begin
      // default one-shot pulses low
      cmd_flash_set_qe   <= 1'b0;
      cmd_flash_clear_qe <= 1'b0;
      cmd_ram_enter_qpi  <= 1'b0;
      cmd_ram_exit_qpi   <= 1'b0;
      cmd_flash_if_reset <= 1'b0;
      cmd_ram_if_reset   <= 1'b0;

      if (wr_memctrl)
        mem_ctrl <= dOut;

      if (wr_memcmd)
      begin
        cmd_flash_set_qe   <= dOut[0];
        cmd_flash_clear_qe <= dOut[1];
        cmd_ram_enter_qpi  <= dOut[2];
        cmd_ram_exit_qpi   <= dOut[3];
        cmd_flash_if_reset <= dOut[4];
        cmd_ram_if_reset   <= dOut[5];
      end
    end
  end

  assign req_flash_quad_read = mem_ctrl[0];
  assign req_cont_fetch      = mem_ctrl[1];
  assign req_ram_qpi         = mem_ctrl[2];

  assign mem_status = {
      11'h000,
      mem_error,
      ram_qpi_active,
      flash_quad_active,
      flash_qe_ok,
      mem_busy
  };

  assign MemOut = rd_memctrl   ? mem_ctrl          :
                  rd_memcmd    ? 16'h0000          :
                  rd_memstatus ? mem_status        :
                                  16'h0000;

endmodule
