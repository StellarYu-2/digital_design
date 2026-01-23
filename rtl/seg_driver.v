`timescale 1ns / 1ps

module seg_driver(
    input            clk,      // System clock
    input            rst_n,    // Reset active low
    input      [23:0] data_bcd, // 6 digits BCD data to display (e.g. 123456 -> 0x123456)
    output reg [5:0]  sel,     // Digit select (Active Low)
    output reg [7:0]  seg      // Segments (Active Low, .gfe_dcba)
);

    // Refresh rate control
    // Assuming 50MHz clock. 1ms per digit -> 1kHz refresh.
    // 50,000 cycles.
    reg [15:0] scan_cnt;
    reg [2:0]  scan_sel;

    always @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            scan_cnt <= 0;
            scan_sel <= 0;
        end else begin
            if(scan_cnt >= 50000) begin // 1ms
                scan_cnt <= 0;
                if(scan_sel == 5) scan_sel <= 0;
                else scan_sel <= scan_sel + 1;
            end else begin
                scan_cnt <= scan_cnt + 1;
            end
        end
    end

    // Mux digit data
    reg [3:0] digit_data;
    always @(*) begin
        case(scan_sel)
            0: digit_data = data_bcd[3:0];
            1: digit_data = data_bcd[7:4];
            2: digit_data = data_bcd[11:8];
            3: digit_data = data_bcd[15:12];
            4: digit_data = data_bcd[19:16];
            5: digit_data = data_bcd[23:20];
            default: digit_data = 0;
        endcase
    end

    // Decode to 7-segment
    //      a
    //     ---
    //  f |   | b
    //     -g-
    //  e |   | c
    //     ---
    //      d
    always @(*) begin
        case(digit_data)
            4'h0: seg = 8'hc0; // 1100_0000
            4'h1: seg = 8'hf9; // 1111_1001
            4'h2: seg = 8'ha4; // 1010_0100
            4'h3: seg = 8'hb0; // 1011_0000
            4'h4: seg = 8'h99; // 1001_1001
            4'h5: seg = 8'h92; // 1001_0010
            4'h6: seg = 8'h82; // 1000_0010
            4'h7: seg = 8'hf8; // 1111_1000
            4'h8: seg = 8'h80; // 1000_0000
            4'h9: seg = 8'h90; // 1001_0000
            4'hA: seg = 8'h88; // 1000_1000 (A)
            4'hB: seg = 8'h83; // 1000_0011 (b)
            4'hC: seg = 8'hc6; // 1100_0110 (C)
            4'hD: seg = 8'ha1; // 1010_0001 (d)
            4'hE: seg = 8'h86; // 1000_0110 (E)
            4'hF: seg = 8'h8e; // 1000_1110 (F)
            default: seg = 8'hc0;
        endcase
    end

    // Digit Select Logic (Active Low)
    always @(*) begin
        case(scan_sel)
            0: sel = 6'b111110;
            1: sel = 6'b111101;
            2: sel = 6'b111011;
            3: sel = 6'b110111;
            4: sel = 6'b101111;
            5: sel = 6'b011111;
            default: sel = 6'b111111;
        endcase
    end

endmodule
