----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 14.02.2020 15:09:56
-- Design Name: 
-- Module Name: spi_master_module - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_unsigned.ALL;


-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity spi_master_module is
    Generic(
      c_wr_divider_div2    : integer := 3; -- Round((clk_frq/wr_sck_freq)/2)
      c_rd_divider_div2    : integer := 16 -- Round((clk_frq/rd_sck_freq)/2)
    );
    Port (
      clk       : in std_logic;
      rst       : in std_logic;
      addr      : in std_logic_vector(7 downto 0);
      wr_data   : in std_logic_vector(7 downto 0);
      wr_en     : in std_logic;
      rd_data   : out std_logic_vector(7 downto 0);
      rd_en     : in std_logic;
      rd_valid  : out std_logic;
      ready     : out std_logic;
      spi_cs    : out std_logic;
      spi_sck   : out std_logic;
      spi_sdi   : out std_logic;
      spi_sdo   : in std_logic
    
    );
end spi_master_module;

architecture Behavioral of spi_master_module is
    signal sck_divide_counter       : std_logic_vector(32 - 1 downto 0);
    type state_machine           is (idle_state, rdy_state, addr_state, data_state, end_state);
    signal state, next_state        : state_machine;
    signal rdwr_n                   : std_logic;
    signal sck                      : std_logic;
    signal sck_d1                   : std_logic;
    signal sck_edge_counter         : std_logic_vector(2 downto 0);
    signal sck_fall_counter         : std_logic_vector(2 downto 0);
    signal sck_edge8                : std_logic;
    signal sck_edge8_d1             : std_logic;
    signal edge8                    : std_logic;
    signal sck_fall8                : std_logic;
    signal sck_fall8_d1             : std_logic;
    signal fall8                    : std_logic;
    signal rdy                      : std_logic;
    signal start                    : std_logic;
    signal wr_reg                   : std_logic_vector(wr_data'length + addr'length downto 0);
    signal sck_fall                 : std_logic;
    signal sck_edge                 : std_logic;
    signal rd_data_reg              : std_logic_vector(rd_data'length - 1 downto 0);
    signal del                      : std_logic;
begin

start <= (wr_en and rdy) XOR (rd_en and rdy);

sck_process:
process(clk, state)
begin
  if (state = idle_state) or (state = rdy_state) then
    sck <= '1';
    sck_divide_counter <= (others => '0');
  else
    if rising_edge(clk) then
      if ((sck_divide_counter = c_wr_divider_div2) and (rdwr_n = '0')) or ((sck_divide_counter = c_rd_divider_div2) and (rdwr_n = '1')) then
        sck_divide_counter <= (others => '0');
        sck <= not sck;
      else
        sck_divide_counter <= sck_divide_counter + 1;
      end if;
    end if;
  end if;
end process;

rd_data_reg_proc :
process(clk)
begin 
  if rising_edge(clk) then
    if (rdwr_n = '1') and (sck_edge = '1') then
      rd_data_reg(rd_data_reg'length - 1 downto 1) <= rd_data_reg(rd_data_reg'length - 2 downto 0);
      rd_data_reg(0) <= spi_sdo;
    end if;
  end if;
end process;

rd_data_proc :
process(clk, state)
begin 
  if (state = idle_state) then
    rd_valid <= '0';
  elsif rising_edge(clk) then
    if (state = data_state) then
      if (rdwr_n = '1') and (edge8 = '1') then
        rd_data <= rd_data_reg;
        rd_valid <= '1';
      end if;
    end if;
  end if;
end process;

sck_fall <= (not sck) and sck_d1;
sck_edge <= sck and (not sck_d1);

process(clk)
begin
  if rising_edge(clk) then
    sck_d1 <= sck;
    if (start = '1') then 
      rdwr_n <= addr(addr'length - 1);
      wr_reg <= '1' & addr & wr_data;
    elsif (sck_fall = '1') then
      wr_reg(wr_reg'length - 1 downto 1) <= wr_reg(wr_reg'length - 2 downto 0);
      wr_reg(0) <= '0';
    end if;
  end if;
end process;

sck_edge_counter_proc :
process(clk, state)
begin
  if (state = idle_state) then
    sck_edge_counter <= (others => '0');
    sck_edge8 <= '0';
  elsif rising_edge(clk) then
    if (sck_edge = '1') then
      if (sck_edge_counter = "111") then
        sck_edge_counter <= (others => '0');
        sck_edge8 <= '1';
      else
        sck_edge_counter <= sck_edge_counter + 1;
        sck_edge8 <= '0';
      end if;
    end if;
    sck_edge8_d1 <= sck_edge8;
    edge8 <= sck_edge8 and (not sck_edge8_d1);
  end if;
end process;

sck_fall_counter_proc :
process(clk, state)
begin
  if (state = idle_state) then
    sck_fall_counter <= (others => '0');
    sck_fall8 <= '0';
  elsif rising_edge(clk) then
    if (sck_fall = '1') then
      if (sck_fall_counter = "111") then
        sck_fall8 <= '1';
        sck_fall_counter <= (others => '0');
      else
        sck_fall_counter <= sck_fall_counter + 1;
        sck_fall8 <= '0';
      end if;
    end if;
    sck_fall8_d1 <= sck_fall8;
    fall8 <= sck_fall8 and (not sck_fall8_d1);
  end if;
end process;

state_sync_process :
process(rst, clk)
begin
  if (rst = '1') then
    state <= idle_state;
  elsif rising_edge(clk) then
    state <= next_state;
  end if;
end process;

next_state_process :
process(state, start, edge8, sck_fall)
begin
  next_state <= state;
  case (state) is
    when idle_state =>
      next_state <= rdy_state;
    when rdy_state =>
      if (start = '1') then 
        next_state <= addr_state;
      end if;
    when addr_state =>
      if (edge8 = '1') then 
        next_state <= data_state;
      end if;
    when data_state => 
      if (edge8 = '1') then 
        next_state <= end_state;
      end if;
    when end_state => 
      if (sck_fall = '1') then 
        next_state <= idle_state;
      end if;
    when others =>
      next_state <= idle_state;
  end case;
end process;

out_process:
process(state, sck, wr_reg(wr_reg'length - 1))
begin
  spi_cs <= '0';
  spi_sck <= sck;
  spi_sdi <= wr_reg(wr_reg'length - 1);
  rdy <= '0';
  case (state) is
    when rdy_state =>
      rdy <= '1';
      spi_sck <= 'H';
      spi_sdi <= 'H';
      spi_cs <= '1';
    when idle_state =>
      spi_sck <= 'H';
      spi_sdi <= 'H';
      spi_cs <= '1';
    when end_state =>
      spi_sck <= '1';
    when others =>
  end case;
end process;

ready <= rdy;

end Behavioral;
