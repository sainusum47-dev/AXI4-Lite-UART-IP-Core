----------------------------------------------------------------------------------
-- Module: UART Transmitter
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
-- Each UART bit lasts for 16 baud_tick pulses.
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity uart_tx is
    Port (
        clk       : in  STD_LOGIC;
        reset     : in  STD_LOGIC;
        baud_tick : in  STD_LOGIC;
        tx_data   : in  STD_LOGIC_VECTOR (7 downto 0);
        tx_start  : in  STD_LOGIC;
        tx        : out STD_LOGIC;
        tx_busy   : out STD_LOGIC
    );
end uart_tx;

architecture Behavioral of uart_tx is

    type tx_state_t is (
        IDLE,
        START_BIT,
        DATA_BITS,
        STOP_BIT
    );

    signal state : tx_state_t := IDLE;

    signal tx_shift_reg : STD_LOGIC_VECTOR(7 downto 0)
                         := (others => '0');

    -- Counts 16 baud ticks for each UART bit.
    signal tick_count : integer range 0 to 15 := 0;

    -- Selects the current data bit.
    signal bit_count : integer range 0 to 7 := 0;

begin

    process(clk)
    begin
        if rising_edge(clk) then

            if reset = '1' then

                state        <= IDLE;
                tx_shift_reg <= (others => '0');
                tick_count   <= 0;
                bit_count    <= 0;

                tx            <= '1';
                tx_busy       <= '0';

            else

                case state is

                    ----------------------------------------------------------------
                    -- IDLE
                    ----------------------------------------------------------------
                    when IDLE =>

                        tx        <= '1';
                        tx_busy   <= '0';
                        tick_count <= 0;
                        bit_count <= 0;

                        if tx_start = '1' then

                            -- Latch the byte.
                            tx_shift_reg <= tx_data;

                            -- Start UART transmission.
                            tx_busy <= '1';

                            -- START bit begins immediately.
                            tx <= '0';

                            tick_count <= 0;
                            bit_count <= 0;

                            state <= START_BIT;

                        end if;

                    ----------------------------------------------------------------
                    -- START BIT
                    ----------------------------------------------------------------
                    when START_BIT =>

                        tx_busy <= '1';

                        if baud_tick = '1' then

                            if tick_count = 15 then

                                -- START bit has lasted 16 ticks.
                                tick_count <= 0;

                                -- Begin DATA bit 0.
                                tx <= tx_shift_reg(0);

                                state <= DATA_BITS;

                            else

                                tick_count <= tick_count + 1;

                            end if;

                        end if;

                    ----------------------------------------------------------------
                    -- DATA BITS
                    ----------------------------------------------------------------
                    when DATA_BITS =>

                        tx_busy <= '1';

                        if baud_tick = '1' then

                            if tick_count = 15 then

                                tick_count <= 0;

                                if bit_count = 7 then

                                    -- All 8 data bits completed.
                                    tx <= '1';

                                    state <= STOP_BIT;

                                else

                                    -- Move to next data bit.
                                    bit_count <= bit_count + 1;

                                    tx <= tx_shift_reg(bit_count + 1);

                                end if;

                            else

                                tick_count <= tick_count + 1;

                            end if;

                        end if;

                    ----------------------------------------------------------------
                    -- STOP BIT
                    ----------------------------------------------------------------
                    when STOP_BIT =>

                        tx_busy <= '1';

                        if baud_tick = '1' then

                            if tick_count = 15 then

                                -- STOP bit complete.
                                tx <= '1';
                                tx_busy <= '0';

                                tick_count <= 0;
                                state <= IDLE;

                            else

                                tick_count <= tick_count + 1;

                            end if;

                        end if;

                end case;

            end if;

        end if;

    end process;

end Behavioral;