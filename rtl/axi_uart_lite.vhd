library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity axi_uart_lite is
    port (
        s_axi_aclk    : in  std_logic;
        s_axi_aresetn : in  std_logic;

        -- AXI4-Lite Write Channel
        s_axi_awaddr  : in  std_logic_vector(4 downto 0);
        s_axi_awvalid : in  std_logic;
        s_axi_awready : out std_logic;
        s_axi_wdata   : in  std_logic_vector(31 downto 0);
        s_axi_wstrb   : in  std_logic_vector(3 downto 0);
        s_axi_wvalid  : in  std_logic;
        s_axi_wready  : out std_logic;
        s_axi_bresp   : out std_logic_vector(1 downto 0);
        s_axi_bvalid  : out std_logic;
        s_axi_bready  : in  std_logic;

        -- AXI4-Lite Read Channel
        s_axi_araddr  : in  std_logic_vector(4 downto 0);
        s_axi_arvalid : in  std_logic;
        s_axi_arready : out std_logic;
        s_axi_rdata   : out std_logic_vector(31 downto 0);
        s_axi_rresp   : out std_logic_vector(1 downto 0);
        s_axi_rvalid  : out std_logic;
        s_axi_rready  : in  std_logic;

        -- External UART Interfaces
        uart_tx       : out std_logic;
        uart_rx       : in  std_logic;
        uart_rts_n    : out std_logic;
        uart_cts_n    : in  std_logic;

        -- Hardware Interrupt Output
        ip2intc_irpt  : out std_logic
    );
end entity axi_uart_lite;

architecture behavioral of axi_uart_lite is

    -- Registers
    signal baud_div   : unsigned(15 downto 0) := to_unsigned(16, 16);
    signal ctrl_reg   : std_logic_vector(31 downto 0) := x"00000003";
    signal ier_reg    : std_logic_vector(2 downto 0)  := "000";
    signal isr_reg    : std_logic_vector(2 downto 0)  := "000";
    signal err_status : std_logic_vector(2 downto 0)  := "000";

    -- Handshakes
    signal awready_i  : std_logic := '0';
    signal wready_i   : std_logic := '0';
    signal bvalid_i   : std_logic := '0';
    signal arready_i  : std_logic := '0';
    signal rvalid_i   : std_logic := '0';
    signal rdata_i    : std_logic_vector(31 downto 0) := (others => '0');

    -- FIFOs
    type fifo_array is array (0 to 15) of std_logic_vector(7 downto 0);
    signal tx_fifo_mem   : fifo_array := (others => (others => '0'));
    signal tx_head, tx_tail : integer range 0 to 15 := 0;
    signal tx_count      : integer range 0 to 16 := 0;
    signal tx_fifo_wr, tx_fifo_rd : std_logic := '0';
    signal tx_fifo_din, tx_fifo_dout : std_logic_vector(7 downto 0) := (others => '0');
    signal tx_fifo_full, tx_fifo_empty : std_logic;

    signal rx_fifo_mem   : fifo_array := (others => (others => '0'));
    signal rx_head, rx_tail : integer range 0 to 15 := 0;
    signal rx_count      : integer range 0 to 16 := 0;
    signal rx_fifo_wr, rx_fifo_rd : std_logic := '0';
    signal rx_fifo_din, rx_fifo_dout : std_logic_vector(7 downto 0) := (others => '0');
    signal rx_fifo_full, rx_fifo_empty : std_logic;

    -- State Machines (Distinct State Names to Avoid Collision with Parity Signals)
    type tx_state_type is (ST_TX_IDLE, ST_TX_START, ST_TX_DATA, ST_TX_PARITY, ST_TX_STOP);
    signal tx_state    : tx_state_type := ST_TX_IDLE;
    signal tx_cnt      : unsigned(15 downto 0) := (others => '0');
    signal tx_bit_idx  : integer range 0 to 7 := 0;
    signal tx_shift    : std_logic_vector(7 downto 0) := (others => '0');
    signal tx_parity   : std_logic := '0';

    type rx_state_type is (ST_RX_IDLE, ST_RX_START, ST_RX_DATA, ST_RX_PARITY, ST_RX_STOP);
    signal rx_state    : rx_state_type := ST_RX_IDLE;
    signal rx_cnt      : unsigned(15 downto 0) := (others => '0');
    signal rx_bit_idx  : integer range 0 to 7 := 0;
    signal rx_shift    : std_logic_vector(7 downto 0) := (others => '0');
    signal rx_parity   : std_logic := '0';

    -- Synchronizers
    signal rx_sync1, rx_sync2   : std_logic := '1';
    signal cts_sync1, cts_sync2 : std_logic := '1';

