library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_unsigned.ALL;
use IEEE.Std_Logic_Arith.all;

library work;
use work.ClockGenerator;
--use work.spi_master_module;
use work.spi_master;
use work.uart_module;
use work.async_fifo_30;
use work.ADC_FIFO;
use work.buff_io_iobuf_out_rus;
use work.IntToFloat;
use work.MultFloat;
use work.AddFloat;
use work.LTC2145_14_receiver;
--use work.FIFO8x16;
--use work.QuadratorSendResponse;



entity QuadratorTop is
  Port(
    clk50MHz        : in std_logic;
    reset_n         : in std_logic;
    adc_clk         : in std_logic;
    adc_enc         : out std_logic;
    adc_of          : in std_logic_vector(1 downto 0);
    adc_d1          : in std_logic_vector(13 downto 0);
    adc_d2          : in std_logic_vector(13 downto 0);
    sync_in_vec     : in std_logic_vector(2 downto 0);
    sync_out_vec    : out std_logic_vector(2 downto 0);
    uart_rxd        : in std_logic;
    uart_txd        : out std_logic;
    spi_miso        : in std_logic;
    spi_mosi        : out std_logic;
    spi_sck         : out std_logic;
    adc_cs          : out std_logic;
    dac_cs          : out std_logic;
    gtp             : out std_logic_vector(3 downto 0);
    rtp             : out std_logic_vector(3 downto 0);
    txd_1           : out std_logic;
    rxd_1           : in std_logic
    
  );
end QuadratorTop;

