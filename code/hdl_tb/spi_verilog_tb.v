`include spi_verilog.v`

module spi_verilog_tb ()

parameter SPI_MODE = 3;


logic r_Rst_L = 1'b0;
logic w_SPI_Clk;