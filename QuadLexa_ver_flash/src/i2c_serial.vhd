----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 29.07.2020 17:13:23
-- Design Name: 
-- Module Name: i2c_serial - Behavioral
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

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity i2c_serial is
    generic(
      c_data_width  : integer := 9;
      c_clk_div     : integer := 16
    );
    port (
      clk       : in std_logic;
      rst       : in std_logic;
      din       : in std_logic_vector(c_data_width - 1 downto 0);
      wr_en     : in std_logic;
      start     : in std_logic;
      stop      : in std_logic;
      ready     : out std_logic;
      busy      : out std_logic;
      dout      : out std_logic_vector(c_data_width - 1 downto 0);
      valid     : out std_logic;
      sda       : inout std_logic;
      scl       : inout std_logic
    );
end i2c_serial;

architecture Behavioral of i2c_serial is
  type stm  is (idle, cmd_st, start_st, start_st1, start_st2, data_st0, data_st1, work_st, stop_st0, stop_st1, start_delay);
  signal state          : stm;
  signal sdata, sclk    : std_logic;
  signal counter        : integer;
  signal treg           : std_logic_vector(c_data_width - 1 downto 0);
  signal rreg           : std_logic_vector(c_data_width - 1 downto 0);
  signal sclk_counter   : integer;

begin

sda <= '0' when sdata = '0' else 'Z';
scl <= '0' when sclk = '0' else 'Z';

process(rst, clk)
begin
  if (rst = '1') then
    state <= idle;
    sdata <= '1';
    sclk <= '1';
    busy <= '1';
    ready <= '0';
    valid <= '0';
    counter <= 0;
  elsif rising_edge(clk) then
    case (state) is
      when idle =>
        sclk <= '1';
        sdata <= '1';
        if (counter < c_clk_div - 1) then
           counter <= counter + 1;
        else
          counter <= 0;
          ready <= '1';
          busy <= '0';
          state <= cmd_st;
          sclk_counter <= 0;
       end if;
      when cmd_st =>
        if (start = '1') then
          state <= start_st;
          busy <= '1';
          ready <= '0';
          sdata <= '0';
          sclk <= '1';
        elsif (stop = '1') then 
          state <= stop_st0;
          sdata <= '0';
          sclk <= '0';
          ready <= '0';
          busy <= '1';
          counter <= 0;
        elsif (wr_en = '1') then
          state <= data_st0;
          busy <= '1';
          ready <= '0';
          treg <= din;
        end if;
      when data_st0 =>
        if (sclk_counter < c_data_width) then
          sdata <= treg(treg'length - 1);
          sclk <= '0';
          if (counter < c_clk_div - 1) then
            counter <= counter + 1;
          else
            counter <= 0;
            rreg(rreg'length - 1 downto 1) <= rreg(rreg'length - 2 downto 0);
            rreg(0) <= sda;
            state <= data_st1;
          end if;
        else
          sclk <= '1';
          sdata <= '1';
          ready <= '1';
          state <= work_st;
          sclk_counter <= 0;
          valid <= '1';
          dout <= rreg;
        end if;
      when data_st1 =>
          sdata <= treg(treg'length - 1);
          sclk <= '1';
          if (counter < c_clk_div - 1) then
            counter <= counter + 1;
          else
            counter <= 0;
            sclk_counter <= sclk_counter + 1;
            treg(treg'length - 1 downto 1) <= treg(treg'length - 2 downto 0);
            treg(0) <= '1';
            state <= data_st0;
          end if;
      when start_st =>
        if (sclk = '0') then
          if (sdata = '0') then
            sdata <= '1';
          end if;
          if (counter < c_clk_div - 1) then
            counter <= counter + 1;
          else
            counter <= 0;
            sclk <= '1';
          end if;
        else
          if (counter < c_clk_div - 1) then
            counter <= counter + 1;
          else
            counter <= 0;
            sdata <= '0';
            state <= start_delay;
          end if;
        end if;
      when start_delay =>
        if (counter < c_clk_div - 1) then
          counter <= counter + 1;
        else
          counter <= 0;
          ready <= '1';
          state <= work_st;
        end if;
      when work_st =>
        valid <= '0';
        if (stop = '1') then
          state <= stop_st0;
          sdata <= '0';
          sclk <= '0';
          ready <= '0';
          counter <= 0;
        elsif (wr_en = '1') then
          state <= data_st0;
          sclk_counter <= 0; 
          ready <= '0';
          treg <= din;
        elsif (start = '1') then
          state <= start_st;
          ready <= '0';
          sclk <= '0';
          counter <= 0;
        end if;
      when stop_st0 =>
        if (counter < c_clk_div - 1) then
          counter <= counter + 1;
        else
          counter <= 0;
          sclk <= '1';
          state <= stop_st1;
        end if;
      when stop_st1 =>
        if (counter < c_clk_div - 1) then
          counter <= counter + 1;
        else
          counter <= 0;
          state <= idle;
        end if;
      when others =>
        state <= idle;
    end case; 
  end if;
end process;


end Behavioral;
