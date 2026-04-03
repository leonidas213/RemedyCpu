module cpu_memory_glue_example
(
    input  wire        clk,
    input  wire        rst,

    input  wire        ld,
    input  wire        st,
    input  wire [15:0] programAddr,
    input  wire [15:0] AddrOut,
    input  wire [15:0] DataOut,
    input  wire        spimiso,

    output wire [15:0] mem_out,
    output wire        fetch_done,
    output wire        data_done,
    output wire        mem_stall,
    output wire        execute_pulse,
    output wire        pc_en,

    output wire        spics_flash,
    output wire        spics_ram,
    output wire        spiclk,
    output wire        spimosi,
    output wire        spibusy
);

  wire fetch_req;
  wire execute_now;
  wire wait_data;

  wire ld_req;
  wire st_req;

  wire spi_st;
  wire spi_ld;
  wire [15:0] spi_addr;
  wire [15:0] spi_data_in;
  wire [15:0] spi_data_out;
  wire spi_target;
  wire spi_is_continous;
  wire spi_cs;

  cpu_cycle_controller u_cycle
  (
      .clk(clk),
      .rst(rst),
      .fetch_done(fetch_done),
      .data_done(data_done),
      .ld(ld),
      .st(st),
      .fetch_req(fetch_req),
      .execute_now(execute_now),
      .wait_data(wait_data)
  );

  pulse_on_rise u_exec_pulse
  (
      .clk(clk),
      .rst(rst),
      .sig(execute_now),
      .pulse(execute_pulse)
  );

  assign ld_req = execute_pulse & ld;
  assign st_req = execute_pulse & st;

  memory_wait_controller u_mem_wait
  (
      .clk(clk),
      .rst(rst),
      .fetch_req(fetch_req),
      .ld_req(ld_req),
      .st_req(st_req),
      .fetch_addr(programAddr),
      .data_addr(AddrOut),
      .store_data(DataOut),
      .mem_rdata(mem_out),
      .fetch_done(fetch_done),
      .data_done(data_done),
      .mem_stall(mem_stall),
      .spi_st(spi_st),
      .spi_ld(spi_ld),
      .spi_addr(spi_addr),
      .spi_data_in(spi_data_in),
      .spi_target(spi_target),
      .spi_is_continous(spi_is_continous),
      .spi_data_out(spi_data_out),
      .spi_busy(spibusy)
  );

  spi_memory_interface u_spi_mem
  (
      .clk(clk),
      .spi_rst(rst),
      .st(spi_st),
      .ld(spi_ld),
      .addr(spi_addr),
      .data_in(spi_data_in),
      .data_out(spi_data_out),
      .is_continous(spi_is_continous),
      .spi_cs(spi_cs),
      .spi_clk(spiclk),
      .busy(spibusy),
      .spi_mosi(spimosi),
      .spi_miso(spimiso)
  );

  // Active-low chip selects derived from one SPI CS + target select.
  assign spics_flash = spi_cs |  spi_target;
  assign spics_ram   = spi_cs | ~spi_target;

  // Same logic as your gate + inverter drawing, just cleaner.
  assign pc_en = execute_pulse & ~mem_stall;

endmodule
