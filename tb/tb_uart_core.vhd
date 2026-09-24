----------------------------------------------------------------------------------
-- Testbench: UART Core
-- Project: AXI_UART_IP
--
-- End-to-end loopback verification
--
-- Test path:
--   TX interface
--      ↓
--   TX FIFO
--      ↓
--   UART TX
--      ↓
--      tx
--      ↓
--      rx
--      ↓
--   UART RX
--      ↓
--   RX FIFO
--      ↓
--   RX interface
--
-- UART:
--   8 data bits
--   No parity
--   1 stop bit
--   LSB first
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_uart_core is
end tb_uart_core;

architecture Behavioral of tb_uart_core is

    --------------------------------------------------------------------------
    -- Clock
    --------------------------------------------------------------------------
    signal clk : STD_LOGIC := '0';

    constant CLK_PERIOD : time := 10 ns;

    --------------------------------------------------------------------------
    -- Reset
    --------------------------------------------------------------------------
    signal reset : STD_LOGIC := '1';

    --------------------------------------------------------------------------
    -- Baud divider
    --------------------------------------------------------------------------
    signal baud_div : STD_LOGIC_VECTOR(15 downto 0) := x"0004";

    --------------------------------------------------------------------------
    -- TX interface
    --------------------------------------------------------------------------
    signal tx_data_in : STD_LOGIC_VECTOR(7 downto 0) := x"00";
    signal tx_write   : STD_LOGIC := '0';

    signal tx_full  : STD_LOGIC;
    signal tx_empty : STD_LOGIC;
    signal tx_busy  : STD_LOGIC;

    --------------------------------------------------------------------------
    -- RX interface
    --------------------------------------------------------------------------
    signal rx_data_out : STD_LOGIC_VECTOR(7 downto 0);
    signal rx_read     : STD_LOGIC := '0';

    signal rx_empty : STD_LOGIC;
    signal rx_full  : STD_LOGIC;
    signal rx_valid : STD_LOGIC;

    signal frame_error : STD_LOGIC;

    --------------------------------------------------------------------------
    -- UART pins
    --------------------------------------------------------------------------
    signal tx : STD_LOGIC;
    signal rx : STD_LOGIC := '1';

