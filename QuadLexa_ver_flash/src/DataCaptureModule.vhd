
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
    InValid         : in std_logic;
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
--  constant c_addr_width       : integer := natural(log2(real(c_max_n_word)));
--  type SMType     is (IdleST, StartST, CaptureST, PushST, ResetAddr, EndST, AddrEdge);
--  signal state, next_state    : SMType;
  type SMType     is (IdleST, StartST, CaptureST, PushST);
  signal state                : SMType;
  signal w_addr               : integer range 0 to c_max_n_word;
  signal r_addr               : integer range 0 to c_max_n_word;
--  signal address              : integer range 0 to c_max_n_word;
--  signal wren                 : std_logic;
  signal SampleCounter        : std_logic_vector(31 downto 0);
--  signal InDataReg            : std_logic_vector(c_data_length - 1 downto 0);
--  signal OutDataReg           : std_logic_vector(c_data_length - 1 downto 0);
  type mem is array (0 to c_max_n_word - 1) of std_logic_vector(c_data_length - 1 downto 0);
  signal memory               : mem;
  signal valid                : std_logic;
  signal ready                : std_logic;
--  signal buff_full            : std_logic;
  signal start_vec				: std_logic_vector(2 downto 0);
  signal start 					: std_logic;


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
        --if (InStart = '1') then
        if (start = '1') then
          state <= CaptureST;
          OutBusy <= '1';
          w_addr <= 1;
			 memory(0) <= InData;
          SampleCounter <= (others => '0');
        end if;
      when CaptureST =>
		  if (valid = '1') then
		    valid <= '0';
		  end if;
		  
		  if (start = '1') then
				w_addr <= 1;
			   memory(0) <= InData;
				SampleCounter <= (others => '0');
        elsif (InValid = '1') then
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
        OutData <= memory(r_addr);
        if ((start = '1') and (r_addr = 0)) then
          state <= CaptureST;
          OutBusy <= '1';
          w_addr <= 1;
			 memory(0) <= InData;
          SampleCounter <= (others => '0');
			 valid <= '0';
        else
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

--SMSyncProc  :
--  process(clk, rst)
--  begin
--    if (rst = '1') then
--      state <= IdleST;
--    elsif rising_edge(clk) then
--      state <= next_state;
--    end if;
--  end process;
--
--SMNextStateProc :
--  process(state, InStart, buff_full, w_addr, r_addr, OutReady)
--  begin
--    next_state <= state;
--    case(state) is
--      when IdleST =>
--        next_state <= StartST;
--      when StartST => 
--        if (InStart = '1') then
--          next_state <= CaptureST;
--        end if;
--      when CaptureST=>
--        if (buff_full = '1')then
--          next_state <= PushST;
--        end if;
--      when ResetAddr =>
--        next_state <= CaptureST;
--      when PushST =>
--        if (InStart = '1') then
--          next_state <= ResetAddr;
--        elsif (r_addr >= w_addr) then
--          next_state <= EndST;
--        elsif (OutReady = '1') then
--          next_state <= AddrEdge;
--        end if;
--      when AddrEdge =>
--        next_state <= PushST;
--      when EndST =>
--        next_state <= IdleST;
--      when others =>
--        next_state <= IdleST;
--    end case;
--  end process;
--
--buff_full <= '1' when (w_addr >= InNumWord ) or (w_addr >= c_max_n_word) else '0';
--
--SMOutProc :
--  process(state)
--  begin
--    address <= r_addr;
--    InReady <= '0';
--    valid <= '0';
--    OutDataLength <= (others => '0');
--    OutBusy <= '1';
--    case(state) is
--      when IdleST =>
--      when StartST => 
--        OutBusy <= '0';
--      when CaptureST=>
--        address <= w_addr;
--        InReady <= '1';
--      when PushST =>
--        valid <= '1';
--        OutDataLength <= conv_std_logic_vector(w_addr, OutDataLength'length);
--      when others =>
--    end case;
--  end process;
--
--process(clk)
--begin
--  if rising_edge(clk) then
--    OutData <= memory(r_addr);
--  end if;
--end process;
--
--  OutValid <= valid;
--
--r_addr_proc :
--  process(clk, state)
--  begin
--    if (state = IdleST) or (state = ResetAddr) then
--      r_addr <= 0;
--    elsif rising_edge(clk) then
--      if (OutReady = '1') and (valid = '1') then
--        r_addr <= r_addr + 1;
--      end if;
--    end if;
--  end process;
--
--wren_proc :
--  process(clk, state)
--  begin
--    if (state /= CaptureST) then
--      wren <= '0';
--      SampleCounter <= (others => '0');
--    elsif rising_edge(clk) then
--      if (InValid = '1') then
--        if (SampleCounter < InDSamplParam) then
--          SampleCounter <= SampleCounter + 1;
--          wren <= '0';
--        else
--          SampleCounter <= (others => '0');
--          wren <= '1';
--        end if;
--      else
--        wren <= '0';
--      end if;
--      InDataReg <= InData;
--    end if;
--  end process;
--
--w_addr_proc :
--  process(clk, state)
--  begin
--    if (state = IdleST) or (state = ResetAddr) then
--      w_addr <= 0;
--    elsif rising_edge(clk) then
--      if (wren = '1') and (buff_full = '0') then
--        w_addr <= w_addr + 1;
--        memory(w_addr) <= InData;
--      end if;
--    end if;
--  end process;

END SYN;