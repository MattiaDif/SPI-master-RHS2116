-- @title      SPI protocol specific for Intan RHS, multi MISO/MOSI
-- @category   interface
-- @file       spi_vhdl.vhd
-- @author     Mattia Di Florio
-- @date       10 aug 2022
-- @version    0.1
-- @copyright
-- © 2022 Mattia Di Florio <di.florio.mattia@gmail.com>
-- SPDX-License-Identifier: MIT License
--
-- @brief
-- SPI protocol specific for Intan RHS2116 chip, CPOL = 0, CPHA = 0.
-- For more info, refer to Intan RHS2116 Datasheet
-- 
-- @changelog
-- > 


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;


entity spi_vhdl is

    generic ( CLK_FREQ    : natural := 100000000;                           -- main clk default value
              WORD_LENGTH : natural :=        32;                           -- length of data for TX and RX
              SPICLK_FREQ : natural :=  25000000                            -- spi clk default value
            );


    port ( clk        : in  std_logic;                                      -- main clock
           reset      : in  std_logic;                                      -- reset signal
           cs         : out std_logic;                                      -- chip select

           mosi_1     : out std_logic;                                      -- master out slave in output 1
           miso_1     : in  std_logic;                                      -- master in slave out input 1
           mosi_2     : out std_logic;                                      -- master out slave in output 2 
           miso_2     : in  std_logic;                                      -- master in slave out input 2

           sclk       : out std_logic;                                      -- SPI clock

           -- interface
           data_in_v  : in  std_logic;                                      -- master in slave out input 1
           ready_out  : out std_logic;                                      -- ready to get new data to transmit
           data_out_v : out std_logic;                                      -- data received validity, new data available flag

           data_in_1  : in  std_logic_vector(WORD_LENGTH - 1 downto 0);     -- data to transmit over mosi_1
           data_in_2  : in  std_logic_vector(WORD_LENGTH - 1 downto 0);     -- data to transmit over mosi_2

           data_out_1 : out std_logic_vector(WORD_LENGTH - 1 downto 0);     -- data received from miso_1
           data_out_2 : out std_logic_vector(WORD_LENGTH - 1 downto 0)      -- data received from miso_2

         );

end spi_vhdl;

architecture Behavioral of spi_vhdl is

    constant TCSOFF      : natural := 10;                                                       -- to guarantee at least a CS off time of 100 ns
                                                                                                -- N*clk --> if N = 10 and clk = 100MHz, CS off time is 100 ns
    
    type clk_gen is (zero,
                     one
                    );

    type main_machine is (idle,                                                                
                          start,
                          wait_cs                                                              
                         );
    
    signal clk_controller : clk_gen;                                                            -- state machine for spi clk generation
    signal main_proc      : main_machine := idle;                                               -- state machine for main processing

    signal clk_inc        : integer range 0 to (CLK_FREQ/(SPICLK_FREQ)) - 1;                    -- counter for sclk generation
    signal clk_counter    : integer range 0 to WORD_LENGTH;                                     -- counter for data transmission/reception

    signal clk_trig       : std_logic;                                                          -- trigger sclk
    signal chip_sel       : std_logic := '1';                                                   -- chip select

    signal busy_flag      : std_logic := '0';                                                   -- SPI module busy flag
    signal data_ready     : std_logic := '1';                                                   -- new data available flag
    
    signal shift_reg_tx_1 : std_logic_vector(WORD_LENGTH - 1 downto 0) := (others => '0');      -- shift register transmitter 
    signal shift_reg_tx_2 : std_logic_vector(WORD_LENGTH - 1 downto 0) := (others => '0');      -- shift register transmitter

    signal shift_reg_rx_1 : std_logic_vector(WORD_LENGTH - 1 downto 0) := (others => '0');      -- shift register receiver 
    signal shift_reg_rx_2 : std_logic_vector(WORD_LENGTH - 1 downto 0) := (others => '0');      -- shift register receiver 


    signal cs_counter     : integer range 0 to TCSOFF := 0;                                     -- counter for tcsoff
    signal go_proc        : std_logic;


