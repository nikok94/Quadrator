library IEEE;
use IEEE.STD_LOGIC_1164.ALL;



entity QuadratorSendResponse is
  Port(
    clk         : in std_logic;
    rst         : in std_logic;
    id          : in std_logic_vector(7 downto 0);
    func        : in std_logic_vector(7 downto 0);
    data_len    : in std_logic_vector(15 downto 0);
    enable      : in std_logic;
    byte        : out std_logic_vector(7 downto 0);
    valid       : out std_logic;
    ready       : in std_logic;
    cont        : out std_logic
  );
end QuadratorSendResponse;

architecture Behavioral of QuadratorSendResponse is
    type send_state_mashine is (idle, send_id, send_func, send_data_len0, send_data_len1, continue);
    signal state, next_state    : send_state_mashine;

begin
sync_proc :
process(rst, clk)
begin
  if rst = '1' then
    state <= idle;
  elsif rising_edge(clk) then
    state <= next_state;
  end if;
end process;
  
next_state_proc :
process(state, enable)
begin
  next_state <= state;
  case (state) is
    when idle =>
      if (enable = '1') then
        next_state <= send_id;
      end if;
    when send_id =>
      if (ready = '1') then
        next_state <= send_func;
      end if;
    when send_func =>
      if (ready = '1') then
        next_state <= send_data_len0;
      end if;
    when send_data_len0 =>
      if (ready = '1') then
        next_state <= send_data_len1;
      end if;
    when send_data_len1 =>
      if (ready = '1') then
        next_state <= continue;
      end if;
    when continue =>
      next_state <= idle;
    when others =>
      next_state <= idle;
  end case;
end process;

out_proc :
process(state, id, data_len, func)
begin
  byte <= (others => '0');
  valid <= '1';
  cont <= '0';
    case (state) is
      when idle =>
        valid <= '0';
      when send_id =>
        byte <= id;
      when send_func =>
        byte <= func;
      when send_data_len0 =>
        byte <= data_len(7 downto 0);
      when send_data_len1 =>
        byte <= data_len(15 downto 8);
      when continue =>
        cont <= '1';
      when others =>
        valid <= '0';
    end case;
end process;


end Behavioral;