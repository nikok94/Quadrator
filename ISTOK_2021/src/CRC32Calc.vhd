LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.std_logic_unsigned.all;
use IEEE.MATH_REAL.ALL;
use IEEE.Std_Logic_Arith.all;

library work;
use work.CRC32;

ENTITY CRC32Calc IS
    GENERIC (
      c_din_byte_whidth        : integer := 4
    );
    PORT (
      clk       : in std_logic;
      rst       : in std_logic;
      din       : in std_logic_vector(c_din_byte_whidth*8 - 1 downto 0);
      wr_en     : in std_logic;
      wr_ack    : out std_logic;
      crc_out   : out std_logic_vector(31 downto 0);
      valid     : out std_logic
    );
END CRC32Calc;


ARCHITECTURE SYN OF CRC32Calc IS
  signal crc32_din      : in std_logic_vector(7 downto 0);


BEGIN

CRC32_inst : ENTITY CRC32
    PORT MAP(
      clk       => clk,
      rst       => rst,
      din       : in std_logic_vector(7 downto 0);
      wr_en     : in std_logic;
      wr_ack    : out std_logic;
      crc_out   : out std_logic_vector(31 downto 0);
      valid     : out std_logic
    );



END SYN;
