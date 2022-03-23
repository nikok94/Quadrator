
LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.std_logic_signed.all;
use IEEE.MATH_REAL.all;
use IEEE.Std_Logic_Arith.all;


ENTITY DataCaptureModule IS
  GENERIC (
    c_max_n_word    : integer := 512;
    c_data_length   : integer := 32
  );
  PORT
  (
    clk             : in std_logic;
    rst             : in std_logic;

    InDSamplParam   : in std_logic_vector(31 downto 0);

    InData          : in std_logic_vector(31 downto 0);
    InReady         : out std_logic;

    InStart         : in std_logic;
    InNumWord       : in integer;

    OutBusy         : out std_logic;
    OutDataLength   : out std_logic_vector(31 downto 0);
    OutData         : out std_logic_vector(31 downto 0);
    OutValid        : out std_logic;
    OutReady        : in std_logic
  );
END DataCaptureModule;


ARCHITECTURE SYN OF DataCaptureModule IS

  type SMType     is (IdleST, StartST, CaptureST, PushST);
  signal state                : SMType;
  signal w_addr               : integer range 0 to c_max_n_word;
  signal r_addr               : integer range 0 to c_max_n_word;
  signal SampleCounter        : std_logic_vector(31 downto 0);
  type mem is array (0 to c_max_n_word - 1) of std_logic_vector(c_data_length - 1 downto 0);
  signal memory               : mem;
  signal valid                : std_logic;
  signal ready                : std_logic;
  signal start_vec            : std_logic_vector(2 downto 0);
  signal start                : std_logic;


BEGIN

process(clk,rst)
begin
  if(rst = '1') then
    start_vec <= (others => '0');
  elsif rising_edge(clk) then
    start_vec(start_vec'length - 1 downto 1) <= start_vec(start_vec'length-2 downto 0);
    start_vec(0) <= InStart;
    start <= (not start_vec(start_vec'length - 1)) and start_vec(start_vec'length - 2);
  end if;
end process;

process(clk, rst)
begin
  if(rst = '1') then
    state <= IdleST;
    OutBusy <= '1';
    ready <= '0';
  elsif rising_edge(clk) then
    case state is
      when IdleST =>
        state <= StartST;
        ready <= '1';
      when StartST =>
        OutBusy <= '0';
        if (start = '1') then
          state <= CaptureST;
          OutBusy <= '1';
          w_addr <= 0;
          SampleCounter <= InDSamplParam;
        end if;
      when CaptureST =>
        if (start = '1') then
          w_addr <= 0;
          SampleCounter <= InDSamplParam;
        else
          if (SampleCounter >= InDSamplParam) then
            SampleCounter <= (others => '0');
            if ((w_addr >= InNumWord) or (w_addr>=c_max_n_word)) then
                state <= PushST;
                ready <= '0';
                r_addr <= 0;
                OutDataLength <= conv_std_logic_vector(w_addr, OutDataLength'length);
            else
                memory(w_addr) <= InData;
                w_addr <= w_addr+1;
            end if;
          else
            SampleCounter <= SampleCounter+1;
          end if;
        end if;
      when PushST =>
        if ((start = '1') and (r_addr = 0)) then
          state <= CaptureST;
          OutBusy <= '1';
          w_addr <= 0;
          SampleCounter <= InDSamplParam;
          valid <= '0';
        else
          OutData <= memory(r_addr);
          if (r_addr >= w_addr) then
            state <= IdleST;
            valid <= '0';
          else
            valid <= '1';
            if ((valid='1') and (OutReady='1')) then
              r_addr <= r_addr+1;
              valid <= '0';
            end if;
          end if;
        end if;
      when others =>
        state <= IdleST;
    end case;
  end if;
end process;

InReady <= ready;
OutValid <= valid;

END SYN;