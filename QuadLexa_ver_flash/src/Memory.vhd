library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
 
entity Memory is
  generic (
      c_data_width    : integer := 32;
      c_buff_length   : integer := 512
    );
  port (
    clk     : in std_logic;
    address : in integer;
    wr_en   : in std_logic;
    wr_ack  : out std_logic;
    wr_data : in std_logic_vector(c_data_width - 1 downto 0);
    rd_en   : in std_logic;
    rd_data : out std_logic_vector(c_data_width - 1 downto 0);
    rd_ack  : out std_logic
  );
end Memory;
 
 
architecture RTL of Memory is
  type memory_type  is array(0 to c_buff_length - 1) of std_logic_vector(c_data_width - 1 downto 0);
  signal mem        : memory_type;

begin

wr_proc :
  process(clk)
  begin
    if rising_edge(clk) then
      if ((wr_en = '1') and (address <= c_buff_length - 1)) then
        mem(address) <= wr_data;
        wr_ack <= '1';
      else
        wr_ack <= '0';
      end if;
    end if;
  end process;

rd_proc :
  process(clk)
  begin
    if rising_edge(clk) then
      if ((rd_en = '1') and (address <= c_data_width - 1)) then
        rd_data <= mem(address);
        rd_ack <= '1';
      else
        rd_ack <= '0';
      end if;
    end if;
  end process;

end RTL;