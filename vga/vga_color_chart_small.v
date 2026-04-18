module vga_color_chart_small_fixed (
    input  wire clk,      // pixel clock: ideally 25.175 MHz, 25 MHz usually works
    input  wire reset,

    output wire hsync,
    output wire vsync,
    output wire [1:0] vga_r,
    output wire [1:0] vga_g,
    output wire [1:0] vga_b
);

    // 640x480 @ 60 Hz timing
    // H total = 800 : 640 visible, 16 front, 96 sync, 48 back
    // V total = 525 : 480 visible, 10 front,  2 sync, 33 back

    reg [9:0] hcount;
    reg [9:0] vcount;

    reg [6:0] x_in_cell;   // 0..79
    reg [5:0] y_in_cell;   // 0..59
    reg [2:0] cell_x;      // 0..7
    reg [2:0] cell_y;      // 0..7

    wire visible_area;

    assign visible_area = (hcount < 10'd640) && (vcount < 10'd480);

    // active low syncs
    assign hsync = ~((hcount >= 10'd656) && (hcount < 10'd752));
    assign vsync = ~((vcount >= 10'd490) && (vcount < 10'd492));

    // 64 colors from 8x8 chart position
    assign vga_r = visible_area ? cell_y[2:1]             : 2'b00;
    assign vga_g = visible_area ? {cell_y[0], cell_x[2]} : 2'b00;
    assign vga_b = visible_area ? cell_x[1:0]             : 2'b00;

    always @(posedge clk) begin
        if (reset) begin
            hcount    <= 10'd0;
            vcount    <= 10'd0;
            x_in_cell <= 7'd0;
            y_in_cell <= 6'd0;
            cell_x    <= 3'd0;
            cell_y    <= 3'd0;
        end else begin
            if (hcount == 10'd799) begin
                hcount <= 10'd0;

                // restart horizontal cell tracking each line
                x_in_cell <= 7'd0;
                cell_x    <= 3'd0;

                if (vcount == 10'd524) begin
                    vcount    <= 10'd0;
                    y_in_cell <= 6'd0;
                    cell_y    <= 3'd0;
                end else begin
                    vcount <= vcount + 10'd1;

                    // only advance 8-row chart inside visible 480 lines
                    if (vcount < 10'd479) begin
                        if (y_in_cell == 6'd59) begin
                            y_in_cell <= 6'd0;
                            cell_y    <= cell_y + 3'd1;
                        end else begin
                            y_in_cell <= y_in_cell + 6'd1;
                        end
                    end else begin
                        y_in_cell <= 6'd0;
                        cell_y    <= 3'd0;
                    end
                end
            end else begin
                hcount <= hcount + 10'd1;

                // only advance 8-column chart inside visible 640 pixels
                if (hcount < 10'd639) begin
                    if (x_in_cell == 7'd79) begin
                        x_in_cell <= 7'd0;
                        cell_x    <= cell_x + 3'd1;
                    end else begin
                        x_in_cell <= x_in_cell + 7'd1;
                    end
                end else begin
                    x_in_cell <= 7'd0;
                    cell_x    <= 3'd0;
                end
            end
        end
    end

endmodule