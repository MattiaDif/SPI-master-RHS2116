# SPI-master-RHS2116
SPI logic to interface with the RHS2116 chip ([link](https://intantech.com/RHS_headstages.html?tabSelect=RHS32ch)), for FPGA. 

Info:
- CPOL = 0 
- CPHA = 0

For detailed information about the SPI requirements, refer to Intan RHS2116 documentation: [datasheet](https://intantech.com/downloads.html?tabSelect=Datasheets).
<br />

The SPI has been validated for an FPGA architecture running at 100MHz, and it has been optimized to match the chip specification and to allow SPI clock frequency customization. Since the SPI logic has been designed for RHS2116 chip, it works with clock polarity (CPOL) and clock phase (CPHA) equal to 0.
<br />

## Installation

To clone this repo open your terminal and run:

`git clone https://github.com/MattiaDif/SPI-master-RHS2116.git`

## REFERENCE
If you use this repo, please cite:

"Di Florio, M. SPI-master-RHS2116 (Version 0.2) [Computer software]. https://github.com/MattiaDif/SPI-master-RHS2116"

## Notes
To contribute refers to the *dev* branch!
