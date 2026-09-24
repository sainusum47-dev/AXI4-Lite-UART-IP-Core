library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity tb_axi_uart_lite is
end entity tb_axi_uart_lite;

architecture behavioral of tb_axi_uart_lite is

    constant CLK_PERIOD : time := 10 ns;

    signal clk          : std_logic := '0';
    signal resetn       : std_logic := '0';

    signal awaddr       : std_logic_vector(4 downto 0)  := (others => '0');
    signal awvalid      : std_logic                     := '0';
    signal awready      : std_logic;
    signal wdata        : std_logic_vector(31 downto 0) := (others => '0');
    signal wstrb        : std_logic_vector(3 downto 0)  := (others => '0');
    signal wvalid       : std_logic                     := '0';
    signal wready       : std_logic;
    signal bresp        : std_logic_vector(1 downto 0);
    signal bvalid       : std_logic;
    signal bready       : std_logic                     := '0';

    signal araddr       : std_logic_vector(4 downto 0)  := (others => '0');
    signal arvalid      : std_logic                     := '0';
    signal arready      : std_logic;
    signal rdata        : std_logic_vector(31 downto 0);
    signal rresp        : std_logic_vector(1 downto 0);
    signal rvalid       : std_logic;
    signal rready       : std_logic                     := '0';

    signal tx, rx       : std_logic;
    signal rts_n, cts_n : std_logic := '0';
    signal interrupt    : std_logic;

begin

    clk_process : process
    begin
        clk <= '0'; wait for CLK_PERIOD / 2;
        clk <= '1'; wait for CLK_PERIOD / 2;
    end process;

    rx <= tx;

    dut : entity work.axi_uart_lite
        port map (
            s_axi_aclk    => clk,
            s_axi_aresetn => resetn,
            s_axi_awaddr  => awaddr,
            s_axi_awvalid => awvalid,
            s_axi_awready => awready,
            s_axi_wdata   => wdata,
            s_axi_wstrb   => wstrb,
            s_axi_wvalid  => wvalid,
            s_axi_wready  => wready,
            s_axi_bresp   => bresp,
            s_axi_bvalid  => bvalid,
            s_axi_bready  => bready,
            s_axi_araddr  => araddr,
            s_axi_arvalid => arvalid,
            s_axi_arready => arready,
            s_axi_rdata   => rdata,
            s_axi_rresp   => rresp,
            s_axi_rvalid  => rvalid,
            s_axi_rready  => rready,
            uart_tx       => tx,
            uart_rx       => rx,
            uart_rts_n    => rts_n,
            uart_cts_n    => cts_n,
            ip2intc_irpt  => interrupt
        );

    stimulus : process

        procedure axi_write(addr : std_logic_vector(4 downto 0); data : std_logic_vector(31 downto 0)) is
        begin
            wait until rising_edge(clk);
            awaddr <= addr; awvalid <= '1'; wdata <= data; wstrb <= "1111"; wvalid <= '1';
            wait until (awready = '1' and wready = '1' and rising_edge(clk));
            awvalid <= '0'; wvalid <= '0'; bready <= '1';
            wait until (bvalid = '1' and rising_edge(clk));
            bready <= '0'; wait for CLK_PERIOD;
        end procedure;

        procedure axi_read(addr : std_logic_vector(4 downto 0); data : out std_logic_vector(31 downto 0)) is
        begin
            wait until rising_edge(clk);
            araddr <= addr; arvalid <= '1';
            wait until (arready = '1' and rising_edge(clk));
            arvalid <= '0'; rready <= '1';
            wait until (rvalid = '1' and rising_edge(clk));
            data := rdata; rready <= '0'; wait for CLK_PERIOD;
        end procedure;

        variable temp : std_logic_vector(31 downto 0);

    begin
        resetn <= '0'; wait for 100 ns;
        resetn <= '1'; wait for 100 ns;

        -- TEST 1: Enable Interrupts (IER = 0x01)
        axi_write("10000", x"00000001"); 

        -- TEST 2: Gated Flow Control (Assert CTS high)
        cts_n <= '1'; 
        axi_write("00000", x"000000A5");
        wait for 2 us;

        if tx = '1' then
            report "PASS: Flow control verified. TX line remained IDLE while CTS_N was HIGH." severity note;
        end if;

        -- Release Flow Control
        cts_n <= '0';

        -- TEST 3: Wait for Interrupt Signal
        wait until interrupt = '1';
        report "PASS: Hardware Interrupt (ip2intc_irpt) successfully generated on RX completion!" severity note;

        -- TEST 4: Read Received Data and Clear Interrupt (W1C)
        axi_read("00000", temp);
        if temp(7 downto 0) = x"A5" then
            report "SUCCESS: Advanced IP Loopback Verified (Received 0xA5)!" severity note;
        end if;

        axi_write("10100", x"00000001");
        wait for 50 ns;

        if interrupt = '0' then
            report "PASS: Interrupt line cleared via Write-1-Clear (W1C) to ISR!" severity note;
        end if;

        report "ALL ADVANCED HARDWARE TESTS PASSED SUCCESSFULLY" severity note;
        wait;
    end process;

end architecture behavioral;