begin

    --------------------------------------------------------------------------
    -- LOOPBACK
    --------------------------------------------------------------------------
    rx <= tx;

    --------------------------------------------------------------------------
    -- DUT
    --------------------------------------------------------------------------
    DUT : entity work.uart_core
        port map (
            clk         => clk,
            reset       => reset,

            baud_div    => baud_div,

            tx_data_in  => tx_data_in,
            tx_write    => tx_write,
            tx_full     => tx_full,
            tx_empty    => tx_empty,
            tx_busy     => tx_busy,

            rx_data_out => rx_data_out,
            rx_read     => rx_read,
            rx_empty    => rx_empty,
            rx_full     => rx_full,
            rx_valid    => rx_valid,
            frame_error => frame_error,

            tx          => tx,
            rx          => rx
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
    -- MAIN TEST
    --------------------------------------------------------------------------
    stimulus_process : process

        variable rx_data_seen : boolean := false;
        variable tx_done_seen : boolean := false;

    begin

        ----------------------------------------------------------------------
        -- RESET
        ----------------------------------------------------------------------
        reset <= '1';

        tx_write <= '0';
        rx_read  <= '0';

        tx_data_in <= x"00";

        wait for 50 ns;

        reset <= '0';

        wait for 20 ns;

        ----------------------------------------------------------------------
        -- INITIAL CHECKS
        ----------------------------------------------------------------------

        assert tx_full = '0'
            report "FAIL: TX FIFO unexpectedly FULL after reset."
            severity error;

        assert tx_empty = '1'
            report "FAIL: TX FIFO is not EMPTY after reset."
            severity error;

        assert rx_empty = '1'
            report "FAIL: RX FIFO is not EMPTY after reset."
            severity error;

        assert tx = '1'
            report "FAIL: TX line is not HIGH during idle."
            severity error;

        assert tx_busy = '0'
            report "FAIL: TX_BUSY is not LOW during idle."
            severity error;

        report "PASS: UART core reset and idle checks."
            severity note;

        ----------------------------------------------------------------------
        -- WRITE 0x55 INTO TX FIFO
        ----------------------------------------------------------------------

        tx_data_in <= x"55";
        tx_write   <= '1';

        wait until rising_edge(clk);
        wait for 1 ns;

        tx_write <= '0';

        report "PASS: 0x55 written to TX interface."
            severity note;

        ----------------------------------------------------------------------
        -- WAIT FOR RX FIFO TO RECEIVE DATA
        --
        -- Maximum wait = 20 us.
        ----------------------------------------------------------------------

        for i in 0 to 1999 loop

            wait until rising_edge(clk);
            wait for 1 ns;

            if rx_empty = '0' then

                rx_data_seen := true;

                exit;

            end if;

        end loop;

        ----------------------------------------------------------------------
        -- CHECK RX FIFO RECEIVED A BYTE
        ----------------------------------------------------------------------

        assert rx_data_seen
            report "FAIL: RX FIFO did not receive data within timeout."
            severity error;

        ----------------------------------------------------------------------
        -- CHECK FRAME ERROR
        ----------------------------------------------------------------------

        assert frame_error = '0'
            report "FAIL: UART frame error detected."
            severity error;

        ----------------------------------------------------------------------
        -- READ RX FIFO
        ----------------------------------------------------------------------

        rx_read <= '1';

        wait until rising_edge(clk);
        wait for 1 ns;

        rx_read <= '0';

        ----------------------------------------------------------------------
        -- CHECK RECEIVED DATA
        ----------------------------------------------------------------------

        assert rx_data_out = x"55"
            report "FAIL: UART core received incorrect data. Expected 0x55."
            severity error;

        report "PASS: 0x55 received correctly through RX FIFO."
            severity note;

        ----------------------------------------------------------------------
        -- RX FIFO SHOULD NOW BE EMPTY
        ----------------------------------------------------------------------

        assert rx_empty = '1'
            report "FAIL: RX FIFO should be EMPTY after reading the byte."
            severity error;

        ----------------------------------------------------------------------
        -- IMPORTANT:
        --
        -- Do not immediately check TX_BUSY.
        --
        -- RX can finish slightly before TX has completed its final
        -- transmission timing.
        --
        -- Wait until TX_BUSY actually becomes LOW.
        ----------------------------------------------------------------------

        for i in 0 to 1999 loop

            wait until rising_edge(clk);
            wait for 1 ns;

            if tx_busy = '0' then

                tx_done_seen := true;

                exit;

            end if;

        end loop;

        ----------------------------------------------------------------------
        -- CHECK TX COMPLETION
        ----------------------------------------------------------------------

        assert tx_done_seen
            report "FAIL: TX_BUSY did not return LOW within timeout."
            severity error;

        assert tx = '1'
            report "FAIL: TX line is not HIGH after transmission."
            severity error;

        report "PASS: TX transmission completed."
            severity note;

        ----------------------------------------------------------------------
        -- FINAL RESULT
        ----------------------------------------------------------------------

        if rx_data_seen and
           (rx_data_out = x"55") and
           (frame_error = '0') and
           (rx_empty = '1') and
           tx_done_seen and
           (tx = '1') then

            report "=========================================="
                severity note;

            report "UART CORE TEST PASSED"
                severity note;

            report "TX FIFO -> UART TX -> UART RX -> RX FIFO"
                severity note;

            report "0x55 transmitted and received correctly."
                severity note;

            report "RX FIFO readback: PASS"
                severity note;

            report "TX completion: PASS"
                severity note;

            report "No framing error."
                severity note;

            report "=========================================="
                severity note;

        else

            report "=========================================="
                severity error;

            report "UART CORE TEST FAILED"
                severity error;

            report "=========================================="
                severity error;

        end if;

        wait;

    end process;

end Behavioral;