LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.std_logic_unsigned.all;
use IEEE.MATH_REAL.ALL;

library work;
use work.PRSGenerator;

ENTITY MemoryCheckController IS
    GENERIC (
      c_init        : std_logic_vector(31 downto 0) := x"00000001";
      c_mem_range   : integer := 4096
    );
    PORT (
      clk       : in std_logic;
      rst       : in std_logic;

      s_addr    : in std_logic_vector(natural(log2(real(c_mem_range/8 - 1))) - 1 downto 0);
      s_din     : in std_logic_vector(31 downto 0);
      s_wr_en   : in std_logic;
      s_wr_ack  : out std_logic;
      s_dout    : out std_logic_vector(31 downto 0);
      s_rd_en   : in std_logic;
      s_rd_ack  : out std_logic;
      s_error   : out std_logic;
      s_busy    : out std_logic;
      
      m_addr    : out std_logic_vector(natural(log2(real(c_mem_range/4 - 1))) - 1 downto 0);
      m_din     : out std_logic_vector(31 downto 0);
      m_wr_en   : out std_logic;
      m_wr_ack  : in std_logic;
      m_dout    : in std_logic_vector(31 downto 0);
      m_rd_en   : out std_logic;
      m_rd_ack  : in std_logic;
      m_error   : in std_logic;
      m_busy    : in std_logic

    );
END MemoryCheckController;


ARCHITECTURE SYN OF MemoryCheckController IS
    type stm                is (idle, cmd, wr_start, wr_st, rd_start, wr_control_seq, wr_data);
    signal state            : stm;
--    signal prsgen_rst       : std_logic;
--    signal prsgen_en        : std_logic;
--    signal prsgen_result    : std_logic_vector(31 downto 0);
--    signal prsgen_num_state : integer;
    signal xor_data         : std_logic_vector(31 downto 0);
    signal wr_cntr_seq      : std_logic_vector(31 downto 0);
    signal wr_en            : std_logic;
BEGIN

m_wr_en <= wr_en;

main_proc :
  process(clk, rst)
  begin
    if (rst = '1') then
      state <= idle;
      prsgen_rst <= '1';
      s_busy <= '1';
      s_wr_ack <= '0';
      s_rd_ack <= '0';
      s_error <= '0';
      wr_en <= '0';
      m_rd_en <= '0';
    elsif rising_edge(clk) then
      case (state) is
        when idle =>
          state <= cmd;
          prsgen_rst <= '0';
          s_busy <= '0';
        when cmd =>
          if (s_wr_en = '1') then 
            state <= wr_start;
            s_busy <= '1';
          elsif (s_rd_en = '1') then
            state <= rd_start;
            s_busy <= '1';
          end if;
        when wr_start =>
          if (m_busy = '0') then
            wr_en <= '1';
            m_din <= c_init xor s_din;
            m_addr <= s_addr & '0';
          end if;
          if ((wr_en = '1') and (m_wr_ack = '1')) then
            wr_en <= '1';
            state <= wr_st;
          end if;
      end case;
    end if;
  end process;

--prsgen_inst : ENTITY PRSGenerator
--    PORT MAP
--    (
--      clk       => clk,
--      rst       => prsgen_rst,
--      en        => prsgen_en,
--      init      => c_init,
--      result    => prsgen_result,
--      num_state => prsgen_num_state
--    );

END SYN;
