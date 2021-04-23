LIBRARY ieee;
USE ieee.std_logic_1164.all;

ENTITY PRSGenerator IS
    PORT
    (
      clk       : in std_logic;
      rst       : in std_logic;
      en        : in std_logic;
      init      : in std_logic_vector(31 downto 0);
      result    : out std_logic_vector(31 downto 0);
      num_state : out integer
    );
END PRSGenerator;


ARCHITECTURE SYN OF PRSGenerator IS
    signal s    : std_logic_vector(31 downto 0);

BEGIN

process(rst, clk)
begin
  if (rst = '1') then 
    s <= init;
    num_state <= 0;
  elsif rising_edge(clk) then
    if (en = '1') then
      s <= (((s(0) xor s(25)) xor (s(27) xor s(29))) xor (s(30) xor s(31))) & s(31 downto 1);
      num_state <= num_state + 1;
    end if;
  end if;
end process;

result <= s;

END SYN;
