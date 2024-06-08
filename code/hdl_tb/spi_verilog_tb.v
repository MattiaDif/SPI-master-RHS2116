// @title      SPI protocol specific for Intan RHS, testbench
// @file       spi_verilog_tb.vhd
// @author     Mattia Di Florio
// @date       7 jun 2024
// @version    0.1
// @copyright
// © 2024 Mattia Di Florio <di.florio.mattia@gmail.com>
// SPDX-License-Identifier: MIT License
//
// @brief
// SPI protocol tb for Intan RHS devices, CPOL = 0, CPHA = 0.
// For more info, refer to Intan RHS2116 Datasheet
// 
// @changelog
// > 

`timescale 1ns/1ps
`include "/mnt/d/GitHub/SPI-master-RHS2116/code/hdl/spi_verilog.v"


module spi_verilog_tb;

    // Parameters
    localparam  CLK_FREQ    = 100000000;
    localparam  WORD_LENGTH =        32;
    localparam  SPICLK_FREQ =  25000000;

    localparam COUNTER_MAX = 1;
    localparam END_SIM = 10;

    //Ports
    reg  clk = 0;
    reg  reset;
    wire cs;
    wire mosi_1;
    wire  miso_1;
    wire mosi_2;
    wire  miso_2;
    wire sclk;
    reg  data_in_v;
    wire ready_out;
    wire data_out_v;
    reg  [WORD_LENGTH-1:0] data_in_1;
    reg  [WORD_LENGTH-1:0] data_in_2;
    wire [WORD_LENGTH-1:0] data_out_1;
    wire [WORD_LENGTH-1:0] data_out_2;

    integer x = 0;
    integer counter = 0;
    integer data = 0;


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
        // for icarus verilog simulator
        $dumpfile("spi_verilog_tb.vcd");
        $dumpvars;
        reset = 1'b1;
        #30
        reset = 1'b0;
    end

    always @(posedge(clk)) begin

        if (reset) begin
            
        end else if (counter < COUNTER_MAX) begin
            counter <= counter + 1;
            data_in_v <= 1'b0;
        end else if (counter == COUNTER_MAX && data_in_v == 1'b0) begin
            data_in_1 <= data;
            data_in_2 <= data;
            data_in_v <= 1'b1;
        end else if (data_in_v == 1'b1 && ready_out == 1'b1) begin
            if (data < 150) begin
                data <= data + 1;
            end else begin
                data <= 0;
            end
            counter   <= 0;
            data_in_v <= 1'b0;

            x <= x + 1;
            #10;    
            if (x>END_SIM) begin
                $finish;
            end  
        end  
        
    end

    assign miso_1 = mosi_1;
    assign miso_2 = mosi_2;

endmodule