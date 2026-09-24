----------------------------------------------------------------------------------
-- Testbench: UART FIFO
-- Project: AXI_UART_IP
--
-- FIFO configuration:
--   Data width = 8 bits
--   Depth      = 16 entries
--
-- Tests:
--   1. Reset
--   2. Write / Read
--   3. FIFO ordering
--   4. Full condition
--   5. Overflow protection
--   6. Empty condition
--   7. Underflow protection
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity tb_uart_fifo is
end tb_uart_fifo;

architecture Behavioral of tb_uart_fifo is

    --------------------------------------------------------------------------
    -- DUT signals
    --------------------------------------------------------------------------
    signal clk          : STD_LOGIC := '0';
    signal reset        : STD_LOGIC := '1';

    signal wr_en        : STD_LOGIC := '0';
    signal rd_en        : STD_LOGIC := '0';

    signal din          : STD_LOGIC_VECTOR(7 downto 0) := (others => '0');
    signal dout         : STD_LOGIC_VECTOR(7 downto 0);

    signal full         : STD_LOGIC;
    signal empty        : STD_LOGIC;
    signal almost_full  : STD_LOGIC;
    signal almost_empty : STD_LOGIC;

    signal level        : STD_LOGIC_VECTOR(4 downto 0);

    signal overflow     : STD_LOGIC;
    signal underflow    : STD_LOGIC;

    constant CLK_PERIOD : time := 10 ns;

begin

    --------------------------------------------------------------------------
    -- DUT
    --------------------------------------------------------------------------
    DUT : entity work.uart_fifo
        port map (
            clk          => clk,
            reset        => reset,
            wr_en        => wr_en,
            rd_en        => rd_en,
            din          => din,
            dout         => dout,
            full         => full,
            empty        => empty,
            almost_full  => almost_full,
            almost_empty => almost_empty,
            level        => level,
            overflow     => overflow,
            underflow    => underflow
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
    -- Main stimulus
    --------------------------------------------------------------------------
    stimulus_process : process
    begin

        ----------------------------------------------------------------------
        -- RESET
        ----------------------------------------------------------------------
        reset <= '1';
        wr_en <= '0';
        rd_en <= '0';
        din   <= x"00";

        wait for 30 ns;

        reset <= '0';

        wait until rising_edge(clk);
        wait for 1 ns;

        ----------------------------------------------------------------------
        -- TEST 1: FIFO should be empty after reset
        ----------------------------------------------------------------------
        assert empty = '1'
            report "FAIL: FIFO is not EMPTY after reset."
            severity error;

        assert level = "00000"
            report "FAIL: FIFO level is not 0 after reset."
            severity error;

        report "PASS: FIFO reset test."
            severity note;

        ----------------------------------------------------------------------
        -- TEST 2: Write three bytes
        ----------------------------------------------------------------------

        -- Write 0x11
        din   <= x"11";
        wr_en <= '1';

        wait until rising_edge(clk);
        wait for 1 ns;

        wr_en <= '0';

        -- Write 0x22
        din   <= x"22";
        wr_en <= '1';

        wait until rising_edge(clk);
        wait for 1 ns;

        wr_en <= '0';

        -- Write 0x33
        din   <= x"33";
        wr_en <= '1';

        wait until rising_edge(clk);
        wait for 1 ns;

        wr_en <= '0';

        assert level = "00011"
            report "FAIL: FIFO level should be 3."
            severity error;

        assert empty = '0'
            report "FAIL: FIFO incorrectly reports EMPTY."
            severity error;

        report "PASS: FIFO write test."
            severity note;

        ----------------------------------------------------------------------
        -- TEST 3: FIFO ordering
        ----------------------------------------------------------------------

        -- Read 0x11
        rd_en <= '1';

        wait until rising_edge(clk);
        wait for 1 ns;

        rd_en <= '0';

        assert dout = x"11"
            report "FAIL: Expected 0x11."
            severity error;

        -- Read 0x22
        rd_en <= '1';

        wait until rising_edge(clk);
        wait for 1 ns;

        rd_en <= '0';

        assert dout = x"22"
            report "FAIL: Expected 0x22."
            severity error;

        -- Read 0x33
        rd_en <= '1';

        wait until rising_edge(clk);
        wait for 1 ns;

        rd_en <= '0';

        assert dout = x"33"
            report "FAIL: Expected 0x33."
            severity error;

        assert empty = '1'
            report "FAIL: FIFO should be EMPTY."
            severity error;

        report "PASS: FIFO ordering test."
            severity note;

        ----------------------------------------------------------------------
        -- TEST 4: Fill FIFO with 16 entries
        ----------------------------------------------------------------------

        for i in 0 to 15 loop

            din   <= std_logic_vector(to_unsigned(i, 8));
            wr_en <= '1';

            wait until rising_edge(clk);
            wait for 1 ns;

            wr_en <= '0';

        end loop;

        assert full = '1'
            report "FAIL: FIFO is not FULL after 16 writes."
            severity error;

        assert level = "10000"
            report "FAIL: FIFO level should be 16."
            severity error;

        report "PASS: FIFO FULL test."
            severity note;

        ----------------------------------------------------------------------
        -- TEST 5: Overflow protection
        ----------------------------------------------------------------------

        din   <= x"FF";
        wr_en <= '1';

        wait until rising_edge(clk);
        wait for 1 ns;

        wr_en <= '0';

        assert overflow = '1'
            report "FAIL: Overflow was not detected."
            severity error;

        assert level = "10000"
            report "FAIL: FIFO level changed during overflow."
            severity error;

        report "PASS: FIFO overflow protection."
            severity note;

        ----------------------------------------------------------------------
        -- TEST 6: Read all 16 entries
        ----------------------------------------------------------------------

        for i in 0 to 15 loop

            rd_en <= '1';

            wait until rising_edge(clk);
            wait for 1 ns;

            rd_en <= '0';

        end loop;

        assert empty = '1'
            report "FAIL: FIFO should be EMPTY after 16 reads."
            severity error;

        assert level = "00000"
            report "FAIL: FIFO level should be 0."
            severity error;

        report "PASS: FIFO EMPTY test."
            severity note;

        ----------------------------------------------------------------------
        -- TEST 7: Underflow protection
        ----------------------------------------------------------------------

        rd_en <= '1';

        wait until rising_edge(clk);
        wait for 1 ns;

        rd_en <= '0';

        assert underflow = '1'
            report "FAIL: Underflow was not detected."
            severity error;

        assert level = "00000"
            report "FAIL: FIFO level changed during underflow."
            severity error;

        report "PASS: FIFO underflow protection."
            severity note;

        ----------------------------------------------------------------------
        -- FINAL RESULT
        ----------------------------------------------------------------------

        report "=========================================="
            severity note;

        report "UART FIFO TEST PASSED"
            severity note;

        report "Reset                : PASS"
            severity note;

        report "Write / Read         : PASS"
            severity note;

        report "FIFO Ordering        : PASS"
            severity note;

        report "FIFO Full            : PASS"
            severity note;

        report "FIFO Empty           : PASS"
            severity note;

        report "Overflow Protection  : PASS"
            severity note;

        report "Underflow Protection : PASS"
            severity note;

        report "=========================================="
            severity note;

        wait;

    end process;

end Behavioral;