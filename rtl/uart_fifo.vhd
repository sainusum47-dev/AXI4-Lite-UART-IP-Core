----------------------------------------------------------------------------------
-- Module: Reusable 8-bit FIFO
-- Project: AXI_UART_IP
-- Target Device: xc7a35tcpg236-1
-- Tool: Vivado 2026.1
--
-- FIFO configuration:
--   Data width : 8 bits
--   Depth      : 16 entries
--
-- Features:
--   Write / Read
--   Full / Empty
--   Almost Full / Almost Empty
--   FIFO level
--   Overflow / Underflow protection
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity uart_fifo is
    Port (
        clk          : in  STD_LOGIC;
        reset        : in  STD_LOGIC;
        wr_en        : in  STD_LOGIC;
        rd_en        : in  STD_LOGIC;
        din          : in  STD_LOGIC_VECTOR (7 downto 0);
        dout         : out STD_LOGIC_VECTOR (7 downto 0);
        full         : out STD_LOGIC;
        empty        : out STD_LOGIC;
        almost_full  : out STD_LOGIC;
        almost_empty : out STD_LOGIC;
        level        : out STD_LOGIC_VECTOR (4 downto 0);
        overflow     : out STD_LOGIC;
        underflow    : out STD_LOGIC
    );
end uart_fifo;

architecture Behavioral of uart_fifo is

    --------------------------------------------------------------------------
    -- FIFO memory
    --------------------------------------------------------------------------
    type fifo_memory_t is array (0 to 15) of STD_LOGIC_VECTOR(7 downto 0);

    signal fifo_memory : fifo_memory_t := (others => (others => '0'));

    --------------------------------------------------------------------------
    -- Read and write pointers
    --
    -- 4 bits are sufficient for addresses 0 to 15.
    --------------------------------------------------------------------------
    signal wr_ptr : unsigned(3 downto 0) := (others => '0');
    signal rd_ptr : unsigned(3 downto 0) := (others => '0');

    --------------------------------------------------------------------------
    -- Number of entries currently stored.
    --
    -- 5 bits are required because the FIFO can contain 0 to 16 entries.
    --------------------------------------------------------------------------
    signal count : unsigned(4 downto 0) := (others => '0');

    --------------------------------------------------------------------------
    -- Output data register
    --------------------------------------------------------------------------
    signal dout_reg : STD_LOGIC_VECTOR(7 downto 0) := (others => '0');

begin

    --------------------------------------------------------------------------
    -- Output assignments
    --------------------------------------------------------------------------
    dout <= dout_reg;

    level <= STD_LOGIC_VECTOR(count);

    full  <= '1' when count = 16 else '0';
    empty <= '1' when count = 0  else '0';

    --------------------------------------------------------------------------
    -- Almost-full threshold:
    -- Assert when 14 or more entries are stored.
    --------------------------------------------------------------------------
    almost_full <= '1' when count >= 14 else '0';

    --------------------------------------------------------------------------
    -- Almost-empty threshold:
    -- Assert when 1 or fewer entries are stored.
    --------------------------------------------------------------------------
    almost_empty <= '1' when count <= 1 else '0';

    --------------------------------------------------------------------------
    -- FIFO control process
    --------------------------------------------------------------------------
    process(clk)
        variable do_write : boolean;
        variable do_read  : boolean;
    begin

        if rising_edge(clk) then

            ------------------------------------------------------------------
            -- Reset
            ------------------------------------------------------------------
            if reset = '1' then

                wr_ptr   <= (others => '0');
                rd_ptr   <= (others => '0');
                count    <= (others => '0');

                dout_reg <= (others => '0');

                overflow  <= '0';
                underflow <= '0';

            else

                ----------------------------------------------------------------
                -- Default error outputs are one-cycle pulses.
                ----------------------------------------------------------------
                overflow  <= '0';
                underflow <= '0';

                ----------------------------------------------------------------
                -- Determine legal operations.
                ----------------------------------------------------------------
                do_write := (wr_en = '1') and (count < 16);

                do_read  := (rd_en = '1') and (count > 0);

                ----------------------------------------------------------------
                -- Overflow protection
                ----------------------------------------------------------------
                if (wr_en = '1') and (count = 16) then
                    overflow <= '1';
                end if;

                ----------------------------------------------------------------
                -- Underflow protection
                ----------------------------------------------------------------
                if (rd_en = '1') and (count = 0) then
                    underflow <= '1';
                end if;

                ----------------------------------------------------------------
                -- WRITE
                ----------------------------------------------------------------
                if do_write then

                    fifo_memory(to_integer(wr_ptr)) <= din;

                    wr_ptr <= wr_ptr + 1;

                end if;

                ----------------------------------------------------------------
                -- READ
                ----------------------------------------------------------------
                if do_read then

                    dout_reg <= fifo_memory(to_integer(rd_ptr));

                    rd_ptr <= rd_ptr + 1;

                end if;

                ----------------------------------------------------------------
                -- COUNT UPDATE
                ----------------------------------------------------------------
                if do_write and not do_read then

                    count <= count + 1;

                elsif do_read and not do_write then

                    count <= count - 1;

                end if;

            end if;

        end if;

    end process;

end Behavioral;