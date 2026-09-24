----------------------------------------------------------------------------------
-- Testbench: UART Baud Rate Generator
-- Project: AXI_UART_IP
--
-- Purpose:
-- Verifies that uart_baud_gen produces baud_tick at the expected interval.
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_uart_baud_gen is
end tb_uart_baud_gen;

architecture Behavioral of tb_uart_baud_gen is

    -- DUT signals
    signal clk       : STD_LOGIC := '0';
    signal reset     : STD_LOGIC := '1';
    signal baud_div  : STD_LOGIC_VECTOR(15 downto 0) := x"0004";
    signal baud_tick : STD_LOGIC;

    constant CLK_PERIOD : time := 10 ns;

begin

    --------------------------------------------------------------------------
    -- DUT
    --------------------------------------------------------------------------
    DUT : entity work.uart_baud_gen
        port map (
            clk       => clk,
            reset     => reset,
            baud_div  => baud_div,
            baud_tick => baud_tick
        );

    --------------------------------------------------------------------------
    -- 100 MHz clock
    --------------------------------------------------------------------------
    clk_process : process
    begin
        while true loop
            clk <= '0';
            wait for CLK_PERIOD / 2;

            clk <= '1';
            wait for CLK_PERIOD / 2;
        end loop;
    end process;

    --------------------------------------------------------------------------
    -- Stimulus and self-checking process
    --------------------------------------------------------------------------
    stimulus_process : process
        variable tick_count : integer := 0;
    begin

        ----------------------------------------------------------------------
        -- Apply reset
        ----------------------------------------------------------------------
        reset <= '1';

        wait for 30 ns;

        ----------------------------------------------------------------------
        -- Release reset
        ----------------------------------------------------------------------
        reset <= '0';

        ----------------------------------------------------------------------
        -- Observe 20 clock cycles
        ----------------------------------------------------------------------
        for i in 0 to 19 loop

            wait until rising_edge(clk);

            -- Allow DUT signal assignments to update.
            wait for 1 ns;

            if baud_tick = '1' then
                tick_count := tick_count + 1;

                report "BAUD TICK detected at "
                       & time'image(now)
                       severity note;
            end if;

        end loop;

        ----------------------------------------------------------------------
        -- Check result
        --
        -- baud_div = 4
        -- 20 clock cycles / 4 = 5 expected ticks
        ----------------------------------------------------------------------
        if tick_count = 5 then

            report "TEST PASSED: Baud generator produced 5 expected ticks."
                severity note;

        else

            assert false
                report "TEST FAILED: Expected 5 baud ticks, got "
                       & integer'image(tick_count)
                severity error;

        end if;

        wait;

    end process;

end Behavioral;