// @title      SPI protocol specific for Intan RHS, multi MISO/MOSI
// @category   interface
// @file       spi_verilog.v
// @author     Mattia Di Florio
// @date       07 jun 2024
// @version    0.1
// @copyright
// © 2024 Mattia Di Florio <di.florio.mattia@gmail.com>
// SPDX-License-Identifier: MIT License
//
// @brief
// SPI protocol specific for Intan RHS2116 chip, CPOL = 0, CPHA = 0.
// For more info, refer to Intan RHS2116 Datasheet
// 
// @changelog
// > 
///////////////////////////////////////////////////////////////////////////////

module spi_verilog
#( parameter CLK_FREQ    = 100000000,
   parameter WORD_LENGTH =        32,
   parameter SPICLK_FREQ =  25000000
)

( input wire clk,
  input wire reset,
  output wire cs,

  output wire mosi_1,
  input  wire miso_1,
  output wire mosi_2,
  input  wire miso_2,

  output wire sclk,

  //interface
  input  wire data_in_v,
  output wire ready_out,
  output wire data_out_v,

  input  wire [WORD_LENGTH-1:0] data_in_1,
  input  wire [WORD_LENGTH-1:0] data_in_2,

  output reg [WORD_LENGTH-1:0] data_out_1,
  output reg [WORD_LENGTH-1:0] data_out_2

);



parameter zero = 1'b0;
parameter one  = 1'b1;

reg     clk_controller;
reg     clk_trig;
integer clk_inc;


parameter idle    = 2'b00;
parameter start   = 2'b01;
parameter wait_cs = 2'b10;

reg [1:0] main_proc;
reg       clk_counter;
reg       go_proc;
reg       chip_sel;    
reg       busy_flag;   
reg       data_ready;    



// SPI clock (sclk) generation
always @(posedge(clk)) begin: clk_generation
    if (reset == 1'b1) begin
        clk_controller <= zero;
        clk_trig       <= 1'b0;
        clk_inc        <= 0;
        
    end else begin
        case(clk_controller)
            zero: begin
                if (clk_inc < ((CLK_FREQ/(SPICLK_FREQ))/2)) begin
                    clk_inc <= clk_inc + 1;

                    if (clk_inc == ((CLK_FREQ/(SPICLK_FREQ))/2) - 1) begin
                        clk_controller <= one;
                        clk_trig <= 1'b0;
                    
                    end else begin
                        clk_trig <= 1'b1;

                    end
                end    
                end

            one: begin
                if (clk_inc < (CLK_FREQ/(SPICLK_FREQ))) begin
                    clk_inc <= clk_inc + 1;

                    if (clk_inc == (CLK_FREQ/(SPICLK_FREQ)) - 1) begin
                        clk_inc        <= 0;
                        clk_controller <= zero;
                        clk_trig       <= 1'b1;
                    
                    end else begin
                        clk_trig <= 1'b0;

                    end
                end
            end
        endcase
    end
    
end


always @(posedge(clk)) begin: SPI_communication
    if (reset == 1'b1) begin
        main_proc   <= idle;
        clk_counter <=  0;
        go_proc     <= 1'b0;
        chip_sel    <= 1'b1;
        busy_flag   <= 1'b0;
        data_ready  <= 1'b1;        

    end else begin
        case(main_proc)
        init: begin
            data_ready   <= '0';                                                                                            // new data available flag                              
            if (data_in_v == 1'b1 && busy_flag == 1'b0) begin
                
                shift_reg_tx_1 <= data_in_1;                                                                                // update data to transmit  
                shift_reg_tx_2 <= data_in_2;                                                                                // update data to transmit          
                go_proc        <= 1'b1;                                                                                     // fsm state update
                busy_flag      <= 1'b1;                                                                                     // busy flag

            end else if (go_proc == 1'b1 && clk_trig == 1'b1 && clk_inc == (CLK_FREQ/(SPICLK_FREQ*2)) - 1) begin             // on the falling edge of clk_trig
                chip_sel                               <= 1'b0;                                                              // chip select
                main_proc                              <= start;
                go_proc                                <= 1'b0;   
                clk_counter                            <= clk_counter + 1;                         
                //input 1                       
                shift_reg_tx_1[WORD_LENGTH-1 downto 1] <= shift_reg_tx_1[WORD_LENGTH-2 downto 0];                           // update bit to transmit on mosi
                mosi_1                                 <= shift_reg_tx_1[WORD_LENGTH-1];                                    // bit transmission on mosi
                shift_reg_rx_1                         <= {shift_reg_rx_1[WORD_LENGTH-2 downto 0], miso_1};                 // update bit to receive on miso
                //input 2                     
                shift_reg_tx_2[WORD_LENGTH-1 downto 1] <= shift_reg_tx_2[WORD_LENGTH-2 downto 0];                           // update bit to transmit on mosi
                mosi_2                                 <= shift_reg_tx_2[WORD_LENGTH-1];                                    // bit transmission on mosi
                shift_reg_rx_2                         <= {shift_reg_rx_2[WORD_LENGTH-2 downto 0], miso_2};                 // update bit to receive on miso

            end else begin
                main_proc <= idle;
            end

        end


        start: begin
            
        end

        wait_cs: begin
            
        end

        endcase
        
    end
    
end


assign sclk = clk_trig;

endmodule