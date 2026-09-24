----------------------------------------------------------------------------------
-- Module: UART Receiver
-- Project: AXI_UART_IP
-- Target Device: xc7a35tcpg236-1
-- Tool: Vivado 2026.1
--
-- UART configuration:
--   Data bits : 8
--   Parity    : None
--   Stop bits : 1
--   Bit order : LSB first
--
-- baud_tick = 16x UART timing tick.
--
-- Integration-safe behavior:
--   rx_data is updated first.
--   rx_valid is asserted on the following clock cycle.
--   This allows a synchronous RX FIFO to correctly capture the byte.
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity uart_rx is
    Port (
        clk         : in  STD_LOGIC;
        reset       : in  STD_LOGIC;
        baud_tick   : in  STD_LOGIC;
        rx          : in  STD_LOGIC;
        rx_data     : out STD_LOGIC_VECTOR (7 downto 0);
        rx_valid    : out STD_LOGIC;
        rx_busy     : out STD_LOGIC;
        frame_error : out STD_LOGIC
    );
end uart_rx;

architecture Behavioral of uart_rx is

    --------------------------------------------------------------------------
    -- Receiver states
    --------------------------------------------------------------------------
    type rx_state_t is (
        IDLE,
        START_BIT,
        DATA_BITS,
        STOP_BIT,
        RX_DONE
    );

    signal state : rx_state_t := IDLE;

    --------------------------------------------------------------------------
    -- Two-flip-flop synchronizer
    --------------------------------------------------------------------------
    signal rx_meta : STD_LOGIC := '1';
    signal rx_sync : STD_LOGIC := '1';

    --------------------------------------------------------------------------
    -- Receive shift register
    --------------------------------------------------------------------------
    signal rx_shift_reg : STD_LOGIC_VECTOR(7 downto 0)
                         := (others => '0');

    --------------------------------------------------------------------------
    -- Counts the 16 baud ticks in one UART bit
    --------------------------------------------------------------------------
    signal tick_count : integer range 0 to 15 := 0;

    --------------------------------------------------------------------------
    -- Data bit counter
    --------------------------------------------------------------------------
    signal bit_count : integer range 0 to 7 := 0;

begin

    process(clk)
    begin

        if rising_edge(clk) then

            ------------------------------------------------------------------
            -- Synchronize asynchronous RX input
            ------------------------------------------------------------------
            rx_meta <= rx;
            rx_sync <= rx_meta;

            ------------------------------------------------------------------
            -- Reset
            ------------------------------------------------------------------
            if reset = '1' then

                state        <= IDLE;
                rx_shift_reg <= (others => '0');
                rx_data      <= (others => '0');

                tick_count   <= 0;
                bit_count    <= 0;

                rx_valid     <= '0';
                rx_busy      <= '0';
                frame_error  <= '0';

            else

                ----------------------------------------------------------------
                -- Default pulse outputs
                ----------------------------------------------------------------
                rx_valid    <= '0';
                frame_error <= '0';

                case state is

                    ------------------------------------------------------------
                    -- IDLE
                    ------------------------------------------------------------
                    when IDLE =>

                        rx_busy    <= '0';
                        tick_count <= 0;
                        bit_count  <= 0;

                        if rx_sync = '0' then

                            rx_busy    <= '1';
                            tick_count <= 0;

                            state <= START_BIT;

                        end if;

                    ------------------------------------------------------------
                    -- START BIT
                    --
                    -- Wait 8 baud ticks to sample near the center.
                    ------------------------------------------------------------
                    when START_BIT =>

                        rx_busy <= '1';

                        if baud_tick = '1' then

                            if tick_count = 7 then

                                tick_count <= 0;

                                if rx_sync = '0' then

                                    bit_count <= 0;

                                    state <= DATA_BITS;

                                else

                                    -- False start.
                                    rx_busy <= '0';
                                    state <= IDLE;

                                end if;

                            else

                                tick_count <= tick_count + 1;

                            end if;

                        end if;

                    ------------------------------------------------------------
                    -- DATA BITS
                    ------------------------------------------------------------
                    when DATA_BITS =>

                        rx_busy <= '1';

                        if baud_tick = '1' then

                            if tick_count = 15 then

                                tick_count <= 0;

                                -- Sample current data bit.
                                rx_shift_reg(bit_count) <= rx_sync;

                                if bit_count = 7 then

                                    state <= STOP_BIT;

                                else

                                    bit_count <= bit_count + 1;

                                end if;

                            else

                                tick_count <= tick_count + 1;

                            end if;

                        end if;

                    ------------------------------------------------------------
                    -- STOP BIT
                    ------------------------------------------------------------
                    when STOP_BIT =>

                        rx_busy <= '1';

                        if baud_tick = '1' then

                            if tick_count = 15 then

                                tick_count <= 0;

                                if rx_sync = '1' then

                                    ----------------------------------------------------------------
                                    -- IMPORTANT:
                                    -- First update rx_data.
                                    -- rx_valid will be asserted in RX_DONE
                                    -- on the following clock.
                                    ----------------------------------------------------------------
                                    rx_data <= rx_shift_reg;

                                    state <= RX_DONE;

                                else

                                    frame_error <= '1';

                                    rx_busy <= '0';

                                    state <= IDLE;

                                end if;

                            else

                                tick_count <= tick_count + 1;

                            end if;

                        end if;

                    ------------------------------------------------------------
                    -- RX_DONE
                    --
                    -- rx_data has already been updated.
                    -- Now generate the one-cycle rx_valid pulse.
                    ------------------------------------------------------------
                    when RX_DONE =>

                        rx_valid <= '1';
                        rx_busy  <= '0';

                        state <= IDLE;

                end case;

            end if;

        end if;

    end process;

end Behavioral;