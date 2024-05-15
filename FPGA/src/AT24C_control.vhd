----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 28.07.2020 14:33:37
-- Design Name: 
-- Module Name: AT24C_control - Behavioral
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

entity AT24C_control is
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
end AT24C_control;

architecture Behavioral of AT24C_control is
    signal wreg             : std_logic_vector(31 downto 0);
    signal w_ack            : std_logic;
    type stm    is (idle, cmd_st, w_start_st, r_start_st, w_data, w_data_status, wr_r_addr_st, wr_r_addr_status, r_data, r_data_status, err_ack_st, stop_st, rd_ready, r_start0_st, r_data0, r_data0_status);
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
    signal counter          : integer;

begin
process(clk, rst)
begin
  if (rst = '1') then
    state <= stop_st;
    wr_ack <= '0';
    rd_ack <= '0';
    error <= '0';
    i2c_reset  <= '1';
    i2c_stop <= '1';
    busy_out <= '1';
  elsif rising_edge(clk) then
    i2c_ready_d <= i2c_ready;
    case (state) is
      when idle =>
        state <= cmd_st;
        i2c_wr_en <= '0';
        counter <= 0;
        error <= '0';
        i2c_reset <= '0';
        busy_out <= '0';
      when cmd_st =>
        if (wr_en = '1') then
          i2c_buff(buff_struct'pos(DEVICE_ADDRESS)) <= "10100000";
          i2c_buff(buff_struct'pos(FIRST_WORD_ADDRESS))(addr'length - 9 downto 0) <= addr(addr'length - 3 downto 6);
          i2c_buff(buff_struct'pos(SECOND_WORD_ADDRESS))(7 downto 0) <= addr(5 downto 0) & "00";
          i2c_buff(buff_struct'pos(DATA0))(7 downto 0) <= data_in(31 downto 24);
          i2c_buff(buff_struct'pos(DATA1))(7 downto 0) <= data_in(23 downto 16);
          i2c_buff(buff_struct'pos(DATA2))(7 downto 0) <= data_in(15 downto 8);
          i2c_buff(buff_struct'pos(DATA3))(7 downto 0) <= data_in(7 downto 0);
          state <= w_start_st;
          i2c_start <= '1';
          wr_ack <= '1';
          busy_out <= '1';
        elsif (rd_en = '1') then
          i2c_buff(buff_struct'pos(DEVICE_ADDRESS)) <= "10100000";
          i2c_buff(buff_struct'pos(FIRST_WORD_ADDRESS))(addr'length - 9 downto 0) <= addr(addr'length - 3 downto 6);
          i2c_buff(buff_struct'pos(SECOND_WORD_ADDRESS))(7 downto 0) <= addr(5 downto 0) & "00";
          state <= r_start_st;
          counter <= 0;
          i2c_start <= '1';
          busy_out <= '1';
        end if;
      when w_start_st =>
        wr_ack <= '0';
        i2c_start <= '0';
        if ((i2c_ready_d = '0') and (i2c_ready = '1')) then
          state <= w_data;
        end if;
      when r_start_st =>
        i2c_start <= '0';
        if ((i2c_ready_d = '0') and (i2c_ready = '1')) then
          if (counter = 0) then
            state <= wr_r_addr_st;
          else
            state <= r_data;
            i2c_din <= "10100001" & '1';
            counter <= counter + 1;
          end if;
        end if;
      when wr_r_addr_st =>
        if (counter < buff_struct'pos(DATA0)) then
          i2c_wr_en <= '1';
          i2c_din <= i2c_buff(counter) & '1';
          state <= wr_r_addr_status;
        else
          i2c_start <= '1';
          state <= r_start0_st;
        end if;
      when wr_r_addr_status =>
        i2c_wr_en <= '0';
        if (i2c_valid = '1') then
          if (i2c_dout(0) = '1') then
            state <= err_ack_st;
          else
            state <= wr_r_addr_st;
            counter <= counter + 1;
          end if;
        end if;
      when r_start0_st =>
        i2c_start <= '0';
        if ((i2c_ready_d = '0') and (i2c_ready = '1')) then
          state <= r_data0;
          i2c_din <= "10100001" & '1';
        end if;
      when r_data0 =>
       --if (counter < buff_struct'pos(DATA0)) then
          i2c_wr_en <= '1';
          state <= r_data0_status;
        --else
        --  state <= r_start_st;
        --  i2c_start <= '1';
        --end if;
      when r_data0_status =>
        i2c_wr_en <= '0';
        i2c_din <= (others => '1'); 
        if (i2c_valid = '1') then
          i2c_buff(counter - 1) <= i2c_dout(8 downto 1);
          if (i2c_dout(0) = '1') then
            state <= r_start_st;
            i2c_start <= '1';
            counter <= counter - 2;
          else
            state <= r_data0;
            i2c_din <= (others => '1');
          end if;
        end if;
      when r_data =>
       if (counter < i2c_buff'length) then
          i2c_wr_en <= '1';
          state <= r_data_status;
        else
          rd_ack <= '1';
          data_out <= i2c_buff(buff_struct'pos(DATA0)) & i2c_buff(buff_struct'pos(DATA1)) & i2c_buff(buff_struct'pos(DATA2)) & i2c_buff(buff_struct'pos(DATA3));
          state <= stop_st;
          i2c_stop <= '1';
        end if;
      when r_data_status =>
        i2c_wr_en <= '0';
        i2c_din <= (others => '1'); 
        if (i2c_valid = '1') then
          i2c_buff(counter - 1) <= i2c_dout;
          if (i2c_dout(0) = '1') then
            state <= err_ack_st;
          else
            state <= r_data;
            counter <= counter + 1;
          end if;
        end if;
      when w_data =>
        if (counter < i2c_buff'length) then
          i2c_wr_en <= '1';
          i2c_din <= i2c_buff(counter) & '1';
          state <= w_data_status;
        else
          state <= stop_st;
          i2c_stop <= '1';
        end if;
      when w_data_status =>
        i2c_wr_en <= '0';
        if (i2c_valid = '1') then
          if (i2c_dout(0) = '1') then
            state <= err_ack_st;
          else
            state <= w_data;
            counter <= counter + 1;
          end if;
        end if;
      when stop_st =>
        rd_ack <= '0';
        i2c_reset <= '0';
        if (i2c_ready = '1') then
          i2c_stop <= '0';
        end if;
        if ((i2c_busy = '0') and (i2c_stop = '0')) then
          state <= idle;
          i2c_reset <= '1';
        end if;
      when err_ack_st =>
        state <= idle;
        error <= '1';
      when others =>
        state <= idle;
    end case;
  end if;
end process;

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
