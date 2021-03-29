

LIBRARY ieee;
USE ieee.std_logic_1164.all;

ENTITY ddr_receiver IS
  PORT(
    clk     : in std_logic;
    i       : in std_logic;
    o       : out std_logic_vector(1 downto 0)
  );

END ddr_receiver;

ARCHITECTURE logic OF ddr_receiver IS
    signal edge_reg : std_logic;
    signal fall_reg : std_logic;
    signal clk_n    : std_logic;

BEGIN

clk_n <= not clk;

edge_proc :
process(clk)
begin
  if rising_edge(clk) then
    edge_reg <= i;
  end if;
end process;

fall_proc :
process(clk_n)
begin
  if rising_edge(clk_n) then
    fall_reg <= i;
  end if;
end process;

out_proc :
process(clk)
begin
  if rising_edge(clk) then
   -- o <= fall_reg & edge_reg;
    o <= edge_reg & fall_reg;
  end if;
end process;


END logic;
