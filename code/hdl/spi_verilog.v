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
#( parameter CLK_FREQ    = 100000000,                   // main clk default values
   parameter WORD_LENGTH =        32,                   // length of data for TX and RX
   parameter SPICLK_FREQ =  25000000                    // spi clk default value
)

( input wire clk,                                       // main clock
  input wire reset,                                     // reset signal
  output wire cs,                                       // chip select

  output reg  mosi_1,                                   // master out slave in output 1
  input  wire miso_1,                                   // master in slave out input 1
  output reg  mosi_2,                                   // master out slave in output 2
  input  wire miso_2,                                   // master in slave out input 1

  output wire sclk,                                     // SPI clock

  //interface
  input  wire data_in_v,                                // master in slave out input 1
  output wire ready_out,                                // ready to get new data to transmit
  output wire data_out_v,                               // data received validity, new data available flag

  input  wire [WORD_LENGTH-1:0] data_in_1,              // data to transmit over mosi_1
  input  wire [WORD_LENGTH-1:0] data_in_2,              // data to transmit over mosi_2

  output reg [WORD_LENGTH-1:0] data_out_1,              // data received from miso_1
  output reg [WORD_LENGTH-1:0] data_out_2               // data received from miso_2

);



parameter TCSOFF = 10;                                  // to guarantee at least a CS off time of 100 ns

// SPI clock state machine
parameter zero = 1'b0;                                  
parameter one  = 1'b1;                                  
reg     clk_controller;                                 

reg     clk_trig;                                       // trigger sclk
integer clk_inc;                                        // counter for sclk generation

// main state machine for data TX and RX
parameter idle    = 2'b00;                              
parameter start   = 2'b01;                              
parameter wait_cs = 2'b10;                              
reg [1:0] main_proc;                                    

integer   clk_counter;                                  // counter for data transmission/reception
integer   cs_counter = 0;                               // counter for tcsoff
reg       go_proc;                                      
reg       chip_sel;                                     // chip select
reg       busy_flag;                                    // SPI module busy flag
reg       data_ready;                                   // new data available flag

