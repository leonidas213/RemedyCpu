module uart_regs (
    input clk,
    input rst,
    input iow,
    input ior,
    input [15:0] addr,
    input [15:0] data_in,
    output reg [15:0] data_out,
    output reg tx_wr_en,
    output reg rx_rd_en,
    output reg [7:0] tx_data,
    input [7:0] rx_data,
    input rx_ready,
    input tx_ready,
    input rx_empty,
    input tx_empty,
    input rx_full,
    input tx_full,
    input tx_busy,
    input interrupt_busy,
    output reg [15:0] baud_div,
    output reg interrupt,
    input [15:0] writeReadAddr,
    input [15:0] configReg,
    input [15:0] statusReg,
    output reg outEnable
);
    // localparam writeReadAddr = 16'h000A ;
    // localparam configReg = 16'h000B ;
    // localparam statusReg = 16'h000C ;
    reg [1:0] conf;       // Bit 0 = TX INT enable, Bit 1 = RX INT enable
    reg interrupt_pending;

    // Write logic
    always @(posedge clk , posedge rst) begin
        if (rst) begin
            tx_wr_en <= 0;
            rx_rd_en <= 0;
            baud_div <= 1;
            conf <= 2'b00;
            interrupt <= 0;
            interrupt_pending <= 0;
        end else begin
            tx_wr_en <= 0;
            interrupt <= 0;

            if (iow) begin
                case (addr)
                    writeReadAddr: begin
                        tx_data <= data_in[7:0];
                        tx_wr_en <= 1;
                    end
                    configReg: begin
                        conf <= data_in[1:0];
                        baud_div <= data_in[15:0];
                    end
                endcase
            end

            // Interrupt conditions
            if ((rx_ready && conf[1]) || (tx_ready && conf[0])) begin
                if (!interrupt_busy) begin
                    interrupt <= 1;
                    interrupt_pending <= 1;
                end
            end else if (interrupt_busy) begin
                interrupt <= 0;
            end
        end
    end

    // Read logic
    always @(posedge ior,posedge clk) begin
        data_out = 16'h0000;
        if (ior) begin
            case (addr)
                writeReadAddr: begin
                    data_out = {8'h00, rx_data};
                    rx_rd_en = 1;
                        outEnable = 1;
                   
                end
                configReg: begin
                    data_out = {baud_div, conf};
                    outEnable = 1; 
                end
                statusReg: begin
                    data_out[0] = tx_ready;
                    data_out[1] = rx_ready;
                    data_out[2] = tx_empty;
                    data_out[3] = rx_empty;
                    data_out[4] = tx_full;
                    data_out[5] = rx_full;
                    data_out[6] = interrupt_pending;
                    outEnable = 1; 
                end
            endcase
        end else begin
            outEnable = 0;
            rx_rd_en = 0;
        end
    end
endmodule
