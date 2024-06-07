`timescale 1ns/1ps
`include "/mnt/d/GitHub/SPI-master-RHS2116/code/hdl/spi_verilog.v"


module spi_verilog_tb;

    // Parameters
    localparam  CLK_FREQ    = 100000000;
    localparam  WORD_LENGTH =        32;
    localparam  SPICLK_FREQ =  25000000;

    //Ports
    reg  clk = 0;
    reg  reset;
    wire cs;
    wire mosi_1;
    reg  miso_1;
    wire mosi_2;
    reg  miso_2;
    wire sclk;
    reg  data_in_v;
    wire ready_out;
    wire data_out_v;
    reg  [WORD_LENGTH-1:0] data_in_1;
    reg  [WORD_LENGTH-1:0] data_in_2;
    wire [WORD_LENGTH-1:0] data_out_1;
    wire [WORD_LENGTH-1:0] data_out_2;

    integer x = 0;


    spi_verilog # (
        .CLK_FREQ(CLK_FREQ),
        .WORD_LENGTH(WORD_LENGTH),
        .SPICLK_FREQ(SPICLK_FREQ)
    )

    spi_verilog_inst (
        .clk(clk),
        .reset(reset),
        .cs(cs),
        .mosi_1(mosi_1),
        .miso_1(miso_1),
        .mosi_2(mosi_2),
        .miso_2(miso_2),
        .sclk(sclk),
        .data_in_v(data_in_v),
        .ready_out(ready_out),
        .data_out_v(data_out_v),
        .data_in_1(data_in_1),
        .data_in_2(data_in_2),
        .data_out_1(data_out_1),
        .data_out_2(data_out_2)
    );

    always #5  clk = ! clk;    // 10 ns delay

    initial begin
        $dumpfile("spi_verilog_tb.vcd");
        $dumpvars;
        reset = 1'b1;
        #30
        reset = 1'b0;
    end

    always @(posedge(clk)) begin
        if (reset) begin
            
        end else begin
            x <= x + 1;
            #10;    
            if (x>10) begin
                $finish;
            end        
        end
        
    end

endmodule