reg [WORD_LENGTH-1:0] shift_reg_tx_1;                   // shift register transmitter 
reg [WORD_LENGTH-1:0] shift_reg_tx_2;                   // shift register transmitter 
reg [WORD_LENGTH-1:0] shift_reg_rx_1;                   // shift register receiver 
reg [WORD_LENGTH-1:0] shift_reg_rx_2;                   //shift register receiver 



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
        idle: begin
            data_ready   <= 1'b0;                                                                                           // new data available flag                              
            if (data_in_v == 1'b1 && busy_flag == 1'b0) begin
                
                shift_reg_tx_1 <= data_in_1;                                                                                // update data to transmit  
                shift_reg_tx_2 <= data_in_2;                                                                                // update data to transmit          
                go_proc        <= 1'b1;                                                                                     // fsm state update
                busy_flag      <= 1'b1;                                                                                     // busy flag

            end else if (go_proc == 1'b1 && clk_trig == 1'b1 && clk_inc == (CLK_FREQ/(SPICLK_FREQ*2)) - 1) begin            // on the falling edge of clk_trig
                chip_sel                        <= 1'b0;                                                                    // chip select
                main_proc                       <= start;
                go_proc                         <= 1'b0;   
                clk_counter                     <= clk_counter + 1;                         
                //input 1                       
                shift_reg_tx_1[WORD_LENGTH-1:1] <= shift_reg_tx_1[WORD_LENGTH-2:0];                                     	// update bit to transmit on mosi
                mosi_1                          <= shift_reg_tx_1[WORD_LENGTH-1];                                       	// bit transmission on mosi
                shift_reg_rx_1                  <= {shift_reg_rx_1[WORD_LENGTH-2:0], miso_1};                           	// update bit to receive on miso
                //input 2                     
                shift_reg_tx_2[WORD_LENGTH-1:1] <= shift_reg_tx_2[WORD_LENGTH-2:0];                                         // update bit to transmit on mosi
                mosi_2                          <= shift_reg_tx_2[WORD_LENGTH-1];                                           // bit transmission on mosi
                shift_reg_rx_2                  <= {shift_reg_rx_2[WORD_LENGTH-2:0], miso_2};                               // update bit to receive on miso

            end else begin
                main_proc <= idle;
            end
        end


        start: begin
            if (clk_inc == ((CLK_FREQ/(SPICLK_FREQ)) - (CLK_FREQ/(SPICLK_FREQ*2))) - 1) begin                               // to guarantee cpha = 0
                if (clk_counter == WORD_LENGTH) begin                                                                       // if all the bits have been transmitted/received end communication
                    main_proc                       <= wait_cs;
                    clk_counter                     <=  0;                                                                  // count the number of bits transmitted
                    //input 1                       
                    shift_reg_tx_1[WORD_LENGTH-1:1] <= shift_reg_tx_1[WORD_LENGTH-2:0];                                     // update bit to transmit on mosi
                    mosi_1                          <= shift_reg_tx_1[WORD_LENGTH-1];                                       // bit transmission on mosi
                    shift_reg_rx_1                  <= {shift_reg_rx_1[WORD_LENGTH-2:0], miso_1};                           // update bit to receive on miso
                    //input 2                     
                    shift_reg_tx_2[WORD_LENGTH-1:1] <= shift_reg_tx_2[WORD_LENGTH-2:0];                                     // update bit to transmit on mosi
                    mosi_2                          <= shift_reg_tx_2[WORD_LENGTH-1];                                       // bit transmission on mosi
                    shift_reg_rx_2                  <= {shift_reg_rx_2[WORD_LENGTH-2:0], miso_2};                           // update bit to receive on miso

                end else begin
                    main_proc                       <= start;
                    clk_counter                     <= clk_counter + 1;                                                
                    //input 1                       
                    shift_reg_tx_1[WORD_LENGTH-1:1] <= shift_reg_tx_1[WORD_LENGTH-2:0];                                     // update bit to transmit on mosi
                    mosi_1                          <= shift_reg_tx_1[WORD_LENGTH-1];                                       // bit transmission on mosi
                    shift_reg_rx_1                  <= {shift_reg_rx_1[WORD_LENGTH-2:0], miso_1};                           // update bit to receive on miso
                    //input 2                     
                    shift_reg_tx_2[WORD_LENGTH-1:1] <= shift_reg_tx_2[WORD_LENGTH-2:0];                                     // update bit to transmit on mosi
                    mosi_2                          <= shift_reg_tx_2[WORD_LENGTH-1];                                       // bit transmission on mosi
                    shift_reg_rx_2                  <= {shift_reg_rx_2[WORD_LENGTH-2:0], miso_2};                           // update bit to receive on miso

                end;
            end;
        end

        wait_cs: begin
            if (clk_trig == 1'b0 && clk_inc == (CLK_FREQ/(SPICLK_FREQ)) - 1 && chip_sel == 1'b0) begin                      // guarantee simmetry between high/low transition of chip select
                chip_sel <= 1'b1;

            end else if (cs_counter < TCSOFF - 4 && chip_sel == 1'b1) begin                                                 // to guarantee tcsoff 
                cs_counter <= cs_counter + 1;                                                                               // increment tcsoff counter
            
            end else if (cs_counter == TCSOFF - 4 && chip_sel == 1'b1) begin                   
                cs_counter <=  0;
                busy_flag  <= 1'b0;
                main_proc  <= idle;
                data_out_1 <= shift_reg_rx_1;                                                                               // output received data
                data_out_2 <= shift_reg_rx_2;                                                                               // output received data
                data_ready <= 1'b1;                                                                                         // received data validity flag

            end;
        end
        endcase
    end
end


assign sclk       = (chip_sel == 1'b0) ? clk_trig : 1'b0;   	// output SPI clock 
assign cs         = chip_sel;                                   // output chip select
assign ready_out  = !busy_flag;                                 // SPI ready for new operation
assign data_out_v = data_ready;                                 // new data available


endmodule