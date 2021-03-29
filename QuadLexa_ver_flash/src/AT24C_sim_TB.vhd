----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 28.07.2020 14:33:37
-- Design Name: 
-- Module Name: AT24C_sim_TB - Behavioral
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
use IEEE.MATH_REAL.ALL;

library work;
use work.AT24C_master;
use work.CRC32;
--use work.PRSGenerator;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity AT24C_sim_TB is
end AT24C_sim_TB;

architecture Behavioral of AT24C_sim_TB is
    signal clk                  : std_logic;
    signal rst                  : std_logic:= '1';
    signal addr                 : std_logic_vector(natural(log2(real(4096/4 - 1))) - 1 downto 0) := "1011011111";
    signal data_in              : std_logic_vector(31 downto 0) := x"55016633";
    signal wr_en                : std_logic := '0';
    signal wr_ack               : std_logic;
    signal data_out             : std_logic_vector(31 downto 0) := (others => '0');
    signal rd_en                : std_logic := '0';
    signal rd_ack               : std_logic := '0';
    signal error                : std_logic;
    signal busy_out             : std_logic;
    signal sda                  : std_logic;
    signal scl                  : std_logic;
    type stm    is (idle, wr, ready);
    signal state                : stm;
    signal PRSGenerator_result  : std_logic_vector(31 downto 0);
    
    type param_struct       is (par1, par2, par3, StructureLength);
    type param_type is array (param_struct'pos(StructureLength) - 1 downto 0) of std_logic_vector(31 downto 0);
    signal params               : param_type;
    type memory_type   is array (param_struct'pos(StructureLength)*2 - 1 downto 0) of std_logic_vector(31 downto 0);
    signal memory               : memory_type;
    type mem_stm            is (idle);
    signal crc                  : std_logic_vector(31 downto 0);
    signal CRC32_din            : std_logic_vector(7 downto 0);
    signal CRC32_wr_ack         : std_logic;

begin
clk_gen_process:
  process
  begin
    clk <= '0';
    wait for 8 ns;
    clk <= '1';
    wait for 8 ns;
  end process;

  rst <= '0' after 100 ns;

main_proc :
  process(clk, rst)
  begin
    if (rst = '1') then
      wr_en <= '0';
      rd_en <= '0';
      state <= idle;
    elsif rising_edge(clk) then
      case (state) is
        when idle =>
          if (busy_out = '0') then
            rd_en <= '1';
            state <= wr;
          end if;
        when wr =>
          if (rd_en = '1') and (busy_out = '1') then
            rd_en <= '0';
            state <= ready;
          end if;
        when others =>
          
      end case;
    end if;
  end process;
  
process(clk, rst)
begin
  if (rst = '1') then
    CRC32_din <= ( others => '0');
  elsif rising_edge(clk) then
    if (CRC32_wr_ack = '1') then
      CRC32_din <= CRC32_din + 1;
    end if;
  end if;
end process;

--PRSGenerator_inst : ENTITY PRSGenerator
--    PORT MAP
--    (
--      clk       => clk,
--      rst       => rst,
--      en        => '1',
--      init      => x"08010426",
--      result    => PRSGenerator_result
--    );

CRC32_inst : ENTITY CRC32
    PORT MAP(
      clk       => clk,
      rst       => rst,
      din       => CRC32_din,
      wr_en     => '1',
      wr_ack    => CRC32_wr_ack, 
      crc_out   => crc,
      valid     => open
    );

AT24C_master_inst : entity AT24C_master
    Generic map(
      c_mem_range       => 4096,
      c_div_clk         => 2
      )
    Port map(
      clk           => clk       ,
      rst           => rst       ,
      addr          => addr      ,
      data_in       => data_in   ,
      wr_en         => wr_en     ,
      wr_ack        => wr_ack    ,
      data_out      => data_out  ,
      rd_en         => rd_en     ,
      rd_ack        => rd_ack    ,
      error         => error     ,
      busy_out      => busy_out  ,
      sda           => sda       ,
      scl           => scl       
    );

end Behavioral;
