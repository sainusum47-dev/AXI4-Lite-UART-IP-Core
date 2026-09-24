----------------------------------------------------------------------------------
-- Company:
-- Engineer:
--
-- Create Date: 17.09.2026
-- Design Name: AXI4-Lite UART IP Core
-- Module Name: uart_baud_gen
-- Project Name: AXI_UART_IP
-- Target Devices: xc7a35tcpg236-1
-- Tool Versions: Vivado 2026.1
--
-- Description:
-- Generates a periodic baud_tick from the system clock.
--
-- First implementation:
-- Integer clock divider.
--
-- Example:
-- Clock     = 100 MHz
-- baud_div  = 54
--
-- Later versions can use fractional baud-rate generation.
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity uart_baud_gen is
    Port (
        clk       : in  STD_LOGIC;
        reset     : in  STD_LOGIC;
        baud_div  : in  STD_LOGIC_VECTOR (15 downto 0);
        baud_tick : out STD_LOGIC
    );
end uart_baud_gen;

architecture Behavioral of uart_baud_gen is

    -- Counter used to divide the system clock.
    signal counter : unsigned(15 downto 0) := (others => '0');

begin

    process(clk)
    begin
        if rising_edge(clk) then

            -- Reset counter and output.
            if reset = '1' then
                counter   <= (others => '0');
                baud_tick <= '0';

            else
                -- Protect against an invalid divider value of zero.
                if unsigned(baud_div) = 0 then
                    counter   <= (others => '0');
                    baud_tick <= '1';

                -- Generate one clock-cycle baud tick.
                elsif counter = unsigned(baud_div) - 1 then
                    counter   <= (others => '0');
                    baud_tick <= '1';

                else
                    counter   <= counter + 1;
                    baud_tick <= '0';
                end if;
            end if;

        end if;
    end process;

end Behavioral;