begin

    -- SPI clock (sclk) generation
    clk_generation : process(clk) 
    begin
        if rising_edge(clk) then
            if reset = '1' then
                clk_controller <= zero;
                clk_trig       <= '0';
                clk_inc        <=  0;
            
            else 
                case clk_controller is
                    when zero =>
                        if clk_inc < ((CLK_FREQ/(SPICLK_FREQ))/2) then
                            clk_inc <= clk_inc + 1;
                            
                            if clk_inc = ((CLK_FREQ/(SPICLK_FREQ))/2) - 1 then
                                clk_controller <= one;
                                clk_trig <= '0';
                            
                            else
                                clk_trig <= '1';

                            end if;                        
                        end if;
                    
                    when one =>
                        if clk_inc < (CLK_FREQ/(SPICLK_FREQ)) then
                            clk_inc <= clk_inc + 1;

                            if clk_inc = (CLK_FREQ/(SPICLK_FREQ)) - 1 then
                                clk_inc        <= 0;
                                clk_controller <= zero;
                                clk_trig       <= '1';
                            
                            else
                                clk_trig <= '0';

                            end if; 
                        end if;
                    end case;       
            end if;
        end if;
    end process clk_generation;


    -- main state machine for spi tx/rx
    SPI_communication : process(clk) 
    begin
        if rising_edge(clk) then
            if reset = '1' then
                main_proc   <= idle;
                clk_counter <=  0;
                go_proc     <= '0';
                chip_sel    <= '1';
                busy_flag   <= '0';
                data_ready  <= '1';

            else                                                
                case main_proc is
                    when idle =>   
                    data_ready   <= '0';                                                                                            -- new data available flag                              
                    if data_in_v = '1' and busy_flag = '0' then   
                        shift_reg_tx_1 <= data_in_1;                                                                                -- update data to transmit  
                        shift_reg_tx_2 <= data_in_2;                                                                                -- update data to transmit          
                        go_proc        <= '1';                                                                                      -- fsm state update
                        busy_flag      <= '1';                                                                                      -- busy flag

                    elsif go_proc = '1' and clk_trig = '1' and clk_inc = (CLK_FREQ/(SPICLK_FREQ*2)) - 1 then                        -- on the falling edge of clk_trig
                        chip_sel                               <= '0';                                                              -- chip select
                        main_proc                              <= start;
                        go_proc                                <= '0';   
                        clk_counter                            <= clk_counter + 1;                         
                        --input 1                       
                        shift_reg_tx_1(WORD_LENGTH-1 downto 1) <= shift_reg_tx_1(WORD_LENGTH-2 downto 0);                           -- update bit to transmit on mosi
                        mosi_1                                 <= shift_reg_tx_1(WORD_LENGTH-1);                                    -- bit transmission on mosi
                        shift_reg_rx_1                         <= shift_reg_rx_1(WORD_LENGTH-2 downto 0) & miso_1;                  -- update bit to receive on miso
                        --input 2                       
                        shift_reg_tx_2(WORD_LENGTH-1 downto 1) <= shift_reg_tx_2(WORD_LENGTH-2 downto 0);                           -- update bit to transmit on mosi
                        mosi_2                                 <= shift_reg_tx_2(WORD_LENGTH-1);                                    -- bit transmission on mosi
                        shift_reg_rx_2                         <= shift_reg_rx_2(WORD_LENGTH-2 downto 0) & miso_2;                  -- update bit to receive on miso

                    else
                        main_proc <= idle;

                    end if;
                                            
                    when start => 
                    if clk_inc = ((CLK_FREQ/(SPICLK_FREQ)) - (CLK_FREQ/(SPICLK_FREQ*2))) - 1 then                                   -- to guarantee cpha = 0
                        if clk_counter = WORD_LENGTH then                                                                           -- if all the bits have been transmitted/received end communication
                            main_proc                              <= wait_cs;
                            clk_counter                            <=  0;                                                           -- count the number of bits transmitted
                            --input 1                       
                            shift_reg_tx_1(WORD_LENGTH-1 downto 1) <= shift_reg_tx_1(WORD_LENGTH-2 downto 0);                       -- update bit to transmit on mosi
                            mosi_1                                 <= shift_reg_tx_1(WORD_LENGTH-1);                                -- bit transmission on mosi
                            shift_reg_rx_1                         <= shift_reg_rx_1(WORD_LENGTH-2 downto 0) & miso_1;              -- update bit to receive on miso
                            --input 2                       
                            shift_reg_tx_2(WORD_LENGTH-1 downto 1) <= shift_reg_tx_2(WORD_LENGTH-2 downto 0);                       -- update bit to transmit on mosi
                            mosi_2                                 <= shift_reg_tx_2(WORD_LENGTH-1);                                -- bit transmission on mosi
                            shift_reg_rx_2                         <= shift_reg_rx_2(WORD_LENGTH-2 downto 0) & miso_2;              -- update bit to receive on miso
    
                        else
                            main_proc                              <= start;
                            clk_counter                            <= clk_counter + 1;                                                
                            --input 1                       
                            shift_reg_tx_1(WORD_LENGTH-1 downto 1) <= shift_reg_tx_1(WORD_LENGTH-2 downto 0);                       -- update bit to transmit on mosi
                            mosi_1                                 <= shift_reg_tx_1(WORD_LENGTH-1);                                -- bit transmission on mosi
                            shift_reg_rx_1                         <= shift_reg_rx_1(WORD_LENGTH-2 downto 0) & miso_1;              -- update bit to receive on miso
                            --input 2                       
                            shift_reg_tx_2(WORD_LENGTH-1 downto 1) <= shift_reg_tx_2(WORD_LENGTH-2 downto 0);                       -- update bit to transmit on mosi
                            mosi_2                                 <= shift_reg_tx_2(WORD_LENGTH-1);                                -- bit transmission on mosi
                            shift_reg_rx_2                         <= shift_reg_rx_2(WORD_LENGTH-2 downto 0) & miso_2;              -- update bit to receive on miso

                        end if;
                    end if;

                    when wait_cs =>
                        if clk_trig = '0' and clk_inc = (CLK_FREQ/(SPICLK_FREQ)) - 1 and chip_sel = '0' then                        -- guarantee simmetry between high/low transition of chip select
                            chip_sel <= '1';

                        elsif cs_counter < TCSOFF - 4 and chip_sel = '1' then                                                       -- to guarantee tcsoff 
                            cs_counter <= cs_counter + 1;                                                                           -- increment tcsoff counter
                        
                        elsif cs_counter = TCSOFF - 4 and chip_sel = '1' then                   
                            cs_counter <=  0;
                            busy_flag  <= '0';
                            main_proc  <= idle;
                            data_out_1 <= shift_reg_rx_1;                                                                            -- output received data
                            data_out_2 <= shift_reg_rx_2;                                                                            -- output received data
                            data_ready <= '1';                                                                                       -- received data validity flag

                        end if;
                end case;
            end if;
        end if;
    end process SPI_communication;


    cs         <= chip_sel;                               -- output chip select
    sclk       <= clk_trig when chip_sel = '0' else '0';  -- output SPI clock 
    ready_out  <= not busy_flag;                          -- SPI ready for new operation
    data_out_v <= data_ready;                             -- new data available


end Behavioral;
