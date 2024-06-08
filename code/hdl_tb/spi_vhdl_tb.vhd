-- @title      SPI protocol specific for Intan RHS, testbench
-- @file       spi_vhdl_tb.vhd
-- @author     Mattia Di Florio
-- @date       11 aug 2022
-- @version    0.1
-- @copyright
-- © 2022 Mattia Di Florio <di.florio.mattia@gmail.com>
-- SPDX-License-Identifier: MIT License
--
-- @brief
-- SPI protocol tb for Intan RHS devices, CPOL = 0, CPHA = 0.
-- For more info, refer to Intan RHS2116 Datasheet
-- 
-- @changelog
-- > 


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity spi_vhdl_tb is
end;

architecture bench of spi_vhdl_tb is

    component spi_cust_generic

        generic ( CLK_FREQ    : natural;
                  WORD_LENGTH : natural;
                  SPICLK_FREQ : natural
                );

        port ( clk        : in  std_logic;                                    -- main clock
               reset      : in  std_logic;                                    -- reset button
               cs         : out std_logic;                                    -- chip select

               mosi_1     : out std_logic;                                    -- master out slave in input 1 
               miso_1     : in  std_logic;                                    -- master in slave out input 1
               mosi_2     : out std_logic;                                    -- master out slave in input 2 
               miso_2     : in  std_logic;                                    -- master in slave out

               sclk       : out std_logic;                                    -- SPI clock for communication

               -- interface
               data_in_v  : in  std_logic;                                   -- data to transmit validity
               ready_out  : out std_logic;                                   -- ready to get new data flag 
               data_out_v : out std_logic;                                   -- data received validity

               data_in_1  : in  std_logic_vector(WORD_LENGTH - 1 downto 0);  -- data to transmit 
               data_in_2  : in  std_logic_vector(WORD_LENGTH - 1 downto 0);  -- data to transmit
    
               data_out_1 : out std_logic_vector(WORD_LENGTH - 1 downto 0);  -- data received 
               data_out_2 : out std_logic_vector(WORD_LENGTH - 1 downto 0)   

            );

    end component;


    -- Clock period
    constant clk_period  : time    := 10 ns;
    -- Generics
    constant CLK_FREQ    : natural := 100000000;
    constant WORD_LENGTH : natural :=        32;
    constant SPICLK_FREQ : natural :=  25000000;

    constant COUNTER_MAX : natural := 1;                                                        -- a data is sent to SPI module each time counter reaches COUNTER_MAX
    

    -- Ports
    signal clk        : std_logic;
    signal reset      : std_logic;
    signal cs         : std_logic;
    signal mosi_1     : std_logic;
    signal mosi_2     : std_logic;

    signal miso_1     : std_logic;
    signal miso_2     : std_logic;

    signal sclk       : std_logic;
    signal data_in_1  : std_logic_vector(WORD_LENGTH - 1 downto 0) := (others => '0');
    signal data_in_2  : std_logic_vector(WORD_LENGTH - 1 downto 0) := (others => '0');

    signal data_in_v  : std_logic                                  := '1';
    signal ready_out  : std_logic;
    signal data_out_1 : std_logic_vector(WORD_LENGTH - 1 downto 0) := (others => '0');
    signal data_out_2 : std_logic_vector(WORD_LENGTH - 1 downto 0) := (others => '0');
    signal data_out_v : std_logic;

    signal data       : integer                        := 0;                                    -- input data 
    signal counter    : integer range 0 to COUNTER_MAX := COUNTER_MAX;                          -- counter to simulate a module which send data to SPI module


begin

  spi_protocol_inst : spi_vhdl

    generic map ( CLK_FREQ    => CLK_FREQ,
                  WORD_LENGTH => WORD_LENGTH,
                  SPICLK_FREQ => SPICLK_FREQ
                )

    port map ( clk        => clk,
               reset      => reset,
               cs         => cs,

               mosi_1     => mosi_1,
               miso_1     => miso_1,
               mosi_2     => mosi_2,
               miso_2     => miso_2,
               sclk       => sclk,

               -- interface
               data_in_v  => data_in_v,
               ready_out  => ready_out,
               data_out_v => data_out_v,

               data_in_1  => data_in_1,
               data_in_2  => data_in_2,
               data_out_1 => data_out_1,
               data_out_2 => data_out_2

             );


    clk_process : process   -- clock generation
    begin
        clk <= '1';
        wait for clk_period/2;
        clk <= '0';
        wait for clk_period/2;
    end process clk_process;

   
    data_tx : process(clk)  -- process to simulate input data to transmit via SPI
    begin
        if rising_edge(clk) then
            if counter < COUNTER_MAX then
                counter   <= counter + 1;
                data_in_v <= '0';

            elsif counter = COUNTER_MAX and data_in_v = '0' then
                data_in_1   <= std_logic_vector(to_unsigned(data, data_in_1'length));
                data_in_2   <= std_logic_vector(to_unsigned(data, data_in_2'length));
                data_in_v <= '1';

            elsif data_in_v = '1' and ready_out = '1' then
                if data < 150 then
                data <= data + 1;
                else
                data <= 0;
                end if;
                counter   <=  0;
                data_in_v <= '0';

            end if;
        end if;
    end process data_tx;


    -- this ensure to have always input data to retrieve on miso line 
    miso_1 <= mosi_1;   -- to simulate input data on miso line 1
    miso_2 <= mosi_2;   -- to simulate input data on miso line 2

    reset <= '1' after 0 ns, '0' after 30 ns;

end;
