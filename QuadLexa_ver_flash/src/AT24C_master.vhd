----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 28.07.2020 14:33:37
-- Design Name: 
-- Module Name: AT24C_master - Behavioral
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
use IEEE.MATH_REAL.ALL;

library work;
use work.i2c_serial;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity AT24C_master is
    Generic(
      c_mem_range       : integer := 4096;
      c_div_clk         : integer := 16
      );
    Port(
      clk           : in std_logic;
      rst           : in std_logic;
      addr          : in std_logic_vector(natural(log2(real(c_mem_range/4 - 1))) - 1 downto 0);
      data_in       : in std_logic_vector(31 downto 0);
      wr_en         : in std_logic;
      wr_ack        : out std_logic;
      data_out      : out std_logic_vector(31 downto 0) := (others => '0');
      rd_en         : in std_logic;
      rd_ack        : out std_logic := '0';
      error         : out std_logic;
      busy_out      : out std_logic;
      sda           : inout std_logic;
      scl           : inout std_logic
    );
end AT24C_master;

architecture Behavioral of AT24C_master is
    signal wreg             : std_logic_vector(31 downto 0);
    signal w_ack            : std_logic;
    type stm    is (idle, cmd_st, w_start_st, r_start_st, w_data, error_st, stop_st, r_data, dummy_write, dummy_write_start, rd_byte_stop);
    signal state            : stm;
    signal i2c_rst          : std_logic;
    signal i2c_en           : std_logic;
    signal i2c_din          : std_logic_vector(8 downto 0);
    signal i2c_dout         : std_logic_vector(8 downto 0);
    signal i2c_valid        : std_logic;
    signal i2c_busy         : std_logic;
    signal i2c_busy_d       : std_logic;
    signal i2c_busy_up      : std_logic;
    signal i2c_ack          : std_logic;
    type buff_struct     is (DEVICE_ADDRESS, FIRST_WORD_ADDRESS, SECOND_WORD_ADDRESS, DATA0, DATA1, DATA2, DATA3, StructureLength);
    type buff_type       is array(buff_struct'pos(StructureLength) - 1 downto 0) of std_logic_vector(7 downto 0);
    signal i2c_buff         : buff_type := (others => (others => '0'));
    signal i2c_reset        : std_logic;
    signal i2c_wr_en        : std_logic;
    signal i2c_start        : std_logic;
    signal i2c_stop         : std_logic;
    signal i2c_ready        : std_logic;
    signal i2c_ready_d      : std_logic;
    signal counter          : integer := 0;
    signal word_addr        : std_logic_vector(15 downto 0):= (others => '0');
--    type data_byte_buff_struct is (byte3, byte2, byte1, byte0, StructureLength);
--    signal data_byte_buff   : data_byte_buff_struct;
    type i2c_cmd_buff_struct is array (7 downto 0) of std_logic_vector(8 downto 0);
    signal i2c_cmd_buff     : i2c_cmd_buff_struct;
    signal r_byte_counter   : integer;
    signal r_data_buff      : std_logic_vector(31 downto 0);

begin

word_addr(addr'length - 1 downto 0) <= addr;

process(clk, rst)
begin
  if (rst = '1') then
    state <= idle;
    i2c_reset <= '1';
    i2c_wr_en <= '0';
    i2c_start <= '0';
    i2c_stop <= '0';
    rd_ack <= '0';
    error <= '0';
    busy_out <= '1';
    wr_ack <= '0';
  elsif rising_edge(clk) then
    case (state) is
      when idle =>
        if (i2c_ready = '1') then
          state <= cmd_st;
          busy_out <= '0';
        end if;
        i2c_reset <= '0';
      when cmd_st =>
        if (wr_en = '1') then
          state <= w_start_st;
          i2c_cmd_buff(0) <= "10100000" & '1';
          i2c_cmd_buff(1) <= word_addr(7 + 8*0 downto 0 + 8*0) & '1';
          i2c_cmd_buff(2) <= word_addr(7 + 8*1  downto 0 + 8*1) & '1';
          i2c_cmd_buff(3) <= data_in(7 + 8*0 downto 0 + 8*0) & '1';
          i2c_cmd_buff(4) <= data_in(7 + 8*1 downto 0 + 8*1) & '1';
          i2c_cmd_buff(5) <= data_in(7 + 8*2 downto 0 + 8*2) & '1';
          i2c_cmd_buff(6) <= data_in(7 + 8*3 downto 0 + 8*3) & '1';
          counter <= 0;
          i2c_start <= '1';
          busy_out <= '1';
          error <= '0';
--          data_byte_buff(data_byte_buff_struct'pos(byte0)) <= data_in(7 + 8*0 downto 0 + 8*0);
--          data_byte_buff(data_byte_buff_struct'pos(byte1)) <= data_in(7 + 8*1 downto 0 + 8*1);
--          data_byte_buff(data_byte_buff_struct'pos(byte2)) <= data_in(7 + 8*2 downto 0 + 8*2);
--          data_byte_buff(data_byte_buff_struct'pos(byte3)) <= data_in(7 + 8*3 downto 0 + 8*3);
        elsif (rd_en = '1') then
          state <= dummy_write_start;
          busy_out <= '1';
          i2c_cmd_buff(0) <= "10100000" & '1';
          i2c_cmd_buff(1) <= word_addr(7 + 8*0 downto 0 + 8*0) & '1';
          i2c_cmd_buff(2) <= word_addr(7 + 8*1 downto 0 + 8*1) & '1';
          i2c_cmd_buff(3) <= "10100001" & '1';
          i2c_cmd_buff(4) <= (others => '1');
          i2c_cmd_buff(5) <= (others => '1');
          i2c_cmd_buff(6) <= (others => '1');
          i2c_cmd_buff(7) <= (others => '1');
          counter <= 0;
          i2c_start <= '1';
          error <= '0';
        end if;
      when w_start_st =>

        if (i2c_busy = '1') then
          i2c_start <= '0';
        end if;

        if ((i2c_ready = '1') and (i2c_start = '0')) then
          state <= w_data;
          i2c_wr_en <= '1';
        end if;

      when w_data =>
        if (i2c_valid = '1') then
          if (counter < 6) then 
            if (i2c_dout(0) = '1') then
              state <= error_st;
            else
              counter <= counter + 1;
              i2c_wr_en <= '1';
            end if;
          else
            state <= stop_st;
            wr_ack <= '1';
            i2c_stop <= '1';
          end if;
        else
          i2c_wr_en <= '0';
        end if;
      when dummy_write_start =>
        i2c_start <= '0';

        if (i2c_busy = '1') then
          i2c_start <= '0';
        end if;

        if ((i2c_ready = '1') and (i2c_start = '0')) then
          state <= dummy_write;
          i2c_wr_en <= '1';
        end if;
      when r_start_st => 
        i2c_start <= '0';

        if (i2c_busy = '1') then
          i2c_start <= '0';
        end if;

        if ((i2c_ready = '1') and (i2c_start = '0')) then
          state <= r_data;
          i2c_wr_en <= '1';
        end if;
      when dummy_write => 
        if (i2c_valid = '1') then
          if (counter < 2) then 
            if (i2c_dout(0) = '1') then
              state <= error_st;
            else
              counter <= counter + 1;
              i2c_wr_en <= '1';
            end if;
          else
            state <= r_start_st;
            counter <= counter + 1;
            i2c_start <= '1';
            r_byte_counter <= 0;
          end if;
        else
          i2c_wr_en <= '0';
        end if;

      when r_data =>
        if (i2c_valid = '1') then
          if (counter < 4) then 
            if (i2c_dout(0) = '1') then
              state <= error_st;
            else
              counter <= counter + 1;
              i2c_wr_en <= '1';
            end if;
          else
            r_data_buff(r_byte_counter * 8 + 7 downto r_byte_counter * 8) <= i2c_dout(8 downto 1);
            if (r_byte_counter < 3) then
              r_byte_counter <= r_byte_counter + 1;
              counter <= 3;
              state <= rd_byte_stop;
              i2c_stop <= '1';
            else
              state <= stop_st;
              rd_ack <= '1';
              data_out <= i2c_dout(8 downto 1) & r_data_buff(3*8 - 1 downto 0);
              i2c_stop <= '1';
            end if;
          end if;
        else
          i2c_wr_en <= '0';
        end if;

      when rd_byte_stop =>
        if (i2c_ready = '0') then
          i2c_stop <= '0';
        end if;
        if ((i2c_ready = '1') and (i2c_stop = '0')) then
          state <= r_start_st;
          i2c_start <= '1';
        end if;

      when stop_st =>
        wr_ack <= '0';
        rd_ack <= '0';
        if (i2c_ready = '0') then
          i2c_stop <= '0';
        end if;
        if ((i2c_ready = '1') and (i2c_stop = '0')) then
          state <= cmd_st;
          busy_out <= '0';
        end if;
      when error_st =>
        error <= '1';
        state <= stop_st;
        i2c_stop <= '1';
      when others =>
        state <= idle;
        i2c_reset <= '1';
        i2c_wr_en <= '0';
        i2c_start <= '0';
        i2c_stop <= '0';
        rd_ack <= '0';
        error <= '0';
        busy_out <= '1';
        wr_ack <= '0';
    end case;
  end if;
end process;

i2c_din <= i2c_cmd_buff(counter);
i2c_rst <= rst or i2c_reset;

i2c_serial_inst : entity i2c_serial
    generic map(
      c_data_width  => 9,
      c_clk_div     => c_div_clk
    )
    port map(
      clk       => clk,
      rst       => i2c_rst,
      din       => i2c_din,
      wr_en     => i2c_wr_en,
      start     => i2c_start,
      stop      => i2c_stop,
      ready     => i2c_ready,
      busy      => i2c_busy,
      dout      => i2c_dout,
      valid     => i2c_valid,
      sda       => sda,
      scl       => scl
    );

end Behavioral;
