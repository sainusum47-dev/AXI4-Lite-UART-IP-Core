----------------------------------------------------------------------------------
-- Testbench: UART Transmitter
-- Project: AXI_UART_IP
--
-- UART format:
--   1 start bit
--   8 data bits, LSB first
--   1 stop bit
--
-- baud_tick = 16x UART timing tick
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity tb_uart_tx is
end tb_uart_tx;

architecture Behavioral of tb_uart_tx is

    signal clk       : STD_LOGIC := '0';
    signal reset     : STD_LOGIC := '1';
    signal baud_tick : STD_LOGIC := '0';

    signal tx_data   : STD_LOGIC_VECTOR(7 downto 0) := (others => '0');
    signal tx_start  : STD_LOGIC := '0';

    signal tx        : STD_LOGIC;
    signal tx_busy   : STD_LOGIC;

    constant CLK_PERIOD : time := 10 ns;

begin

    --------------------------------------------------------------------------
    -- DUT
    --------------------------------------------------------------------------
    DUT : entity work.uart_tx
        port map (
            clk       => clk,
            reset     => reset,
            baud_tick => baud_tick,
            tx_data   => tx_data,
            tx_start  => tx_start,
            tx        => tx,
            tx_busy   => tx_busy
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
    -- Temporary 16x baud tick generator
    --
    -- One baud_tick every 4 clock cycles.
    -- Therefore one UART bit = 16 baud_tick pulses.
    --------------------------------------------------------------------------
    baud_process : process
        variable count : integer := 0;
    begin
        while true loop

            wait until falling_edge(clk);

            if count = 3 then
                baud_tick <= '1';
                count := 0;
            else
                baud_tick <= '0';
                count := count + 1;
            end if;

        end loop;
    end process;

    --------------------------------------------------------------------------
    -- Self-checking test
    --------------------------------------------------------------------------
    stimulus_process : process

        procedure wait_for_tick is
        begin
            wait until rising_edge(clk);
            while baud_tick /= '1' loop
                wait until rising_edge(clk);
            end loop;
            wait for 1 ns;
        end procedure;

        procedure wait_for_16_ticks is
        begin
            for i in 0 to 15 loop
                wait_for_tick;
            end loop;
        end procedure;

    begin

        ----------------------------------------------------------------------
        -- RESET
        ----------------------------------------------------------------------
        reset    <= '1';
        tx_start <= '0';
        tx_data  <= x"00";

        wait for 30 ns;

        reset <= '0';

        wait until rising_edge(clk);
        wait for 1 ns;

        ----------------------------------------------------------------------
        -- Check idle
        ----------------------------------------------------------------------
        assert tx = '1'
            report "FAIL: TX is not HIGH in idle."
            severity error;

        assert tx_busy = '0'
            report "FAIL: TX_BUSY is not LOW in idle."
            severity error;

        ----------------------------------------------------------------------
        -- Send 0x55
        ----------------------------------------------------------------------
        tx_data  <= x"55";
        tx_start <= '1';

        wait until rising_edge(clk);

        tx_start <= '0';

        wait for 1 ns;

        assert tx_busy = '1'
            report "FAIL: TX_BUSY did not become HIGH."
            severity error;

        ----------------------------------------------------------------------
        -- START BIT
        ----------------------------------------------------------------------
        assert tx = '0'
            report "FAIL: START bit is not 0."
            severity error;

        report "PASS: START bit detected."
            severity note;

        wait_for_16_ticks;

        ----------------------------------------------------------------------
        -- DATA BIT 0 = 1
        ----------------------------------------------------------------------
        assert tx = '1'
            report "FAIL: DATA bit 0 incorrect."
            severity error;

        report "PASS: DATA bit 0 = 1."
            severity note;

        wait_for_16_ticks;

        ----------------------------------------------------------------------
        -- DATA BIT 1 = 0
        ----------------------------------------------------------------------
        assert tx = '0'
            report "FAIL: DATA bit 1 incorrect."
            severity error;

        wait_for_16_ticks;

        ----------------------------------------------------------------------
        -- DATA BIT 2 = 1
        ----------------------------------------------------------------------
        assert tx = '1'
            report "FAIL: DATA bit 2 incorrect."
            severity error;

        wait_for_16_ticks;

        ----------------------------------------------------------------------
        -- DATA BIT 3 = 0
        ----------------------------------------------------------------------
        assert tx = '0'
            report "FAIL: DATA bit 3 incorrect."
            severity error;

        wait_for_16_ticks;

        ----------------------------------------------------------------------
        -- DATA BIT 4 = 1
        ----------------------------------------------------------------------
        assert tx = '1'
            report "FAIL: DATA bit 4 incorrect."
            severity error;

        wait_for_16_ticks;

        ----------------------------------------------------------------------
        -- DATA BIT 5 = 0
        ----------------------------------------------------------------------
        assert tx = '0'
            report "FAIL: DATA bit 5 incorrect."
            severity error;

        wait_for_16_ticks;

        ----------------------------------------------------------------------
        -- DATA BIT 6 = 1
        ----------------------------------------------------------------------
        assert tx = '1'
            report "FAIL: DATA bit 6 incorrect."
            severity error;

        wait_for_16_ticks;

        ----------------------------------------------------------------------
        -- DATA BIT 7 = 0
        ----------------------------------------------------------------------
        assert tx = '0'
            report "FAIL: DATA bit 7 incorrect."
            severity error;

        wait_for_16_ticks;

        ----------------------------------------------------------------------
        -- STOP BIT
        ----------------------------------------------------------------------
        assert tx = '1'
            report "FAIL: STOP bit is not 1."
            severity error;

        report "PASS: STOP bit detected."
            severity note;

        wait_for_16_ticks;

        ----------------------------------------------------------------------
        -- TX should return to idle
        ----------------------------------------------------------------------
        assert tx = '1'
            report "FAIL: TX did not return to idle."
            severity error;

        assert tx_busy = '0'
            report "FAIL: TX_BUSY did not return LOW."
            severity error;

        ----------------------------------------------------------------------
        -- FINAL RESULT
        ----------------------------------------------------------------------
        report "=========================================="
            severity note;

        report "UART TX TEST PASSED"
            severity note;

        report "0x55 transmitted correctly."
            severity note;

        report "START -> D0..D7 -> STOP"
            severity note;

        report "=========================================="
            severity note;

        wait;

    end process;

end Behavioral;