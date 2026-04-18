`timescale 1ns/1ps

module tb_i2c_master_read;

reg         clk;
reg         rst;

reg         wr_en;
reg         rd_en;
reg  [3:0]  reg_addr;
reg  [15:0] cpu_din;
wire [15:0] cpu_dout;

wire sda_out;
wire scl_out;
wire sda_oe;
wire scl_oe;
wire interrupt;

wire sda_in;
wire scl_in;

reg  slave_sda_oe;
reg  slave_scl_oe;

wire sda_bus;
wire scl_bus;

// Open-drain bus with pull-up behavior
assign sda_bus = (sda_oe | slave_sda_oe) ? 1'b0 : 1'b1;
assign scl_bus = (scl_oe | slave_scl_oe) ? 1'b0 : 1'b1;

assign sda_in = sda_bus;
assign scl_in = scl_bus;

i2c_master_ctrl dut (
    .clk(clk),
    .rst(rst),

    .wr_en(wr_en),
    .rd_en(rd_en),
    .reg_addr(reg_addr),
    .cpu_din(cpu_din),
    .cpu_dout(cpu_dout),

    .sda_in(sda_in),
    .scl_in(scl_in),
    .sda_out(sda_out),
    .scl_out(scl_out),
    .sda_oe(sda_oe),
    .scl_oe(scl_oe),

    .interrupt(interrupt)
);

// Match DUT states
localparam ST_IDLE       = 4'd0;
localparam ST_START_1    = 4'd1;
localparam ST_START_2    = 4'd2;
localparam ST_START_3    = 4'd3;
localparam ST_BIT_SETUP  = 4'd4;
localparam ST_BIT_HIGH   = 4'd5;
localparam ST_BIT_LOW    = 4'd6;
localparam ST_ACK_SETUPW = 4'd7;
localparam ST_ACK_HIGHW  = 4'd8;
localparam ST_ACK_LOWW   = 4'd9;
localparam ST_ACK_SETUPR = 4'd10;
localparam ST_ACK_HIGHR  = 4'd11;
localparam ST_ACK_LOWR   = 4'd12;
localparam ST_STOP_1     = 4'd13;
localparam ST_STOP_2     = 4'd14;
localparam ST_STOP_3     = 4'd15;

// Slave byte to send during read
reg [7:0] slave_read_byte;

// 100 MHz clock
always #5 clk = ~clk;

// Simple slave model
always @(*) begin
    slave_sda_oe = 1'b0;
    slave_scl_oe = 1'b0;

    // ACK during master's write-ack phase (address byte write)
    if ((dut.state == ST_ACK_SETUPW) || (dut.state == ST_ACK_HIGHW)) begin
        slave_sda_oe = 1'b1; // ACK = drive SDA low
    end

    // During read bit phases, slave drives data bits
    // Master samples during ST_BIT_HIGH when cmd_read=1
    // So slave should present bit during ST_BIT_SETUP/ST_BIT_HIGH
    if (dut.cmd_read && ((dut.state == ST_BIT_SETUP) || (dut.state == ST_BIT_HIGH))) begin
        if (slave_read_byte[dut.bit_count] == 1'b0)
            slave_sda_oe = 1'b1; // drive low for 0
        else
            slave_sda_oe = 1'b0; // release for 1
    end
end

task cpu_write;
    input [3:0] addr;
    input [15:0] data;
    begin
        @(negedge clk);
        reg_addr = addr;
        cpu_din  = data;
        wr_en    = 1'b1;
        rd_en    = 1'b0;

        @(negedge clk);
        wr_en    = 1'b0;
    end
endtask

task cpu_read;
    input [3:0] addr;
    begin
        @(negedge clk);
        reg_addr = addr;
        rd_en    = 1'b1;
        wr_en    = 1'b0;
        #1;
        $display("[%0t] READ reg %0h => 0x%04X", $time, addr, cpu_dout);
        @(negedge clk);
        rd_en    = 1'b0;
    end
endtask

task show_status;
    begin
        @(negedge clk);
        reg_addr = 4'h1;
        rd_en    = 1'b1;
        wr_en    = 1'b0;
        #1;
        $display("[%0t] STATUS = 0x%04X  busy=%0d bus_active=%0d done=%0d ack_error=%0d rx_valid=%0d irq=%0d",
                 $time, cpu_dout,
                 cpu_dout[0], cpu_dout[1], cpu_dout[2], cpu_dout[3], cpu_dout[4], cpu_dout[5]);
        @(negedge clk);
        rd_en    = 1'b0;
    end
endtask

initial begin
    clk            = 1'b0;
    rst            = 1'b1;
    wr_en          = 1'b0;
    rd_en          = 1'b0;
    reg_addr       = 4'd0;
    cpu_din        = 16'd0;
    slave_read_byte = 8'h3C; // byte the slave will return

    $dumpfile("i2c_master_read.vcd");
    $dumpvars(0, tb_i2c_master_read);

    // reset
    repeat (5) @(negedge clk);
    rst = 1'b0;

    // CTRL:
    // bit0 enable = 1
    // bit1 irq_enable = 1
    // bit2 stretch_enable = 0
    cpu_write(4'h0, 16'h0003);

    // PRESCALE: small for fast simulation
    cpu_write(4'h2, 16'd2);

    $display("---- SEND ADDRESS BYTE WITH READ BIT ----");
    // Example slave 7-bit address 0x50, read bit = 1 => 0xA1
    cpu_write(4'h3, 16'h00A1);

    // CMD: start + write = bit0 + bit2 = 0x0005
    cpu_write(4'h4, 16'h0005);

    wait (dut.done == 1'b1);
    show_status();

    if (dut.ack_error) begin
        $display("FAIL: address phase got NACK");
        $finish;
    end

    // clear done + ack_error + rx_valid + irq_pending
    cpu_write(4'h1, 16'h003C);

    $display("---- READ ONE BYTE, SEND NACK, THEN STOP ----");

    // CMD: stop + read + read_nack = bit1 + bit3 + bit4 = 0x001A
    cpu_write(4'h4, 16'h001A);

    wait (dut.done == 1'b1);
    show_status();

    // Read DATA register
    cpu_read(4'h3);

    if (cpu_dout[7:0] == slave_read_byte)
        $display("PASS: received expected byte 0x%02X", cpu_dout[7:0]);
    else
        $display("FAIL: expected 0x%02X but got 0x%02X", slave_read_byte, cpu_dout[7:0]);

    repeat (20) @(negedge clk);
    $finish;
end

// Helpful trace
always @(posedge clk) begin
    if (dut.sm_tick) begin
        $display("[%0t] state=%0d SDA=%b SCL=%b bit_count=%0d cmd_w=%0d cmd_r=%0d rx_shift=0x%02X",
                 $time, dut.state, sda_bus, scl_bus, dut.bit_count,
                 dut.cmd_write, dut.cmd_read, dut.rx_shift);
    end
end

endmodule