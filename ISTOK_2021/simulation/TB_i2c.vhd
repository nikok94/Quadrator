 LIBRARY ieee;
 USE ieee.std_logic_1164.all;
 
 library work;
 use work.i2c_master;

 ENTITY  TB_i2c IS 
 END TB_i2c;

 ARCHITECTURE RTL OF TB_i2c IS
  constant c_sys_clk_Hz                  : integer := 125_000_000;
  signal reset_n                         : std_logic := '0';
  signal i2c_ena                         : STD_LOGIC;                   
  signal i2c_addr                        : STD_LOGIC_VECTOR(6 DOWNTO 0);
  signal i2c_rw                          : STD_LOGIC;                   
  signal i2c_data_wr                     : STD_LOGIC_VECTOR(7 DOWNTO 0);
  signal i2c_busy                        : STD_LOGIC;                   
  signal i2c_data_rd                     : STD_LOGIC_VECTOR(7 DOWNTO 0);
  signal i2c_ack_error                   : STD_LOGIC;
  signal i2c_sda                         : std_logic;
  signal i2c_scl                         : std_logic;
  signal clk_125MHz                      : std_logic;

 BEGIN

process 
begin


i2c_master_inst: ENTITY i2c_master
  GENERIC map(
    input_clk   => c_sys_clk_Hz,
    bus_clk     => 400_000
    )
  PORT map(
    clk         => clk_125MHz,
    reset_n     => reset_n,
    ena         => i2c_ena,
    addr        => i2c_addr,
    rw          => i2c_rw,
    data_wr     => i2c_data_wr,
    busy        => i2c_busy,
    data_rd     => i2c_data_rd,
    ack_error   => i2c_ack_error,
    sda         => i2c_sda,
    scl         => i2c_scl
    );


 END RTL;