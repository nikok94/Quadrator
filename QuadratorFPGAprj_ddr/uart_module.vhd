library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_unsigned.ALL;

library work;
use work.UART_TX;
use work.UART_RX;
use work.FIFO32x8;
use work.FIFO8x32;



entity uart_module is
  Generic(
    c_freq_hz              : integer := 125000000;
    c_boad_rate            : integer := 921600
  );
  Port(
    clk             : in std_logic;
    rst             : in std_logic;
    tx_data         : in std_logic_vector(31 downto 0);
    tx_valid        : in std_logic;
    tx_ready        : out std_logic;
    txd             : out std_logic;
    rx_data         : out std_logic_vector(31 downto 0);
    rx_valid        : out std_logic;
    rx_ready        : in std_logic;
    rxd             : in std_logic
  );
end uart_module;

architecture Behavioral of uart_module is
    constant g_CLKS_PER_BIT     : integer := c_freq_hz/c_boad_rate;
    signal tx_fifo_rdreq        : std_logic;
    signal tx_fifo_wrreq        : std_logic;
    signal tx_fifo_empty        : std_logic;
    signal tx_fifo_full         : std_logic;
    signal tx_fifo_q            : std_logic_vector(7 downto 0);
    signal uart_RX_DV           : std_logic;
    signal uart_RX_Byte         : std_logic_vector(7 downto 0);
    signal uart_TX_DV           : std_logic;
    signal uart_TX_Active       : std_logic;
    signal uart_TX_Done         : std_logic;
    signal uart_TX_Byte         : std_logic_vector(7 downto 0);
    signal rx_fifo_rdreq        : std_logic;
    signal rx_fifo_wrreq        : std_logic;
    signal rx_fifo_empty        : std_logic;
    signal rx_fifo_full         : std_logic;
    signal rx_fifo_q            : std_logic_vector(7 downto 0);
begin

UART_TX_inst    : entity UART_TX
  generic map(
    g_CLKS_PER_BIT => g_CLKS_PER_BIT
    )
  port map(
    i_Clk       => clk,
    i_TX_DV     => uart_TX_DV,
    i_TX_Byte   => uart_TX_Byte,
    o_TX_Active => uart_TX_Active,
    o_TX_Serial => txd,
    o_TX_Done   => uart_TX_Done
    );

uart_TX_DV <= not tx_fifo_empty;
uart_TX_Byte <= tx_fifo_q;

tx_fifo_rdreq <= uart_TX_Active and uart_TX_Done;

tx_fifo_wrreq <= tx_valid and (not tx_fifo_full);
tx_ready <= not tx_fifo_full;

TX_FIFO_inst : ENTITY FIFO32x8
    PORT MAP
    (
        aclr        => rst,
        data        => tx_data,
        rdclk       => clk,
        rdreq       => tx_fifo_rdreq,
        wrclk       => clk,
        wrreq       => tx_fifo_wrreq,
        q           => tx_fifo_q,
        rdempty     => tx_fifo_empty,
        wrfull      => tx_fifo_full
    );

rx_valid <= not rx_fifo_empty;
rx_fifo_rdreq <= rx_ready and (not rx_fifo_empty);

RX_FIFO_inst : ENTITY FIFO8x32
    PORT MAP
    (
        aclr        => rst,
        data        => uart_RX_Byte,
        rdclk       => clk,
        rdreq       => rx_fifo_rdreq,
        wrclk       => clk,
        wrreq       => rx_fifo_wrreq,
        q           => rx_data,
        rdempty     => rx_fifo_empty,
        wrfull      => rx_fifo_full
    );

rx_fifo_wrreq <= uart_RX_DV and (not rx_fifo_full);

UART_RX_inst    : entity UART_RX
  generic map(
    g_CLKS_PER_BIT => g_CLKS_PER_BIT
    )
  port map(
    i_Clk       => clk,
    i_RX_Serial => rxd,
    o_RX_DV     => uart_RX_DV,
    o_RX_Byte   => uart_RX_Byte
    );

end Behavioral;