begin

    s_axi_awready <= awready_i;
    s_axi_wready  <= wready_i;
    s_axi_bresp   <= "00";
    s_axi_bvalid  <= bvalid_i;
    s_axi_arready <= arready_i;
    s_axi_rdata   <= rdata_i;
    s_axi_rresp   <= "00";
    s_axi_rvalid  <= rvalid_i;

    ip2intc_irpt <= (isr_reg(0) and ier_reg(0)) or 
                    (isr_reg(1) and ier_reg(1)) or 
                    (isr_reg(2) and ier_reg(2));

    uart_rts_n <= '1' when (ctrl_reg(5) = '1' and rx_count >= 12) else '0';

    ----------------------------------------------------------------------------
    -- AXI Write Channel Logic
    ----------------------------------------------------------------------------
    process(s_axi_aclk)
    begin
        if rising_edge(s_axi_aclk) then
            if s_axi_aresetn = '0' then
                awready_i  <= '0';
                wready_i   <= '0';
                bvalid_i   <= '0';
                tx_fifo_wr <= '0';
                ctrl_reg   <= x"00000003";
                ier_reg    <= "000";
                isr_reg    <= "000";
            else
                tx_fifo_wr <= '0';

                if rx_fifo_wr = '1' then
                    isr_reg(0) <= '1';
                end if;
                if tx_count = 0 and tx_fifo_rd = '1' then
                    isr_reg(1) <= '1';
                end if;
                if err_status /= "000" then
                    isr_reg(2) <= '1';
                end if;

                if (s_axi_awvalid = '1' and s_axi_wvalid = '1' and awready_i = '0') then
                    awready_i <= '1';
                    wready_i  <= '1';

                    case s_axi_awaddr(4 downto 0) is
                        when "00000" =>
                            if tx_fifo_full = '0' then
                                tx_fifo_din <= s_axi_wdata(7 downto 0);
                                tx_fifo_wr  <= '1';
                            end if;
                        when "00100" =>
                            baud_div <= unsigned(s_axi_wdata(15 downto 0));
                        when "01100" =>
                            ctrl_reg <= s_axi_wdata;
                        when "10000" =>
                            ier_reg <= s_axi_wdata(2 downto 0);
                        when "10100" =>
                            isr_reg <= isr_reg and not s_axi_wdata(2 downto 0);
                        when others =>
                            null;
                    end case;
                else
                    awready_i <= '0';
                    wready_i  <= '0';
                end if;

                if (awready_i = '1' and wready_i = '1' and bvalid_i = '0') then
                    bvalid_i <= '1';
                elsif (s_axi_bready = '1' and bvalid_i = '1') then
                    bvalid_i <= '0';
                end if;
            end if;
        end if;
    end process;

    ----------------------------------------------------------------------------
    -- AXI Read Channel Logic
    ----------------------------------------------------------------------------
    process(s_axi_aclk)
        variable status_word : std_logic_vector(31 downto 0);
    begin
        if rising_edge(s_axi_aclk) then
            if s_axi_aresetn = '0' then
                arready_i  <= '0';
                rvalid_i   <= '0';
                rdata_i    <= (others => '0');
                rx_fifo_rd <= '0';
            else
                rx_fifo_rd <= '0';

                status_word := (others => '0');
                status_word(0) := not rx_fifo_empty;
                status_word(1) := rx_fifo_full;
                status_word(2) := tx_fifo_empty;
                status_word(3) := tx_fifo_full;
                status_word(6 downto 4) := err_status;

                if (s_axi_arvalid = '1' and arready_i = '0') then
                    arready_i <= '1';
                    rvalid_i  <= '1';

                    case s_axi_araddr(4 downto 0) is
                        when "00000" =>
                            rdata_i <= x"000000" & rx_fifo_dout;
                            if rx_fifo_empty = '0' then
                                rx_fifo_rd <= '1';
                            end if;
                        when "00100" => rdata_i <= x"0000" & std_logic_vector(baud_div);
                        when "01000" => rdata_i <= status_word;
                        when "01100" => rdata_i <= ctrl_reg;
                        when "10000" => rdata_i <= x"0000000" & '0' & ier_reg;
                        when "10100" => rdata_i <= x"0000000" & '0' & isr_reg;
                        when others  => rdata_i <= (others => '0');
                    end case;
                else
                    arready_i <= '0';
                end if;

                if (rvalid_i = '1' and s_axi_rready = '1') then
                    rvalid_i <= '0';
                end if;
            end if;
        end if;
    end process;

    ----------------------------------------------------------------------------
    -- FIFO RAM Logic
    ----------------------------------------------------------------------------
    tx_fifo_dout  <= tx_fifo_mem(tx_tail);
    tx_fifo_full  <= '1' when tx_count = 16 else '0';
    tx_fifo_empty <= '1' when tx_count = 0 else '0';

    rx_fifo_dout  <= rx_fifo_mem(rx_tail);
    rx_fifo_full  <= '1' when rx_count = 16 else '0';
    rx_fifo_empty <= '1' when rx_count = 0 else '0';

    process(s_axi_aclk)
    begin
        if rising_edge(s_axi_aclk) then
            if s_axi_aresetn = '0' then
                tx_head <= 0; tx_tail <= 0; tx_count <= 0;
                rx_head <= 0; rx_tail <= 0; rx_count <= 0;
            else
                if (tx_fifo_wr = '1' and tx_fifo_full = '0' and tx_fifo_rd = '0') then
                    tx_fifo_mem(tx_head) <= tx_fifo_din;
                    tx_head  <= (tx_head + 1) mod 16;
                    tx_count <= tx_count + 1;
                elsif (tx_fifo_rd = '1' and tx_fifo_empty = '0' and tx_fifo_wr = '0') then
                    tx_tail  <= (tx_tail + 1) mod 16;
                    tx_count <= tx_count - 1;
                end if;

                if (rx_fifo_wr = '1' and rx_fifo_full = '0' and rx_fifo_rd = '0') then
                    rx_fifo_mem(rx_head) <= rx_fifo_din;
                    rx_head  <= (rx_head + 1) mod 16;
                    rx_count <= rx_count + 1;
                elsif (rx_fifo_rd = '1' and rx_fifo_empty = '0' and rx_fifo_wr = '0') then
                    rx_tail  <= (rx_tail + 1) mod 16;
                    rx_count <= rx_count - 1;
                end if;
            end if;
        end if;
    end process;

    ----------------------------------------------------------------------------
    -- Transmitter (TX) State Machine
    ----------------------------------------------------------------------------
    process(s_axi_aclk)
        variable max_bits : integer range 4 to 7;
        variable double_baud : unsigned(15 downto 0);
    begin
        if rising_edge(s_axi_aclk) then
            if s_axi_aresetn = '0' then
                tx_state   <= ST_TX_IDLE;
                uart_tx    <= '1';
                tx_cnt     <= (others => '0');
                tx_bit_idx <= 0;
                tx_fifo_rd <= '0';
                cts_sync1  <= '1'; cts_sync2 <= '1';
            else
                cts_sync1  <= uart_cts_n;
                cts_sync2  <= cts_sync1;
                tx_fifo_rd <= '0';

                max_bits    := to_integer(unsigned(ctrl_reg(1 downto 0))) + 4;
                double_baud := shift_left(baud_div, 1);

                case tx_state is
                    when ST_TX_IDLE =>
                        uart_tx <= '1';
                        tx_cnt  <= (others => '0');
                        if (tx_fifo_empty = '0' and cts_sync2 = '0') then
                            tx_shift   <= tx_fifo_dout;
                            tx_fifo_rd <= '1';
                            tx_state   <= ST_TX_START;
                        end if;

                    when ST_TX_START =>
                        uart_tx <= '0';
                        if tx_cnt >= (baud_div - 1) then
                            tx_cnt     <= (others => '0');
                            tx_bit_idx <= 0;
                            tx_parity  <= ctrl_reg(3);
                            tx_state   <= ST_TX_DATA;
                        else
                            tx_cnt <= tx_cnt + 1;
                        end if;

                    when ST_TX_DATA =>
                        uart_tx <= tx_shift(tx_bit_idx);
                        if tx_cnt >= (baud_div - 1) then
                            tx_cnt    <= (others => '0');
                            tx_parity <= tx_parity xor tx_shift(tx_bit_idx);
                            if tx_bit_idx = max_bits then
                                if ctrl_reg(2) = '1' then
                                    tx_state <= ST_TX_PARITY;
                                else
                                    tx_state <= ST_TX_STOP;
                                end if;
                            else
                                tx_bit_idx <= tx_bit_idx + 1;
                            end if;
                        else
                            tx_cnt <= tx_cnt + 1;
                        end if;

                    when ST_TX_PARITY =>
                        uart_tx <= tx_parity;
                        if tx_cnt >= (baud_div - 1) then
                            tx_cnt   <= (others => '0');
                            tx_state <= ST_TX_STOP;
                        else
                            tx_cnt <= tx_cnt + 1;
                        end if;

                    when ST_TX_STOP =>
                        uart_tx <= '1';
                        if ctrl_reg(4) = '0' then
                            if tx_cnt >= (baud_div - 1) then
                                tx_cnt   <= (others => '0');
                                tx_state <= ST_TX_IDLE;
                            else
                                tx_cnt <= tx_cnt + 1;
                            end if;
                        else
                            if tx_cnt >= (double_baud - 1) then
                                tx_cnt   <= (others => '0');
                                tx_state <= ST_TX_IDLE;
                            else
                                tx_cnt <= tx_cnt + 1;
                            end if;
                        end if;
                end case;
            end if;
        end if;
    end process;

    ----------------------------------------------------------------------------
    -- Receiver (RX) State Machine
    ----------------------------------------------------------------------------
    process(s_axi_aclk)
        variable max_bits  : integer range 4 to 7;
        variable half_baud : unsigned(15 downto 0);
    begin
        if rising_edge(s_axi_aclk) then
            if s_axi_aresetn = '0' then
                rx_sync1   <= '1'; rx_sync2 <= '1';
                rx_state   <= ST_RX_IDLE;
                rx_cnt     <= (others => '0');
                rx_bit_idx <= 0;
                rx_fifo_wr <= '0';
                err_status <= "000";
            else
                rx_sync1   <= uart_rx;
                rx_sync2   <= rx_sync1;
                rx_fifo_wr <= '0';

                max_bits  := to_integer(unsigned(ctrl_reg(1 downto 0))) + 4;
                half_baud := shift_right(baud_div, 1);

                case rx_state is
                    when ST_RX_IDLE =>
                        rx_cnt <= (others => '0');
                        if rx_sync2 = '0' then
                            rx_state <= ST_RX_START;
                        end if;

                    when ST_RX_START =>
                        if rx_cnt >= (half_baud - 1) then
                            rx_cnt <= (others => '0');
                            if rx_sync2 = '0' then
                                rx_bit_idx <= 0;
                                rx_parity  <= ctrl_reg(3);
                                rx_state   <= ST_RX_DATA;
                            else
                                rx_state <= ST_RX_IDLE;
                            end if;
                        else
                            rx_cnt <= rx_cnt + 1;
                        end if;

                    when ST_RX_DATA =>
                        if rx_cnt >= (baud_div - 1) then
                            rx_cnt <= (others => '0');
                            rx_shift(rx_bit_idx) <= rx_sync2;
                            rx_parity <= rx_parity xor rx_sync2;
                            if rx_bit_idx = max_bits then
                                if ctrl_reg(2) = '1' then
                                    rx_state <= ST_RX_PARITY;
                                else
                                    rx_state <= ST_RX_STOP;
                                end if;
                            else
                                rx_bit_idx <= rx_bit_idx + 1;
                            end if;
                        else
                            rx_cnt <= rx_cnt + 1;
                        end if;

                    when ST_RX_PARITY =>
                        if rx_cnt >= (baud_div - 1) then
                            rx_cnt <= (others => '0');
                            if rx_sync2 /= rx_parity then
                                err_status(0) <= '1';
                            end if;
                            rx_state <= ST_RX_STOP;
                        else
                            rx_cnt <= rx_cnt + 1;
                        end if;

                    when ST_RX_STOP =>
                        if rx_cnt >= (baud_div - 1) then
                            rx_cnt <= (others => '0');
                            if rx_sync2 = '0' then
                                err_status(1) <= '1';
                            elsif rx_fifo_full = '1' then
                                err_status(2) <= '1';
                            else
                                rx_fifo_din <= rx_shift;
                                rx_fifo_wr  <= '1';
                            end if;
                            rx_state <= ST_RX_IDLE;
                        else
                            rx_cnt <= rx_cnt + 1;
                        end if;
                end case;
            end if;
        end if;
    end process;

end architecture behavioral;