architecture Behavioral of QuadratorTop is
    constant c_sys_clk_Hz                   : integer := 125_000_000;
    constant c_uart_boad_rate               : integer := 230_400;
    constant spi_ss_slave                   : integer := 2;
    constant spi_d_width                    : integer := 16;
    constant id                             : std_logic_vector(7 downto 0) := x"55";
    signal clk_125MHz                       : std_logic;
    signal clk_to_adc                   : std_logic;
    signal clk_locked                       : std_logic;
    signal counter125                       : std_logic_vector(26 downto 0):= (others => '0');
    signal counter50                        : std_logic_vector(25 downto 0):= (others => '0');
    signal rst                              : std_logic;
    signal uart_tx_data                     : std_logic_vector(31 downto 0);
    signal uart_tx_valid                    : std_logic;
    signal GetFlag                          : std_logic;
    signal SetFlag                          : std_logic;
    signal uart_tx_ready                    : std_logic;
    signal uart_rx_data                     : std_logic_vector(31 downto 0);
    signal uart_rx_valid                    : std_logic;
    signal uart_rx_ready                    : std_logic;
    signal byte                             : std_logic_vector(7 downto 0);
    signal async_fifo_30_empty              : std_logic;
    signal async_fifo_30_q                  : std_logic_vector(29 downto 0);
    type adc_configuration is array (0 to 4) of std_logic_vector (7 downto 0);
    signal adc_config_buff                  : adc_configuration:= (4 => x"02", others => (others => '0'));
    signal cs                               : std_logic_vector(spi_ss_slave - 1 downto 0);
    signal sck                              : std_logic;
    signal spi_rd_data                      : std_logic_vector(spi_d_width - 1 downto 0);
    signal spi_enable                       : std_logic;
    signal curr_func                        : std_logic_vector(7 downto 0);
    signal curr_data_len                    : std_logic_vector(15 downto 0);
    signal uart_fifo_data                   : std_logic_vector(7 downto 0);
    signal uart_fifo_rd_req                 : std_logic;
    signal uart_fifo_wr_req                 : std_logic;
    signal uart_fifo_empty                  : std_logic;
    signal uart_fifo_full                   : std_logic;
    signal uart_fifo_q                      : std_logic_vector(15 downto 0);
    signal uart_fifo_rst                    : std_logic;
    signal rd_data_counter                  : integer;
    signal wr_data_counter                  : integer;
    signal spi_master_tx_data               : std_logic_vector(15 downto 0);
    signal spi_master_cpol                  : std_logic;
    signal spi_master_cpha                  : std_logic;
    signal spi_master_cont                  : std_logic;
    signal spi_master_clk_div               : integer;
    signal spi_master_addr                  : integer;
    signal spi_master_enable                : std_logic;
    signal spi_master_busy                  : std_logic;
    signal QuadratorSendResponse_enable     : std_logic;
    signal QuadratorSendResponse_cont       : std_logic;
    signal DACValueUInt16                   : std_logic_vector(15 downto 0):= x"f056";
    
    signal control0_d1                      : std_logic;
    signal start_write_waveform             : std_logic:= '0';
    signal adc_mem_address                  : std_logic_vector(8 downto 0);
    signal adc_fifo_rdreq                   : std_logic;
    signal adc_fifo_wrreq                   : std_logic;
    signal adc_fifo_empty                   : std_logic;
    signal adc_fifo_full                    : std_logic;
    signal adc_fifo_q                       : std_logic_vector(31 downto 0);
    signal adc_capture_flag                 : std_logic:= '0';

    type set_param_state_machine            is (IDLE, SET_PAR, READY, APPLY, CFG_DAC);
    signal set_par_state,set_par_next_state : set_param_state_machine;
    signal set_par_addr                     : integer;
    
    type get_param_state_machine            is (IDLE, HEAD, GET_PAR, READY);
    signal get_par_state,get_par_next_state : get_param_state_machine;
    signal get_par_addr                     : std_logic_vector(8 downto 0);
    signal get_data                         : std_logic_vector(31 downto 0);
    signal get_valid                        : std_logic;
    
    
    type get_wave_state_machine             is (IDLE, HEAD, GET_WAVEFORM, READY);
    signal get_wave_state,get_wave_next_state : get_wave_state_machine;
    signal get_wave_data                    : std_logic_vector(31 downto 0);
    signal get_wave_valid                   : std_logic;

    type state_machine                      is (IDLE, HEAD, CONF_ADC, SET_PARAMETERS, GET_PARAMETERS, GET_WAVEFORM);
    signal state, next_state                : state_machine;
    signal uart_function                    : std_logic_vector(7 downto 0);
    
    type dac_cfg_state_machine              is (IDLE, SET_SPI, SPI_BUSY_DOWN, CS_WAIT, READY);
    signal dac_cfg_state, dac_cfg_next_state        : dac_cfg_state_machine;
    
    type adc_cfg_state_maschine             is (IDLE, SET_CFG, RST_ADDR, APPLY_CFG, SPI_BUSY_DOWN, SPI_BUSY_UP, READY);
    signal adc_cfg_state, adc_cfg_next_state: adc_cfg_state_maschine;
    type adc_cfg_type                       is array (4 downto 0) of std_logic_vector(7 downto 0);
    signal adc_cfg_buff                     : adc_cfg_type;
    signal adc_par_addr                     : std_logic_vector(2 downto 0);
    signal adc_spi_data                     : std_logic_vector(15 downto 0);
    signal adc_spi_en                       : std_logic;
    
    signal I_value_f                        : std_logic_vector(31 downto 0);
    signal U_value_f                        : std_logic_vector(31 downto 0);
    signal UC1_f                            : std_logic_vector(31 downto 0);
    signal IL1_f                            : std_logic_vector(31 downto 0);
    signal UC1_2_f                          : std_logic_vector(31 downto 0);
    signal IL1_2_f                          : std_logic_vector(31 downto 0);
    signal EC1_f                            : std_logic_vector(31 downto 0);
    signal EL1_f                            : std_logic_vector(31 downto 0);
    signal Ecomm                            : std_logic_vector(31 downto 0);
    signal spi_dac_cfg_data                 : std_logic_vector(15 downto 0);
    signal spi_dac_en                       : std_logic;
    signal dac_counter                      : integer;
    signal cs_wait_counter                  : std_logic_vector(7 downto 0);
    
    signal ADC_DATA0                        : std_logic_vector(13 downto 0);
    signal ADC_DATA1                        : std_logic_vector(13 downto 0);
    signal ADC_O_F                          : std_logic_vector(1 downto 0);
    signal ADC_LCLK                         : std_logic;
    signal adc_clk_counter                  : std_logic_vector(26 downto 0);
    
    type uart_tx_state_machine              is (idle_state, head_state, buffer_state);
    signal uart_tx_state, uart_tx_next_state: uart_tx_state_machine;

    type ParametersStructure is (DAC1_0Value, DAC3_2Value, Status, DEBUG1, DEBUG2, DEBUG3, StructureLength);
    type ParametersType is array (ParametersStructure'pos(StructureLength) - 1 downto 0) of std_logic_vector(31 downto 0);
    signal AllParameters                    : ParametersType;--:= (
                                                               --       ParametersStructure'pos(DACValue) => (others => '0')--,
--                                                                      ParametersStructure'pos(Status)   => (others => '0')
                                                             --      );

    type SetParametersStructure is (DAC1_0Value, DAC3_2Value, Control, kUC_f, kIC_f, C1_f, L1_f, E_f, DEBUG_I, DEBUG_U, StructureLength);
    type SetParametersType is array (SetParametersStructure'pos(StructureLength) - 1 downto 0) of std_logic_vector(31 downto 0);
    signal SetParameters                    : SetParametersType:= (
                                                                      SetParametersStructure'pos(DAC1_0Value) => x"0000f056",
                                                                      SetParametersStructure'pos(DAC3_2Value) => x"0000f056",
                                                                      SetParametersStructure'pos(Control)  => x"00000000",
                                                                      SetParametersStructure'pos(kUC_f)  => x"00000000",
                                                                      SetParametersStructure'pos(kIC_f)  => x"00000000",
                                                                      SetParametersStructure'pos(C1_f)  => x"00000000",
                                                                      SetParametersStructure'pos(L1_f)  => x"00000000",
                                                                      SetParametersStructure'pos(E_f)  => x"00000000",
                                                                      SetParametersStructure'pos(DEBUG_I)  => x"00000000",
                                                                      SetParametersStructure'pos(DEBUG_U)  => x"00000000"
                                                                   );
    signal SetupBuff                        : SetParametersType;
    signal SetupRising                      : std_logic;
    
    type DACCfgType is array (4 - 1 downto 0) of std_logic_vector(15 downto 0);
    signal DAC_CFG                          : DACCfgType;

begin

rst <= (not reset_n) or (not clk_locked);

DAC_CFG(0) <= SetupBuff(SetParametersStructure'pos(DAC1_0Value))(15 downto 0);
DAC_CFG(1) <= SetupBuff(SetParametersStructure'pos(DAC1_0Value))(31 downto 16);
DAC_CFG(2) <= SetupBuff(SetParametersStructure'pos(DAC3_2Value))(15 downto 0);
DAC_CFG(3) <= SetupBuff(SetParametersStructure'pos(DAC3_2Value))(31 downto 16);

AllParameters(ParametersStructure'pos(DAC1_0Value)) <= SetupBuff(SetParametersStructure'pos(DAC1_0Value));
AllParameters(ParametersStructure'pos(DAC3_2Value)) <= SetupBuff(SetParametersStructure'pos(DAC3_2Value));
AllParameters(ParametersStructure'pos(Status))(0) <= adc_capture_flag;
AllParameters(ParametersStructure'pos(Status))(1) <= adc_fifo_empty;
AllParameters(ParametersStructure'pos(Status))(2) <= adc_fifo_full;
AllParameters(ParametersStructure'pos(DEBUG1)) <= EL1_f;
AllParameters(ParametersStructure'pos(DEBUG2)) <= EC1_f;
AllParameters(ParametersStructure'pos(DEBUG3)) <= Ecomm;


clock_gen_inst : ENTITY ClockGenerator
  port map
    (
      areset    => not reset_n,
      inclk0    => clk50MHz,
      c0        => clk_125MHz,
      c1        => clk_to_adc,
      locked    => clk_locked
    );

adc_enc <= clk_to_adc;

uart_module_inst : entity uart_module
  Generic map(
    c_freq_hz       => c_sys_clk_Hz,
    c_boad_rate     => c_uart_boad_rate
  )
  Port map(
    clk             => clk_125MHz,
    rst             => rst,
    tx_data         => uart_tx_data,
    tx_valid        => uart_tx_valid,
    tx_ready        => uart_tx_ready,
    txd             => txd_1,
    rx_data         => uart_rx_data,
    rx_valid        => uart_rx_valid,
    rx_ready        => uart_rx_ready,
    rxd             => rxd_1
  );
uart_rx_ready <= '1';

LTC2145_14_receiver_inst : ENTITY LTC2145_14_receiver
  GENERIC MAP(
    ddr_mode    => true
    )
  PORT MAP(
    rst         => rst,
    ltc_clk     => adc_clk,
    ltc_d0      => adc_d1,
    ltc_d1      => adc_d2,
    ltc_of      => adc_of,
    data0       => ADC_DATA0,
    overflow0   => ADC_O_F(0),
    data1       => ADC_DATA1,
    overflow1   => ADC_O_F(1),
    clk         => ADC_LCLK
  );

FIFO30_inst : ENTITY async_fifo_30
    PORT MAP
    (
        aclr        => rst,
        data        => ADC_O_F(1) & ADC_DATA1 & ADC_O_F(0) & ADC_DATA0,
        rdclk       => clk_125MHz,
        rdreq       => not async_fifo_30_empty,
        wrclk       => ADC_LCLK,
        wrreq       => '1',
        q           => async_fifo_30_q,
        rdempty     => async_fifo_30_empty
    );

IntToFloat1_inst : IntToFloat PORT MAP (
		clock	 => clk_125MHz,
		dataa	 => SetupBuff(SetParametersStructure'pos(DEBUG_I)),
		result	 => I_value_f
	);
    
IntToFloat2_inst : IntToFloat PORT MAP (
		clock	 => clk_125MHz,
		dataa	 => SetupBuff(SetParametersStructure'pos(DEBUG_U)),
		result	 => U_value_f
	);

MultFloat_I_inst : MultFloat PORT MAP (
		clock	 => clk_125MHz,
		dataa	 => I_value_f,
		datab	 => SetupBuff(SetParametersStructure'pos(kIC_f)),
		result	 => IL1_f
	);

MultFloat_U_inst : MultFloat PORT MAP (
		clock	 => clk_125MHz,
		dataa	 => U_value_f,
		datab	 => SetupBuff(SetParametersStructure'pos(kUC_f)),
		result	 => UC1_f
	);

MultFloat_IL1_2_f_inst : MultFloat PORT MAP (
		clock	 => clk_125MHz,
		dataa	 => IL1_f,
		datab	 => IL1_f,
		result	 => IL1_2_f
	);

MultFloat_UC1_2_f_inst : MultFloat PORT MAP (
		clock	 => clk_125MHz,
		dataa	 => UC1_f,
		datab	 => UC1_f,
		result	 => UC1_2_f
	);

MultFloat_EL1_f_inst : MultFloat PORT MAP (
		clock	 => clk_125MHz,
		dataa	 => IL1_2_f,
		datab	 => SetupBuff(SetParametersStructure'pos(L1_f)),
		result	 => EL1_f
	);

MultFloat_EC1_f_inst : MultFloat PORT MAP (
		clock	 => clk_125MHz,
		dataa	 => UC1_2_f,
		datab	 => SetupBuff(SetParametersStructure'pos(C1_f)),
		result	 => EC1_f
	);


AddFloat_inst : AddFloat PORT MAP (
		clock	 => clk_125MHz,
		dataa	 => EL1_f,
		datab	 => EC1_f,
		result	 => Ecomm
	);

SetupBuff_proc :
process(clk_125MHz, rst)
begin
  if (rst = '1') then
    SetupRising <= '0';
  elsif rising_edge(clk_125MHz) then
    if (set_par_state = APPLY) then
      SetupBuff  <= SetParameters;
      SetupRising <= '1';
    else
      SetupBuff(SetParametersStructure'pos(Control))(0) <= '0'; -- start adc capture
      SetupBuff(SetParametersStructure'pos(Control))(1) <= '0'; -- start dac cfg
      SetupRising <= '0';
    end if;
  end if;
end process;


spi_master_inst : ENTITY spi_master
  Generic map(
    slaves  => spi_ss_slave,
    d_width => spi_d_width 
    )
  Port map(
    clock           => clk_125MHz,
    reset_n         => not rst,
    enable          => spi_master_enable,
    cpol            => spi_master_cpol,
    cpha            => spi_master_cpha,
    cont            => '0',
    clk_div         => spi_master_clk_div,
    addr            => spi_master_addr,
    tx_data         => spi_master_tx_data,
    miso            => spi_miso,
    sck             => sck,
    cs              => cs,
    mosi            => spi_mosi,
    busy            => spi_master_busy,
    rx_data         => spi_rd_data
    );

adc_cs <= cs(0);
dac_cs <= cs(1);

sck_out_buf_ins :  ENTITY  buff_io_iobuf_out_rus
    PORT MAP
    ( 
        datain(0)   => sck,
        dataout(0)  => spi_sck
    ); 

process(clk_125MHz)
begin
  if rising_edge(clk_125MHz) then
    counter125 <= counter125 + 1;
  end if;
end process;

process(clk50MHz)
begin
  if rising_edge(clk50MHz) then
    counter50 <= counter50 + 1;
  end if;
end process;

process(adc_clk, rst)
begin
  if (rst = '1') then
    adc_clk_counter <= (others => '0');
  elsif rising_edge(adc_clk) then
    adc_clk_counter <= adc_clk_counter + 1;
  end if;
end process;


gtp(0) <= adc_clk_counter(adc_clk_counter'length - 1);
gtp(1) <= counter125(counter125'length - 1);
--spi_sck <= counter125(counter125'length - 1);

rtp(0) <= '1';
rtp(1) <= counter50(counter50'length - 1);

----------------------------------------
-- main state process 
-- type state_machine                      is (HEAD, CONF_ADC, SET_PARAMETERS, GET_PARAMETERS, GET_WAVEFORM)
-- signal state, next_state                : state_machine;
-- signal uart_rx_data_length              : std_logic_vector(15 downto 0);
-- signal uart_function                    : std_logic_vector(7 downto 0);
----------------------------------------
sync_proc :
process(rst, clk_125MHz)
begin
  if (rst = '1') then
    state <= IDLE;
  elsif rising_edge(clk_125MHz) then
    state <= next_state;
  end if;
end process;

next_state_proc :
process(state, uart_rx_valid, uart_rx_data, adc_cfg_state, set_par_state, uart_tx_ready, get_data, get_wave_state, get_par_state)
begin
  next_state <= state;
    case (state) is
      when IDLE =>
        next_state <= HEAD;
      when HEAD =>
        if (uart_rx_valid = '1') and (uart_rx_data(7 downto 0) = id) then
          case uart_rx_data(15 downto 8) is
            when x"00" => 
              next_state <= CONF_ADC;
            when x"01" =>
              next_state <= SET_PARAMETERS;
            when x"02" =>
              next_state <= GET_PARAMETERS;
            when x"03" =>
              next_state <= GET_WAVEFORM;
            when others =>
              next_state <= IDLE;
          end case;
        end if;
      when CONF_ADC =>
        if (adc_cfg_state = READY) and (uart_tx_ready = '1') then
          next_state <= IDLE;
        end if;
      when SET_PARAMETERS =>
        if (set_par_state = READY) and (uart_tx_ready = '1') then
          next_state <= IDLE;
        end if;
      when GET_PARAMETERS =>
        if (get_par_state = READY) and (uart_tx_ready = '1') then
          next_state <= IDLE;
        end if;
      when GET_WAVEFORM =>
        if (get_wave_state = READY) and (uart_tx_ready = '1') then
          next_state <= IDLE;
        end if;
      when others =>
        next_state <= IDLE;
    end case;
end process;

state_out_proc :
process(state, adc_cfg_state, set_par_state, get_par_state, get_wave_data, get_wave_valid, get_data, get_valid, uart_function, adc_spi_en, adc_spi_data)
begin
  spi_master_enable     <= '0';
  spi_master_clk_div    <= 3;
  spi_master_cpol       <= '1';
  spi_master_cpha       <= '1';
  spi_master_addr       <= 0;
  uart_tx_valid         <= '0';
    case (state) is
      when CONF_ADC =>
        if (adc_cfg_state = READY) then
          uart_tx_data  <= x"0000" & uart_function & id;
          uart_tx_valid <= '1';
        end if;
        spi_master_enable <= adc_spi_en;
        spi_master_tx_data <= adc_spi_data;
      when SET_PARAMETERS =>
        case (set_par_state) is
          when READY => 
            uart_tx_data  <= x"0000" & uart_function & id;
            uart_tx_valid <= '1';
          when CFG_DAC =>
            spi_master_enable <= spi_dac_en;
            spi_master_tx_data <= spi_dac_cfg_data;
            spi_master_addr <= 1;
            spi_master_cpha <= '0';
            spi_master_cpol <= '1';
            spi_master_clk_div    <= 5;
          when others => 
        end case;
      when GET_PARAMETERS =>
          uart_tx_data  <= get_data;
          uart_tx_valid <= get_valid;
      when GET_WAVEFORM => 
          uart_tx_data  <= get_wave_data;
          uart_tx_valid <= get_wave_valid;
      when others =>
    end case;
end process;

process(clk_125MHz)
begin
  if rising_edge(clk_125MHz) then
    if (state = HEAD) then
      if (uart_rx_valid = '1') then
        uart_function <= uart_rx_data(15 downto 8);
      end if;
    end if;
  end if;
end process;

----------------------------------------
--  type adc_cfg_state_maschine             is (IDLE, SET_CFG, RST_ADDR, APPLY_CFG, SPI_BUSY_DOWN, SPI_BUSY_UP, READY)
--  signal adc_cfg_state, adc_cfg_next_state: adc_cfg_state_maschine;
--  type adc_cfg_type                       is array (4 downto 0) of std_logic_vector(7 downto 0);
--  signal adc_cfg_buff                     : adc_cfg_type;
----------------------------------------
adc_cfg_sync_proc :
process(state, clk_125MHz)
begin
  if (state = IDLE) then
    adc_cfg_state <= IDLE;
  elsif rising_edge(clk_125MHz) then
    adc_cfg_state <= adc_cfg_next_state;
  end if;
end process;

adc_cfg_next_state_proc :
process(adc_cfg_state, state, adc_par_addr, spi_master_busy)
begin
  adc_cfg_next_state <= adc_cfg_state;
    case (adc_cfg_state) is
      when IDLE =>
        if (state = CONF_ADC) then
          adc_cfg_next_state <= SET_CFG;
        end if;
      when SET_CFG =>
          if (adc_par_addr > 4) then
            adc_cfg_next_state <= RST_ADDR;
          end if;
      when RST_ADDR =>
        adc_cfg_next_state <= SPI_BUSY_DOWN;
      when SPI_BUSY_DOWN =>
        if (spi_master_busy = '0') then
          adc_cfg_next_state <= APPLY_CFG;
        end if;
      when APPLY_CFG =>
        adc_cfg_next_state <= SPI_BUSY_UP;
      when SPI_BUSY_UP =>
        if (adc_par_addr > 5) then
          adc_cfg_next_state <= READY;
        elsif spi_master_busy = '1' then
          adc_cfg_next_state <= SPI_BUSY_DOWN;
        end if;
      when READY =>
      when others =>
        adc_cfg_next_state <= IDLE;
    end case;
end process;

adc_par_addr_proc :
process(clk_125MHz, adc_cfg_state)
begin
  if (adc_cfg_state = IDLE) or (adc_cfg_state = RST_ADDR) then
    adc_par_addr <= (others => '0');
    adc_spi_en <= '0';
  elsif rising_edge(clk_125MHz) then
    if (uart_rx_valid = '1') then
      adc_cfg_buff(conv_integer(unsigned(adc_par_addr))) <= uart_rx_data(7 downto 0);
      adc_par_addr <= adc_par_addr + 1;
    elsif (adc_cfg_state = APPLY_CFG) then
      adc_spi_en        <= '1';
      adc_spi_data      <= "00000" & adc_par_addr & adc_cfg_buff(conv_integer(unsigned(adc_par_addr)));
      adc_par_addr      <= adc_par_addr + 1;
    end if;
  end if;
end process;

----------------------------------------
--  type set_param_state_machine            is (IDLE, SET_PAR, READY)
--  signal set_par_state,set_par_next_state : set_param_state_machine;
----------------------------------------
set_par_sync_proc :
process(state, clk_125MHz)
begin
  if (state = IDLE) then
    set_par_state <= IDLE;
  elsif rising_edge(clk_125MHz) then
    set_par_state <= set_par_next_state;
  end if;
end process;

set_par_next_state_proc :
process(set_par_state, state, set_par_addr, dac_cfg_state, SetParameters(SetParametersStructure'pos(Control)))
begin
  set_par_next_state <= set_par_state;
    case (set_par_state) is
      when IDLE =>
        if (state = SET_PARAMETERS) then
          set_par_next_state <= SET_PAR;
        end if;
      when SET_PAR =>
        if (set_par_addr >= SetParametersStructure'pos(StructureLength)) then
            set_par_next_state <= APPLY;
        end if;
      when APPLY =>
        if (SetParameters(SetParametersStructure'pos(Control))(1) = '1') then
          set_par_next_state <= CFG_DAC;
        else
          set_par_next_state <= READY;
        end if;
      when CFG_DAC =>
        if (dac_cfg_state = READY) then
          set_par_next_state <= READY;
        end if;
      when READY => 
      when others =>
        set_par_next_state <= IDLE;
    end case;
end process;

set_par_addr_proc :
process(clk_125MHz, set_par_state)
begin
  if (set_par_state /= SET_PAR) then
    set_par_addr <= 0;
  elsif rising_edge(clk_125MHz) then
    if (uart_rx_valid = '1') then
      SetParameters(set_par_addr) <= uart_rx_data;
      set_par_addr <= set_par_addr + 1;
    end if;
  end if;
end process;
----------------------------------------
--  type dac_cfg_state_machine              is (IDLE, SET_SPI, SPI_BUSY_DOWN, READY)
--  signal dac_cfg_state, dac_cfg_next_state        : dac_cfg_state_machine
--  signal spi_dac_cfg_data                 : std_logic_vector(15 downto 0);
--  signal spi_dac_en                       : std_logic_vector(15 downto 0);

----------------------------------------
dac_cfg_sync_proc :
process(set_par_state, clk_125MHz)
begin
  if (set_par_state = IDLE) then
    dac_cfg_state <= IDLE;
  elsif rising_edge(clk_125MHz) then
    dac_cfg_state <= dac_cfg_next_state;
  end if;
end process;

dac_cfg_next_state_proc :
process(dac_cfg_state, set_par_state, dac_counter, spi_master_enable, spi_master_busy, cs_wait_counter)
begin
  dac_cfg_next_state <= dac_cfg_state;
  spi_dac_en <= '0';
    case (dac_cfg_state) is
      when IDLE =>
        if (set_par_state = CFG_DAC) then
            dac_cfg_next_state <= SET_SPI;
        end if;
      when SET_SPI =>
        if (spi_master_enable = '1') then
          dac_cfg_next_state <= SPI_BUSY_DOWN;
        end if;
          spi_dac_cfg_data <= DAC_CFG(dac_counter);
          spi_dac_en <= not spi_master_busy;
      when SPI_BUSY_DOWN =>
        if (spi_master_busy = '0') then 
          dac_cfg_next_state <= CS_WAIT;
        end if;
      when CS_WAIT =>
        if (cs_wait_counter >= x"0f") then
          if dac_counter = DAC_CFG'length then
            dac_cfg_next_state <= READY;
          else
            dac_cfg_next_state <= SET_SPI;
          end if;
        end if;
      when READY =>
        
      when others =>
        dac_cfg_next_state <= IDLE;
    end case;
end process;

cs_wait_counter_proc :
  process(clk_125MHz, dac_cfg_state)
  begin
    if (dac_cfg_state /= CS_WAIT) then
      cs_wait_counter <= (others => '0');
    elsif rising_edge(clk_125MHz) then
      cs_wait_counter <= cs_wait_counter + 1;
    end if;
  end process;

dac_counter_proc :
  process(clk_125MHz, dac_cfg_state)
  begin
    if (dac_cfg_state = IDLE) then
      dac_counter <= 0;
    elsif rising_edge(clk_125MHz) then
      if (spi_master_enable = '1') then
        dac_counter <= dac_counter + 1;
      end if;
    end if;
  end process;

----------------------------------------
--  type get_param_state_machine            is (IDLE, GET_PAR, READY)
--  signal get_par_state,get_par_next_state : get_param_state_machine;
----------------------------------------
get_par_sync_proc :
process(state, clk_125MHz)
begin
  if (state = IDLE) then
    get_par_state <= IDLE;
  elsif rising_edge(clk_125MHz) then
    get_par_state <= get_par_next_state;
  end if;
end process;

get_par_next_state_proc :
process(get_par_state, state, uart_tx_ready, AllParameters, uart_function, get_par_addr)
begin
  get_par_next_state <= get_par_state;
  get_valid <= '0';
    case (get_par_state) is
      when IDLE =>
        if (state = GET_PARAMETERS) then
          get_par_next_state <= HEAD;
        end if;
      when HEAD => 
        if (uart_tx_ready = '1') then
          get_par_next_state <= GET_PAR;
        end if;
        get_valid <= '1';
        get_data <= conv_std_logic_vector(ParametersStructure'pos(StructureLength), 14) & "00" & uart_function & id;
      when GET_PAR =>
        if (get_par_addr >= conv_std_logic_vector(ParametersStructure'pos(StructureLength) - 1, get_par_addr'length)) then
          get_par_next_state <= READY;
        end if;
        get_valid <= '1';
        get_data <= AllParameters(conv_integer(unsigned(get_par_addr)));
      when READY => 
      when others =>
        get_par_next_state <= IDLE;
    end case;
end process;

get_par_addr_proc :
process(clk_125MHz, get_par_state)
begin
  if (get_par_state /= GET_PAR) then
    get_par_addr <= (others => '0');
  elsif rising_edge(clk_125MHz) then
    if (uart_tx_ready = '1') then
      get_par_addr <= get_par_addr + 1;
    end if;
  end if;
end process;


get_wave_sync_proc :
process(state, clk_125MHz)
begin
  if (state = IDLE) then
    get_wave_state <= IDLE;
  elsif rising_edge(clk_125MHz) then
    get_wave_state <= get_wave_next_state;
  end if;
end process;

get_wave_next_state_proc :
process(get_wave_state, state, uart_tx_ready, AllParameters, uart_function, adc_fifo_empty)
begin
  get_wave_next_state <= get_wave_state;
  adc_fifo_rdreq <= '0';
  get_wave_valid <= '0';
    case (get_wave_state) is
      when IDLE =>
        if (state = GET_WAVEFORM) then
          get_wave_next_state <= HEAD;
        end if;
      when HEAD => 
        if (uart_tx_ready = '1') then
          get_wave_next_state <= GET_WAVEFORM;
        end if;
        get_wave_valid <= '1';
        get_wave_data  <= x"8000" & uart_function & id;
      when GET_WAVEFORM =>
        if (adc_fifo_empty = '1') then
          get_wave_next_state <= READY;
        end if;
        get_wave_valid <= not adc_fifo_empty;
        get_wave_data <= adc_fifo_q;
        adc_fifo_rdreq <= uart_tx_ready;
      when READY => 
      when others =>
        get_wave_next_state <= IDLE;
    end case;
end process;

start_write_waveform_proc :
  process(clk_125MHz)
  begin
    if rising_edge(clk_125MHz) then
      control0_d1 <=  SetupBuff(SetParametersStructure'pos(Control))(0);
      start_write_waveform <= control0_d1 and (not SetupBuff(SetParametersStructure'pos(Control))(0));
    end if;
  end process;

adc_mem_address_proc :
  process(clk_125MHz, rst, start_write_waveform)
  begin
    if (rst = '1') then
      adc_capture_flag <= '0';
    elsif rising_edge(clk_125MHz) then
      if (adc_capture_flag = '0') then
        if (start_write_waveform = '1') then
          adc_capture_flag <= '1';
        end if;
      else
        if (adc_fifo_full = '1') then
          adc_capture_flag <= '0';
        end if;
      end if;
    end if;
  end process;

--ADC_MEM_INST : ENTITY ADC_MEM
--    PORT MAP
--    (
--      address       : IN STD_LOGIC_VECTOR (8 DOWNTO 0);
--      clock         => clk_125MHz,
--      data          => '0' & async_fifo_30_q(29 downto 15) & '0' & async_fifo_30_q(14 downto 0),
--      wren          : IN STD_LOGIC ;
--      q             : OUT STD_LOGIC_VECTOR (31 DOWNTO 0)
--    );

adc_fifo_wrreq <= adc_capture_flag and (not adc_fifo_full);

ADC_FIFO_INST : ENTITY ADC_FIFO
    PORT MAP
    (
      clock       => clk_125MHz,
      data        => '0' & async_fifo_30_q(29 downto 15) & '0' & async_fifo_30_q(14 downto 0),
      rdreq       => adc_fifo_rdreq,
      wrreq       => adc_fifo_wrreq,
      empty       => adc_fifo_empty,
      full        => adc_fifo_full,
      q           => adc_fifo_q
    );



end Behavioral;