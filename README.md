# SPI-master-RHS2116
SPI logic to interface with the RHS2116 chip ([link](https://intantech.com/RHS_headstages.html?tabSelect=RHS32ch)), for FPGA. 

Info:
- CPOL = 0 
- CPHA = 0

For detailed information about the SPI requirements, refer to Intan RHS2116 documentation: [datasheet](https://intantech.com/downloads.html?tabSelect=Datasheets).

The SPI has been validated for an FPGA architecture running at 100MHz, and it has been optimized to match the chip specification and to allow SPI clock frequency customization. Since the SPI logic has been designed for RHS2116 chip, it works with clock polarity (CPOL) ans clock phase (CPHA) equal to 0.

### NOTES
The current state of the work provides VHDL code. I'm planning to upload the Verilog version. 

To contribute refers to the dev branch! Thanks and see you around! :)
