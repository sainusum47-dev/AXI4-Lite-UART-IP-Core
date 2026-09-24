----------------------------------------------------------------------------------
-- Testbench: UART Receiver
-- Project: AXI_UART_IP
--
-- Purpose:
--   Verifies reception of an 8-bit UART frame.
--
-- UART format:
--   1 start bit
--   8 data bits, LSB first
--   1 stop bit
--
-- baud_tick:
--   16x UART timing tick
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity tb_uart_rx is
end tb_uart_rx;

architecture Behavioral of tb_uart_rx is

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
    -- UART RX signals
    --------------------------------------------------------------------------
    signal baud_tick : STD_LOGIC := '0';
    signal rx        : STD_LOGIC := '1';

    signal rx_data     : STD_LOGIC_VECTOR(7 downto 0);
    signal rx_valid    : STD_LOGIC;
    signal rx_busy     : STD_LOGIC;
    signal frame_error : STD_LOGIC;

    --------------------------------------------------------------------------
    -- Monitor signals
    --------------------------------------------------------------------------
    signal rx_valid_seen    : STD_LOGIC := '0';
    signal captured_data    : STD_LOGIC_VECTOR(7 downto 0) := (others => '0');
    signal frame_error_seen : STD_LOGIC := '0';

begin

    --------------------------------------------------------------------------
    -- DUT: UART Receiver
    --------------------------------------------------------------------------
    DUT : entity work.uart_rx
        port map (
            clk         => clk,
            reset       => reset,
            baud_tick   => baud_tick,
            rx          => rx,
            rx_data     => rx_data,
            rx_valid    => rx_valid,
            rx_busy     => rx_busy,
            frame_error => frame_error
        );

    --------------------------------------------------------------------------
    -- 100 MHz system clock
    -- 100 MHz = 10 ns period
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
    -- 16x UART timing tick
    --
    -- One baud_tick every 4 system-clock cycles.
    -- Therefore:
    --
    -- 16 baud_ticks = 1 UART bit
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
    -- RX monitor
    --
    -- Captures the one-clock rx_valid pulse and received data.
    --------------------------------------------------------------------------
    monitor_process : process
    begin

        while true loop

            wait until rising_edge(clk);

            -- Allow DUT signal updates to settle.
            wait for 1 ns;

            if rx_valid = '1' then

                rx_valid_seen <= '1';
                captured_data <= rx_data;

                report "MONITOR: RX_VALID detected."
                    severity note;

            end if;

            if frame_error = '1' then

                frame_error_seen <= '1';

                report "MONITOR: FRAME ERROR detected."
                    severity error;

            end if;

        end loop;

    end process;

    --------------------------------------------------------------------------
    -- Main stimulus process
    --------------------------------------------------------------------------
    stimulus_process : process

        ----------------------------------------------------------------------
        -- Send one UART bit.
        --
        -- Each UART bit lasts for 16 baud ticks.
        ----------------------------------------------------------------------
        procedure send_uart_bit(bit_value : STD_LOGIC) is
        begin

            rx <= bit_value;

            for i in 0 to 15 loop

                wait until rising_edge(clk);

                while baud_tick /= '1' loop
                    wait until rising_edge(clk);
                end loop;

            end loop;

        end procedure;

    begin

        ----------------------------------------------------------------------
        -- RESET
        ----------------------------------------------------------------------
        rx    <= '1';
        reset <= '1';

        wait for 30 ns;

        reset <= '0';

        wait for 20 ns;

        ----------------------------------------------------------------------
        -- Start RX test
        ----------------------------------------------------------------------
        report "Starting UART RX test for 0x55."
            severity note;

        ----------------------------------------------------------------------
        -- UART FRAME
        --
        -- 0x55 = 01010101
        --
        -- UART transmits LSB first:
        --
        -- START = 0
        -- D0    = 1
        -- D1    = 0
        -- D2    = 1
        -- D3    = 0
        -- D4    = 1
        -- D5    = 0
        -- D6    = 1
        -- D7    = 0
        -- STOP  = 1
        ----------------------------------------------------------------------

        send_uart_bit('0');  -- START
        send_uart_bit('1');  -- D0
        send_uart_bit('0');  -- D1
        send_uart_bit('1');  -- D2
        send_uart_bit('0');  -- D3
        send_uart_bit('1');  -- D4
        send_uart_bit('0');  -- D5
        send_uart_bit('1');  -- D6
        send_uart_bit('0');  -- D7
        send_uart_bit('1');  -- STOP

        ----------------------------------------------------------------------
        -- Return RX to idle state.
        ----------------------------------------------------------------------
        rx <= '1';

        ----------------------------------------------------------------------
        -- Allow monitor to capture rx_valid.
        ----------------------------------------------------------------------
        wait for 100 ns;

        ----------------------------------------------------------------------
        -- FINAL CHECK 1: RX_VALID
        ----------------------------------------------------------------------
        assert rx_valid_seen = '1'
            report "FAIL: RX_VALID pulse was not observed."
            severity error;

        ----------------------------------------------------------------------
        -- FINAL CHECK 2: Received data
        ----------------------------------------------------------------------
        assert captured_data = x"55"
            report "FAIL: Received data is incorrect. Expected 0x55."
            severity error;

        ----------------------------------------------------------------------
        -- FINAL CHECK 3: Frame error
        ----------------------------------------------------------------------
        assert frame_error_seen = '0'
            report "FAIL: Unexpected framing error detected."
            severity error;

        ----------------------------------------------------------------------
        -- FINAL CHECK 4: Receiver not busy
        ----------------------------------------------------------------------
        assert rx_busy = '0'
            report "FAIL: RX_BUSY did not return LOW."
            severity error;

        ----------------------------------------------------------------------
        -- Final PASS / FAIL decision
        ----------------------------------------------------------------------
        if (rx_valid_seen = '1') and
           (captured_data = x"55") and
           (frame_error_seen = '0') and
           (rx_busy = '0') then

            report "=========================================="
                severity note;

            report "UART RX TEST PASSED"
                severity note;

            report "0x55 received correctly."
                severity note;

            report "RX_VALID observed."
                severity note;

            report "No framing error."
                severity note;

            report "START -> D0..D7 -> STOP"
                severity note;

            report "=========================================="
                severity note;

        else

            report "=========================================="
                severity error;

            report "UART RX TEST FAILED"
                severity error;

            report "=========================================="
                severity error;

        end if;

        wait;

    end process;

end Behavioral;