library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_unsigned.ALL;
use IEEE.Std_Logic_Arith.all;
use IEEE.MATH_REAL.all;

library work;
use work.ClockGenerator;
--use work.spi_master_module;
use work.spi_master;
use work.uart_module;
use work.async_fifo_30;
use work.DataCaptureModule;
use work.buff_io_iobuf_out_rus;
use work.LTC2145_14_receiver;
use work.SquaringModule;
use work.AT24C_master;
use work.CRC32;
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
    optic_rx_vec    : in std_logic_vector(3 downto 0);
    optic_tx_vec    : out std_logic_vector(3 downto 0);
    spi_miso        : in std_logic;
    spi_mosi        : out std_logic;
    spi_sck         : out std_logic;
    adc_cs          : out std_logic;
    dac_cs          : out std_logic;
    --gtp             : out std_logic_vector(3 downto 0);
    --rtp             : out std_logic_vector(3 downto 0);
    leds            : out std_logic_vector(3 downto 0);
    i2c_sda         : inout std_logic;
    i2c_scl         : inout std_logic;
    wp              : out std_logic;
    p39             : out std_logic;
    p42             : out std_logic;
    txd_1           : out std_logic;
    rxd_1           : in std_logic
    
  );
end QuadratorTop;

architecture Behavioral of QuadratorTop is
    constant c_sys_clk_Hz                   : integer := 125_000_000;
    constant c_uart_boad_rate               : integer := 3375000;--1490000;--921600;--1728000;
    constant g_CLKS_PER_BIT                 : integer := natural(ceil(real(c_sys_clk_Hz)/real(c_uart_boad_rate)));
    constant spi_ss_slave                   : integer := 2;
    constant spi_d_width                    : integer := 16;
    constant id                             : std_logic_vector(7 downto 0) := x"55";
    constant waveform_buff_size             : integer := 12040;
    
    constant func_conf_adc                  : std_logic_vector(7 downto 0) := x"10";
    constant func_param_set                 : std_logic_vector(7 downto 0) := x"11";
    constant func_param_get                 : std_logic_vector(7 downto 0) := x"12";
    constant func_get_waveform              : std_logic_vector(7 downto 0) := x"13";
    constant func_SMQ_reset                 : std_logic_vector(7 downto 0) := x"14";
    constant func_flash_param_set           : std_logic_vector(7 downto 0) := x"15";
    constant func_flash_param_get           : std_logic_vector(7 downto 0) := x"16";
    
    signal clk_125MHz                       : std_logic;
    signal clk_to_adc                       : std_logic;
    signal clk_locked                       : std_logic;
    signal counter125                       : std_logic_vector(26 downto 0):= (others => '0');
    signal counter50                        : integer;
    signal rst                              : std_logic;
    signal uart_tx_data                     : std_logic_vector(31 downto 0);
    signal uart_tx_valid                    : std_logic;
    signal GetFlag                          : std_logic;
    signal SetFlag                          : std_logic;
    signal uart_tx_ready                    : std_logic;
    signal uart_tx_compleat                 : std_logic;
    signal uart_rx_data                     : std_logic_vector(31 downto 0);
    signal uart_rx_valid                    : std_logic;
    signal uart_rx_ready                    : std_logic;
    signal byte                             : std_logic_vector(7 downto 0);
    signal adc_data_valid                   : std_logic;
    signal adc_data_reg                     : std_logic_vector(27 downto 0);
    signal adc_data_reg_sync0               : std_logic_vector(27 downto 0);
    signal adc_data_reg_sync1               : std_logic_vector(27 downto 0);
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

    type flash_params_stm                   is (IDLE, READ_FLASH, GET_READ_CRC, READY, WRITE_DATA, GET_WRITE_CRC, WRITE_FLASH, READ_DATA);
    signal flash_data_state                 : flash_params_stm;
    
    type get_wave_state_machine             is (IDLE, HEAD, GET_WAVEFORM, READY);
    signal get_wave_state,get_wave_next_state : get_wave_state_machine;
    signal get_wave_data                    : std_logic_vector(31 downto 0);
    signal get_wave_valid                   : std_logic;

    type state_machine                      is (IDLE, HEAD, RST_SMQ, CONF_ADC, SET_PARAMETERS, GET_PARAMETERS, GET_WAVEFORM, UART_COMPLEAT, UART_RST, SET_FLASH_PARAMETERS, GET_FLASH_PARAMETERS);
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
    
    signal spi_dac_cfg_data                 : std_logic_vector(15 downto 0);
    signal spi_dac_en                       : std_logic;
    signal dac_counter                      : integer;
    signal cs_wait_counter                  : std_logic_vector(7 downto 0);
    
    signal ADC_DATA0                        : std_logic_vector(13 downto 0);
    signal ADC_DATA1                        : std_logic_vector(13 downto 0);
    signal ADC_O_F                          : std_logic_vector(1 downto 0);
    signal ADC_LCLK                         : std_logic;
    signal adc_clk_counter                  : std_logic_vector(26 downto 0);
    signal SControl_d                       : std_logic_vector(31 downto 0);
    
    type uart_tx_state_machine              is (IDLE, head_state, buffer_state);
    signal uart_tx_state, uart_tx_next_state: uart_tx_state_machine;

    type FlashParametersStructure is (  DevId,
                                        VolttageOffset,
                                        CurrentOffset,
                                        kUC_f,
                                        kIL_f,
                                        CRC,
                                        StructureLength
    );

    type FlashParametersType is array (FlashParametersStructure'pos(StructureLength) - 1 downto 0) of std_logic_vector(31 downto 0);
    signal FlashParameters                  : FlashParametersType;
    signal FlashParametersBuff              : FlashParametersType;
    type ParametersStructure is (Volttage,
                                 Current,
                                 Status,
                                 WFBuffSize,
                                 VolttageOffset,
                                 CurrentOffset,
                                 Control,
                                 kUC_f,
                                 kIL_f,
                                 C1_f,
                                 L1_f,
                                 E_f,
                                 SamplingStep,
                                 Ec_f,
                                 El_f,
                                 Ecomm_f,
                                 DevId,
                                 StructureLength);
    type ParametersType is array (ParametersStructure'pos(StructureLength) - 1 downto 0) of std_logic_vector(31 downto 0);
    signal AllParameters                    : ParametersType;
    type SetParametersStructure is (Control,
                                    C1_f,
                                    L1_f,
                                    E_f,
                                    SamplingStep,
                                    RValue,
                                    StructureLength);
    type SetParametersType is array (SetParametersStructure'pos(StructureLength) - 1 downto 0) of std_logic_vector(31 downto 0);
    signal SetParameters         : SetParametersType:= (
                                                           SetParametersStructure'pos(Control)  => x"00000000",
                                                           SetParametersStructure'pos(C1_f)  => x"00000000",
                                                           SetParametersStructure'pos(L1_f)  => x"00000000",
                                                           SetParametersStructure'pos(E_f)  => x"00000000",
                                                           SetParametersStructure'pos(SamplingStep)  => x"00000000",
                                                           SetParametersStructure'pos(RValue)  => x"00000000"
                                                        );
    signal SetupBuff                         : SetParametersType;
    type ControlStructure       is (StartWaveformCapture,
                                    ResetWaveformCapture,
                                    ResetError,
                                    StructureLength);

    type StatusStructure       is ( SMQError,
                                    Waveform_IsReady,
                                    IGBT_Result,
                                    FlashData_IsReady,
                                    FlashData_CRCError,
                                    StructureLength);
    
    signal GetBuff                          : ParametersType;
    signal SetupRising                      : std_logic;
    
    type get_param_state_machine            is (IDLE, HEAD, GET_PAR, READY);
    signal get_par_state,get_par_next_state : get_param_state_machine;
    signal get_par_addr                     : integer range 0 to ParametersStructure'pos(StructureLength);
    signal get_data                         : std_logic_vector(31 downto 0);
    signal get_valid                        : std_logic;
    
    type DACCfgType is array (4 - 1 downto 0) of std_logic_vector(15 downto 0);
    signal DAC_CFG                          : DACCfgType;
    signal Tick2Baud_counter                : std_logic_vector(31 downto 0);
    signal Baud_Tick                        : std_logic;
    signal Baud_Tick_Counter                : integer;
    signal MaxBaudN                         : integer;
    signal IRQ_Baud_En                      : std_logic;
    signal UartRX_Timeout_IRQ               : std_logic;
    signal UartRst                          : std_logic;
    signal StateToIdle                      : std_logic;
    signal SysTickCounter                   : std_logic_vector(31 downto 0):= (others => '0');
    signal counter50_31_d                   : std_logic;
    signal MillisTick                       : std_logic;
    signal CurrentValue_Int                 : integer;
    signal VolttageValue_Int                : integer;
    signal ValidValue_Int                   : std_logic;
    signal uart_rxd                         : std_logic;
    signal uart_txd                         : std_logic;
    signal SquaringModuleOut                : std_logic;
    
    type SMQuadrator    is (IDLE, SMQSync, SMQStartProc, SMQMainProc, SMQError, SMQStable, SMQEndState);
    signal SMQState, SMQNextState           : SMQuadrator;
    signal sync_d_vec                       : std_logic_vector(1 downto 0);
    signal smq_en                           : std_logic;
    signal smq_en_d                         : std_logic;
    signal SMQStart                         : std_logic;
    
    signal uart_rxd_d                       : std_logic;
    signal uart_rxd_d1                      : std_logic;
    signal uart_rxd_fall                    : std_logic;
    signal rxd_1_d                          : std_logic;
    signal rxd_1_d1                         : std_logic;
    signal rxd_1_fall                       : std_logic;
    signal UartTxSwitch                     : std_logic;
    signal UartRxSwitch                     : std_logic;
    signal OpticUartActiv                   : std_logic;
    signal uart_activ                       : std_logic;
    signal ecomm_float                      : std_logic_vector(31 downto 0);
    signal uc_float                         : std_logic_vector(31 downto 0);
    signal il_float                         : std_logic_vector(31 downto 0);
    signal ec1_float                        : std_logic_vector(31 downto 0);
    signal el1_float                        : std_logic_vector(31 downto 0);
    signal CaptureData0                     : std_logic_vector(31 downto 0);
    signal CaptureData0_Valid               : std_logic;
    signal CaptureData1                     : std_logic_vector(31 downto 0);
    signal CaptureData1_Valid               : std_logic;

    signal WaveformSwitch0                  : std_logic_vector(3 downto 0);
    signal Waveform0_Ready                  : std_logic;
    signal Waveform0_Valid                  : std_logic;
    signal Waveform0_Length                 : std_logic_vector(31 downto 0);
    signal Waveform0_Data                   : std_logic_vector(31 downto 0);
    signal Waveform0_Busy                   : std_logic;

    signal uc_il_valid                      : std_logic;
    signal ec1_el1_valid                    : std_logic;
    signal ecomm_valid                      : std_logic;
    signal test_counter                     : std_logic_vector(7 downto 0);

    signal optic_rx_vec_0_sync              : std_logic_vector(3 downto 0);
    signal start_data_capture_ext           : std_logic;
    signal igbt                             : std_logic;
    signal error_squaring                   : std_logic;
    signal reset_smq                        : std_logic;
    signal SquaringModuleOutNot             : std_logic;
    signal SMQStableCounter                 : integer range 0 to 32;
    signal waveform_in_data                 : std_logic_vector(31 downto 0);
    signal at24c_addr                       : std_logic_vector(natural(log2(real(4096/4 - 1))) - 1 downto 0);
    signal at24c_data_in                    : std_logic_vector(31 downto 0);
    signal at24c_wr_en                      : std_logic;
    signal at24c_wr_ack                     : std_logic;
    signal at24c_data_out                   : std_logic_vector(31 downto 0) := (others => '0');
    signal at24c_rd_en                      : std_logic;
    signal at24c_rd_ack                     : std_logic := '0';
    signal at24c_rst                        : std_logic := '0';
    signal at24c_error                      : std_logic := '0';
    signal at24c_busy                       : std_logic := '0';
    signal at24c_busy_d0                    : std_logic := '0';



    type AT24C_STM                  is (idle, write_data_st, read_data_st, delay_st, error_st, busy_st, wait_st);
    signal AT24C_state                      : AT24C_STM;
    signal AT24C_counter                    : std_logic_vector(31 downto 0);
    signal timeCounter                      : std_logic_vector(31 downto 0);
    signal flash_counter                    : integer;
    signal CRC32_rst                        : std_logic;
    signal CRC32_din                        : std_logic_vector(7 downto 0);
    signal CRC32_wr_en                      : std_logic;
    signal CRC32_wr_ack                     : std_logic;
    signal CRC32_crc_out                    : std_logic_vector(31 downto 0);
    signal CRC32_valid                      : std_logic;
    signal CRC32_counter                    : std_logic_vector(31 downto 0);
    signal CRC_Error                        : std_logic;
    signal StartWriteFlash                  : std_logic;
    signal FlashData_Ready                  : std_logic;
    signal FlashGetData                     : std_logic_vector(31 downto 0);
    signal FlashGetValid                    : std_logic;
    signal FlashReadCompleat                : std_logic;
    
    signal cOfst_int                        : integer;
    signal vOfst_int                        : integer;
    signal c_int                            : integer;
    signal v_int                            : integer;
    
    
begin

rst <= (not reset_n) or (not clk_locked);

optic_rx_vec_0_sync_proc : 
  process(clk_125MHz)
  begin
    if rising_edge(clk_125MHz) then
      optic_rx_vec_0_sync(optic_rx_vec_0_sync'length - 1 downto 1) <= optic_rx_vec_0_sync(optic_rx_vec_0_sync'length - 2 downto 0);
      optic_rx_vec_0_sync(0) <= optic_rx_vec(0);
    end if;
  end process;

start_data_capture_ext <= (not optic_rx_vec_0_sync(optic_rx_vec_0_sync'length - 1)) and optic_rx_vec_0_sync(optic_rx_vec_0_sync'length - 2);

uart_rxd <= not optic_rx_vec(3);
optic_tx_vec(3) <= not uart_txd;

optic_tx_vec(1) <= igbt;

p39 <= clk_125MHz;
p42 <= ADC_LCLK;

process(clk_125MHz)
begin
  if rising_edge(clk_125MHz) then
	AllParameters(ParametersStructure'pos(Volttage))                                        <= conv_std_logic_vector(VolttageValue_Int, 32);
	AllParameters(ParametersStructure'pos(Current))                                         <= conv_std_logic_vector(CurrentValue_Int, 32);
	AllParameters(ParametersStructure'pos(WFBuffSize))                                      <= conv_std_logic_vector(waveform_buff_size, 32);
	
	AllParameters(ParametersStructure'pos(VolttageOffset))                                  <= FlashParametersBuff(FlashParametersStructure'pos(VolttageOffset)); --SetParameters(SetParametersStructure'pos(VolttageOffset));
	AllParameters(ParametersStructure'pos(DevId))                                           <= FlashParametersBuff(FlashParametersStructure'pos(DevId)); --SetParameters(SetParametersStructure'pos(VolttageOffset));
	AllParameters(ParametersStructure'pos(CurrentOffset))                                   <= FlashParametersBuff(FlashParametersStructure'pos(CurrentOffset)); --SetParameters(SetParametersStructure'pos(CurrentOffset));
	AllParameters(ParametersStructure'pos(Control))                                         <= SetParameters(SetParametersStructure'pos(Control));
	AllParameters(ParametersStructure'pos(kUC_f))                                           <= FlashParametersBuff(FlashParametersStructure'pos(kUC_f)); --SetParameters(SetParametersStructure'pos(kUC_f));
	AllParameters(ParametersStructure'pos(kIL_f))                                           <= FlashParametersBuff(FlashParametersStructure'pos(kIL_f)); --SetParameters(SetParametersStructure'pos(kIL_f));
	AllParameters(ParametersStructure'pos(C1_f))                                            <= SetParameters(SetParametersStructure'pos(C1_f));
	AllParameters(ParametersStructure'pos(L1_f))                                            <= SetParameters(SetParametersStructure'pos(L1_f));
	AllParameters(ParametersStructure'pos(E_f))                                             <= SetParameters(SetParametersStructure'pos(E_f));
	AllParameters(ParametersStructure'pos(SamplingStep))                                    <= SetParameters(SetParametersStructure'pos(SamplingStep));
	
	AllParameters(ParametersStructure'pos(Status))(StatusStructure'pos(Waveform_IsReady))   <= Waveform0_Valid;
	AllParameters(ParametersStructure'pos(Status))(StatusStructure'pos(SMQError))           <= error_squaring;
	AllParameters(ParametersStructure'pos(Status))(StatusStructure'pos(IGBT_Result))        <= not SquaringModuleOut;
	AllParameters(ParametersStructure'pos(Status))(StatusStructure'pos(FlashData_IsReady))  <= FlashData_Ready;
	AllParameters(ParametersStructure'pos(Status))(StatusStructure'pos(FlashData_CRCError)) <= CRC_Error;
	AllParameters(ParametersStructure'pos(Status))(31 downto StatusStructure'pos(StructureLength))    <= (others => '0');
    
	
--	if (SMQState = SMQStartProc) then
	if ((SMQState = SMQMainProc) and (SquaringModuleOut = '0')) then
	  AllParameters(ParametersStructure'pos(Ec_f))                <= ec1_float;
	  AllParameters(ParametersStructure'pos(El_f))                <= el1_float;
	  AllParameters(ParametersStructure'pos(Ecomm_f))             <= ecomm_float;
	end if;
  end if;
end process;

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

Tick2Baud_counter_proc :
  process(clk_125MHz, IRQ_Baud_En)
  begin
    if (IRQ_Baud_En = '0') then
      Tick2Baud_counter <= (others => '0');
      Baud_Tick <= '0';
    elsif rising_edge(clk_125MHz) then
      if (Tick2Baud_counter = g_CLKS_PER_BIT) then
        Tick2Baud_counter <= (others => '0');
        Baud_Tick <= '1';
      else
        Tick2Baud_counter <= Tick2Baud_counter + 1;
        Baud_Tick <= '0'; 
      end if;
    end if;
  end process;

Baud_Tick_Counter_proc :
  process(clk_125MHz, IRQ_Baud_En)
  begin
    if (IRQ_Baud_En = '0') then
      Baud_Tick_Counter <= 0;
    elsif rising_edge(clk_125MHz) then
      if (Baud_Tick = '1') then
        Baud_Tick_Counter <= Baud_Tick_Counter + 1;
      end if;
    end if;
  end process;

IRQ_Baud_Proc :
  process(clk_125MHz, IRQ_Baud_En)
  begin
    if (IRQ_Baud_En = '0') then
      UartRX_Timeout_IRQ <= '0';
    elsif rising_edge(clk_125MHz) then
      if (Baud_Tick_Counter = MaxBaudN) then
        UartRX_Timeout_IRQ <= '1';
      end if;
    end if;
  end process;

StateToIdle <= rst or UartRX_Timeout_IRQ;

process(clk_125MHz)
begin
  if rising_edge(clk_125MHz) then
    uart_rxd_d <= uart_rxd;
    uart_rxd_d1 <= uart_rxd_d;
    rxd_1_d <= rxd_1;
    rxd_1_d1 <= rxd_1_d;
  end if;
end process;

OpticUartActiv_proc :
  process(clk_125MHz, state)
  begin
    if (state = IDLE) then
      if rising_edge(clk_125MHz) then
        if (uart_rxd_d1 = '1') and (uart_rxd_d = '0') then
          OpticUartActiv <= '1';
          uart_activ <= '1';
        elsif (rxd_1_d1 = '1') and (rxd_1_d = '0')   then
          OpticUartActiv <= '0';
          uart_activ <= '1';
        end if;
      end if;
    else
      uart_activ <= '0';
    end if;
  end process;

Switch_process :
  process(clk_125MHz)
  begin
    if rising_edge(clk_125MHz) then
      if (OpticUartActiv = '1') then
        txd_1 <= '1';
        uart_txd <= UartTxSwitch;
        UartRxSwitch <= uart_rxd_d1;
      else
        txd_1 <= UartTxSwitch;
        uart_txd <= '1';
        UartRxSwitch <= rxd_1_d1;
      end if;
    end if;
  end process;

AT24C_control_inst : entity AT24C_master
  Generic map(
    c_mem_range       => 4096,
    c_div_clk         => 1000
    )
  Port map(
    clk               => clk_125MHz,
    rst               => at24c_rst,
    addr              => at24c_addr,
    data_in           => at24c_data_in,
    wr_en             => at24c_wr_en,
    wr_ack            => at24c_wr_ack,
    data_out          => at24c_data_out,
    rd_en             => at24c_rd_en,
    rd_ack            => at24c_rd_ack,
    error             => at24c_error,
    busy_out          => at24c_busy,
    sda               => i2c_sda,
    scl               => i2c_scl
  );

CRC32_inst : ENTITY CRC32 
  PORT MAP(
    clk              => clk_125MHz,
    rst              => CRC32_rst,
    din              => CRC32_din,
    wr_en            => CRC32_wr_en,
    wr_ack           => CRC32_wr_ack,
    crc_out          => CRC32_crc_out,
    valid            => CRC32_valid
  );

flash_data_state_proc :
  process(clk_125MHz, rst)
  begin
    if (rst = '1') then 
      flash_data_state <= IDLE;
      at24c_rst <= '1';
      at24c_wr_en <= '0';
      at24c_rd_en <= '0';
      CRC32_rst <= '1';
      CRC32_wr_en <= '0';
      CRC_Error <= '0';
      FlashGetValid <= '0';
      FlashData_Ready <= '0';
      wp <= '1';
    elsif rising_edge(clk_125MHz) then
      case (flash_data_state) is
        when IDLE =>
          wp <= '1';
          at24c_rst <= '0';
          if (at24c_busy = '0') then
            flash_data_state <= READ_FLASH;
            at24c_rd_en <= '1';
            at24c_addr <= (others => '0');
          end if;
        when READ_FLASH =>
          if ((at24c_rd_en = '1') and (at24c_rd_ack = '1')) then
            FlashParameters(conv_integer(unsigned(at24c_addr))) <= at24c_data_out;
            if (at24c_addr < FlashParametersStructure'pos(CRC)) then
              at24c_addr <= at24c_addr + 1;  
            else
              at24c_rd_en <= '0';
              flash_data_state <= GET_READ_CRC;
              CRC32_counter <= (others => '0');
              CRC32_rst <= '1';
            end if;
          end if;
        when GET_READ_CRC =>
          CRC32_rst <= '0';
          if (CRC32_counter < FlashParametersStructure'pos(StructureLength)*4) then
            CRC32_din <= FlashParameters(conv_integer(unsigned(CRC32_counter(31 downto 2))))(conv_integer(unsigned(CRC32_counter(1 downto 0)))*8 + 7 downto conv_integer(unsigned(CRC32_counter(1 downto 0)))*8);
            CRC32_wr_en <= '1';
            if (CRC32_wr_ack = '1') then
              CRC32_counter <= CRC32_counter + 1;
            end if;
          else
            CRC32_wr_en <= '0';
            if (CRC32_valid = '1') then
              flash_data_state <= READY;
              if (CRC32_crc_out = x"00000000") then
                CRC_Error <= '0';
                FlashParametersBuff <= FlashParameters;
              else
                CRC_Error <= '1';
              end if;
            end if;
          end if;
        when READY =>
          FlashReadCompleat <= '0';
          FlashData_Ready <= '1';
          if (state = SET_FLASH_PARAMETERS) then
            flash_data_state <= WRITE_DATA;
            flash_counter <= 0;
          --elsif (state = GET_FLASH_PARAMETERS) then
          --  if (uart_tx_ready = '1') then
          --    FlashGetData <= conv_std_logic_vector(FlashParametersStructure'pos(StructureLength) - 1, 14) & "00" & uart_function & id;
          --    FlashGetValid <= '1';
          --    flash_counter <= 0;
          --    flash_data_state <= READ_DATA;
          --  else
          --    FlashGetValid <= '0';
          --  end if;
          --else
            
          end if;
        when READ_DATA =>
			FlashData_Ready <= '0';
          if (flash_counter < FlashParametersStructure'pos(StructureLength) - 1) then
            FlashGetValid <= '1';
            FlashGetData <= FlashParameters(flash_counter);
            if (uart_tx_ready = '1') then
              flash_counter <= flash_counter + 1;
            end if;
          else
            flash_data_state <= READY;
            FlashReadCompleat <= '1';
            FlashGetValid <= '0';
          end if;
        when WRITE_DATA =>
		  FlashData_Ready <= '0';
          if (flash_counter < FlashParametersStructure'pos(StructureLength) - 1) then
            if (uart_rx_valid = '1') then
              flash_counter <= flash_counter + 1;
              FlashParameters(flash_counter) <= uart_rx_data;
            end if;
          else
            flash_data_state <= GET_WRITE_CRC;
            CRC32_counter <= (others => '0');
            FlashParameters(FlashParametersStructure'pos(CRC)) <= (others => '1');
            CRC32_rst <= '1';
          end if;
        when GET_WRITE_CRC =>
          CRC32_rst <= '0';
          if (CRC32_counter < (FlashParametersStructure'pos(StructureLength) - 1)*4) then
            CRC32_din <= FlashParameters(conv_integer(unsigned(CRC32_counter(31 downto 2))))(conv_integer(unsigned(CRC32_counter(1 downto 0)))*8 + 7 downto conv_integer(unsigned(CRC32_counter(1 downto 0)))*8);
            CRC32_wr_en <= '1';
            if (CRC32_wr_ack = '1') then
              CRC32_counter <= CRC32_counter + 1;
            end if;
          else
            CRC32_wr_en <= '0';
            if (CRC32_valid = '1') then
              flash_data_state <= WRITE_FLASH;
              FlashParameters(FlashParametersStructure'pos(CRC)) <= CRC32_crc_out;
              at24c_addr <= (others => '0');
              at24c_data_in <= FlashParameters(0);
              at24c_wr_en <= '1';
              wp <= '0';
            end if;
          end if;
        when WRITE_FLASH =>
            wp <= '0';
            if ((at24c_wr_en = '1') and (at24c_wr_ack = '1')) then
              if (at24c_addr < FlashParametersStructure'pos(StructureLength)) then
                at24c_addr <= at24c_addr + 1;
                at24c_data_in <= FlashParameters(conv_integer(unsigned(at24c_addr + 1)));
              else
                at24c_wr_en <= '0';
                flash_data_state <= IDLE;
                CRC32_counter <= (others => '0');
                CRC32_rst <= '1';
              end if;
            end if;
        when others =>
          flash_data_state <= IDLE;
      end case;
    end if;
  end process;

--timeCounter_proc :
--  process(clk_125MHz, rst)
--  begin
--    if (rst = '1') then
--      at24c_rst <= '1';
--      timeCounter <= (others => '0');
--    elsif rising_edge(clk_125MHz) then
--      if (timeCounter < 250000000) then
--        timeCounter <= timeCounter + 1;
--        at24c_rst <= '0';
--      else
--        timeCounter <= (others => '0');
--        at24c_rst <= '1';
--      end if;
--    end if;
--  end process;
--at24c_rst <= rst;
--i2c_sda <= 'Z';
--i2c_scl <= 'Z';

--AT24C_state_proc :
--process(clk_125MHz, rst)
--begin
--  if (rst = '1') then
--    AT24C_state <= idle;
--    AT24C_counter <= (others => '0');
--    at24c_data_in <= (others => '1');
--    at24c_wr_en <= '0';
--    at24c_addr <= (others => '0');
--    at24c_rd_en <= '0';
--    at24c_rst <= '1';
--  elsif rising_edge(clk_125MHz) then
--  at24c_busy_d0 <= at24c_busy;
--    if (at24c_error = '1') then
--      AT24C_state <= idle;
--      at24c_wr_en <= '0';
--      at24c_rd_en <= '0';
--      at24c_rst <= '1';
--      if (AT24C_counter <= 125000000) then
--        AT24C_counter <= AT24C_counter + 1;
--      else
--        AT24C_counter <= (others => '0');
--        AT24C_state <= idle;
--      end if;
--    else
--      at24c_rst <= '0';
--      case (AT24C_state) is
--        when idle =>
--          if (AT24C_counter < 125000*10) then
--            AT24C_counter <= AT24C_counter + 1;
--          else
--            AT24C_counter <= (others => '0');
--            AT24C_state <= write_data_st;
--          end if;
--        when write_data_st =>
--            at24c_wr_en <= '1';
--            if ((at24c_wr_ack = '1') and (at24c_wr_en = '1')) then
--              AT24C_state <= busy_st;
--              at24c_wr_en <= '0';
--            end if;
--        when busy_st =>
--          if ((at24c_busy = '0') and (at24c_busy_d0 = '1'))then
--             AT24C_state <= delay_st;
--             AT24C_counter <= (others => '0');
--          end if;
--        when read_data_st =>
--          if (at24c_busy = '1') then
--            at24c_rd_en <= '0';
--          end if;
--          if (at24c_rd_ack = '1') then
--            at24c_addr <= at24c_addr + 1;
--            at24c_data_in <= at24c_data_in + 1;
--            AT24C_state <= idle;
--            AT24C_counter <= (others => '0');
--          end if;
--        when delay_st =>
--          if (AT24C_counter < 125000*32) then
--            AT24C_counter <= AT24C_counter + 1;
--          else
--            AT24C_counter <= (others => '0');
--            AT24C_state <= read_data_st;
--            at24c_rd_en <= '1';
--          end if;
--        when others =>
--          
--      end case;
--    end if;
--  end if;
--end process;

uart_module_inst : entity uart_module
  Generic map(
    c_freq_hz       => c_sys_clk_Hz,
    c_boad_rate     => c_uart_boad_rate
  )
  Port map(
    clk             => clk_125MHz,
    rst             => UartRst,
    tx_data         => uart_tx_data,
    tx_valid        => uart_tx_valid,
    tx_ready        => uart_tx_ready,
    tx_done         => uart_tx_compleat,
    txd             => UartTxSwitch,
    rx_data         => uart_rx_data,
    rx_valid        => uart_rx_valid,
    rx_ready        => uart_rx_ready,
    rxd             => UartRxSwitch
  );
uart_rx_ready <= '1';

LTC2145_14_receiver_inst : ENTITY LTC2145_14_receiver
  GENERIC MAP(
    ddr_mode    => false
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

process(ADC_LCLK)
begin
  if rising_edge(ADC_LCLK) then
    adc_data_reg <= ADC_DATA1 &  ADC_DATA0;
  end if;
end process;

process(clk_125MHz)
begin
  if rising_edge(clk_125MHz) then
    adc_data_reg_sync0 <= adc_data_reg;
    adc_data_reg_sync1 <= adc_data_reg_sync0;
  end if;
end process;

adc_value_to_int_proc :
process(rst, clk_125MHz)
begin
  if (rst = '1') then
    CurrentValue_Int <= 0;
    VolttageValue_Int <= 0;
    ValidValue_Int <= '0';
  elsif rising_edge(clk_125MHz) then
    c_int <= conv_integer(unsigned(adc_data_reg_sync1(27 downto 14)));
    v_int <= conv_integer(unsigned(adc_data_reg_sync1(13 downto 00)));
    
    cOfst_int <= conv_integer(signed(FlashParametersBuff(FlashParametersStructure'pos(CurrentOffset))));
    vOfst_int <= conv_integer(signed(FlashParametersBuff(FlashParametersStructure'pos(VolttageOffset))));
  
    CurrentValue_Int <= c_int - cOfst_int;
    VolttageValue_Int <= v_int - vOfst_int;
  end if;
end process;

SquaringModule_inst : entity SquaringModule
  Port map(
    clk             => clk_125MHz,
    curren_int      => CurrentValue_Int,
    volt_int        => VolttageValue_Int,
    kuc_float       => FlashParametersBuff(FlashParametersStructure'pos(kUC_f)),
    kil_float       => FlashParametersBuff(FlashParametersStructure'pos(kIL_f)),
    c1_float        => SetupBuff(SetParametersStructure'pos(C1_f)),
    l1_float        => SetupBuff(SetParametersStructure'pos(L1_f)),
    ut_float        => SetupBuff(SetParametersStructure'pos(E_f)),
    k_float         => SetupBuff(SetParametersStructure'pos(RValue)),
    
    uc_float        => uc_float,
    il_float        => il_float,
    
    ec1_float       => ec1_float,
    el1_float       => el1_float,
    ecomm_float     => ecomm_float,
    igbt            => SquaringModuleOut
  );

SMQuadrator_sync_proc :
process(clk_125MHz, rst)
begin
  if (rst = '1') then
    SMQState <= IDLE;
  elsif rising_edge(clk_125MHz) then
    SMQState <= SMQNextState;
  end if;
end process;

SMQuadrator_nextState_proc :
process(SMQState, smq_en, SquaringModuleOut, reset_smq, SMQStableCounter)
begin
  SMQNextState <= SMQState;
  case (SMQState) is
    when IDLE => 
      SMQNextState <= SMQSync;
    when SMQSync =>
      if (smq_en = '1') then
        SMQNextState <= SMQStartProc;
      end if;
    when SMQStartProc =>
      if (smq_en = '0') then
        SMQNextState <= SMQError;
      else
        if (SquaringModuleOut = '1') then
          SMQNextState <= SMQMainProc;
        end if;
--      else
--        SMQNextState <= SMQMainProc;
      end if;
    when SMQMainProc =>
      if (smq_en = '0') then
        SMQNextState <= SMQError;
      elsif (SquaringModuleOut = '0') then
        SMQNextState <= SMQStable;
      end if;
    when SMQStable =>
      if (SquaringModuleOut = '1') then
        SMQNextState <= SMQMainProc;
      elsif (SMQStableCounter >= 31) then
        SMQNextState <= SMQEndState;
      end if;
    when SMQError =>
      if (reset_smq = '1') then
        SMQNextState <= IDLE;
      end if;
    when SMQEndState =>
      if (smq_en = '0') then
        SMQNextState <= IDLE;
      end if;
    when others => 
      SMQNextState <= IDLE;
  end case;
end process;

SMQuadrator_Out_proc :
process(SMQState)
begin
  igbt <= '0';
  error_squaring <= '0';
  case (SMQState) is
    when SMQMainProc =>
      igbt <= '1';
    when SMQError =>
      error_squaring <= '1';
    when SMQStable =>
      igbt <= '1';
    when others => 
  end case;
end process;

sync_d_vec_proc :
  process(clk_125MHz)
  begin
    if rising_edge(clk_125MHz) then
      sync_d_vec(0) <= optic_rx_vec(1);
      sync_d_vec(sync_d_vec'length - 1 downto 1) <= sync_d_vec(sync_d_vec'length - 2 downto 0);
      smq_en <= sync_d_vec(sync_d_vec'length - 1);
    end if;
  end process;

SMQStableCounter_proc :
  process(clk_125MHz)
  begin
    if rising_edge(clk_125MHz) then
      if (SMQState = SMQStable) then
        SMQStableCounter <= SMQStableCounter + 1;
      else
        SMQStableCounter <= 0;
      end if;
    end if;
  end process;

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
      SetupRising <= '0';
      SetupBuff(SetParametersStructure'pos(Control))(ControlStructure'pos(StartWaveformCapture)) <= '0';
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

process(clk50MHz, rst)
begin
  if (rst = '1') then
    counter50 <= 0;
  elsif rising_edge(clk50MHz) then
    if (counter50 = 49999) then
      MillisTick <= '1';
      counter50 <= 0;
    else
      MillisTick <= '0';
      counter50 <= counter50 + 1;
    end if; 
  end if;
end process;

SysTickCounter_proc:
  process(clk50MHz, rst)
  begin
    if (rst = '1') then
      SysTickCounter <= (others => '0');
    elsif rising_edge(clk50MHz) then
      if (MillisTick = '1') then
        SysTickCounter <= SysTickCounter + 1;
      end if;
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

--gtp(0) <= FlashData_Ready;
--gtp(1) <= counter125(counter125'length - 1);
--gtp(2) <= uart_tx_compleat;
----spi_sck <= counter125(counter125'length - 1);
--
--rtp(0) <= CRC_Error;
--rtp(1) <= not clk_locked;

leds(0) <= FlashData_Ready;
leds(1) <= counter125(counter125'length - 1) and (clk_locked);
leds(2) <= CRC_Error;
leds(3) <= counter125(counter125'length - 1) and (clk_locked);

----------------------------------------
-- main state process 
-- type state_machine                      is (HEAD, CONF_ADC, SET_PARAMETERS, GET_PARAMETERS, GET_WAVEFORM)
-- signal state, next_state                : state_machine;
-- signal uart_rx_data_length              : std_logic_vector(15 downto 0);
-- signal uart_function                    : std_logic_vector(7 downto 0);
----------------------------------------
sync_proc :
process(StateToIdle, clk_125MHz)
begin
  if (StateToIdle = '1') then
    state <= IDLE;
  elsif rising_edge(clk_125MHz) then
    state <= next_state;
  end if;
end process;

next_state_proc :
process(state, uart_activ, uart_rx_valid, uart_rx_data, adc_cfg_state, set_par_state, uart_tx_compleat, get_data, get_wave_state, get_par_state, UartRX_Timeout_IRQ, flash_data_state, FlashReadCompleat)
begin
  next_state <= state;
    case (state) is
      when IDLE =>
        if (uart_activ = '1') then
          next_state <= HEAD;
        end if;
      when HEAD =>
        if (uart_rx_valid = '1') then
          if (uart_rx_data(7 downto 0) = id) then
              case uart_rx_data(15 downto 8) is
                when func_conf_adc => 
                  next_state <= CONF_ADC;
                when func_param_set =>
                  next_state <= SET_PARAMETERS;
                when func_param_get =>
                  next_state <= GET_PARAMETERS;
                when func_get_waveform =>
                  next_state <= GET_WAVEFORM;
                when func_SMQ_reset =>
                  next_state <= RST_SMQ;
                when func_flash_param_set =>
                  next_state <= SET_FLASH_PARAMETERS;
                when func_flash_param_get =>
                  next_state <= GET_FLASH_PARAMETERS;
                when others =>
                  next_state <= UART_RST;
              end case;
            else
              next_state <= UART_RST;
          end if;
        end if;
      when SET_FLASH_PARAMETERS =>
        if (flash_data_state = GET_WRITE_CRC) then
          next_state <= UART_COMPLEAT;
        end if;
      when GET_FLASH_PARAMETERS =>
        if (FlashReadCompleat = '1') then
          next_state <= UART_COMPLEAT;
        end if;
      when RST_SMQ =>
        next_state <= UART_COMPLEAT;
      when CONF_ADC =>
        if (adc_cfg_state = READY) then
          next_state <= UART_COMPLEAT;
        end if;
      when SET_PARAMETERS =>
        if (set_par_state = READY) then
          next_state <= UART_COMPLEAT;
        end if;
      when GET_PARAMETERS =>
        if (get_par_state = READY) then
          next_state <= UART_COMPLEAT;
        end if;
      when GET_WAVEFORM =>
        if (get_wave_state = READY) then
          next_state <= UART_COMPLEAT;
        end if;
      when UART_COMPLEAT =>
        if (uart_tx_compleat = '1') then
          next_state <= IDLE;
        end if;
      when UART_RST =>
      if (UartRX_Timeout_IRQ = '1') then
        next_state <= IDLE;
      end if;
      when others =>
        next_state <= IDLE;
    end case;
end process;

--    constant func_conf_adc                  : std_logic_vector(7 downto 0) := x"10";
--    constant func_param_set                 : std_logic_vector(7 downto 0) := x"11";
--    constant func_param_get                 : std_logic_vector(7 downto 0) := x"12";
--    constant func_get_waveform              : std_logic_vector(7 downto 0) := x"13";
--    constant func_SMQ_reset                 : std_logic_vector(7 downto 0) := x"14";

state_out_proc :
process(state, adc_cfg_state, set_par_state, get_par_state, get_wave_data, get_wave_valid, get_data, get_valid, uart_function, adc_spi_en, adc_spi_data, flash_data_state)
begin
  spi_master_enable     <= '0';
  spi_master_clk_div    <= 3;
  spi_master_cpol       <= '1';
  spi_master_cpha       <= '1';
  spi_master_addr       <= 0;
  uart_tx_valid         <= '0';
  IRQ_Baud_En           <= '0';
  UartRst               <= '0';
  reset_smq             <= '0';
    case (state) is
      when IDLE =>
        UartRst <= '1';
      when RST_SMQ =>
        reset_smq <= '1';
        uart_tx_data  <= x"0000" & func_SMQ_reset & id;
        uart_tx_valid <= '1';
      when CONF_ADC =>
        IRQ_Baud_En <= '1';
        MaxBaudN <= 2*10*4*5;
        if (adc_cfg_state = READY) then
--          uart_tx_data  <= x"0000" & uart_function & id;
          uart_tx_data  <= x"0000" & func_conf_adc & id;
          uart_tx_valid <= '1';
        end if;
        spi_master_enable <= adc_spi_en;
        spi_master_tx_data <= adc_spi_data;
      when SET_FLASH_PARAMETERS => 
        IRQ_Baud_En <= '1';
        if (flash_data_state = GET_WRITE_CRC) then
          uart_tx_data  <= x"0000" & func_param_set & id;
          uart_tx_valid <= '1';
        end if;
      when SET_PARAMETERS =>
        IRQ_Baud_En <= '1';
        MaxBaudN <= 2*(SetParametersStructure'pos(StructureLength) - 1)*4*10;
        case (set_par_state) is
          when READY => 
--            uart_tx_data  <= x"0000" & uart_function & id;
            uart_tx_data  <= x"0000" & func_param_set & id;
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
      when UART_RST =>
        MaxBaudN <= 10;
        IRQ_Baud_En <= '1';
        UartRst <= '1';
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
process(set_par_state, state, set_par_addr, dac_cfg_state)
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
        set_par_next_state <= READY;
--        if (SetParameters(SetParametersStructure'pos(Control))(1) = '1') then
--          set_par_next_state <= CFG_DAC;
--        else
--          set_par_next_state <= READY;
--        end if;
--      when CFG_DAC =>
--        if (dac_cfg_state = READY) then
--          set_par_next_state <= READY;
--        end if;
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
--dac_cfg_sync_proc :
--process(set_par_state, clk_125MHz)
--begin
--  if (set_par_state = IDLE) then
--    dac_cfg_state <= IDLE;
--  elsif rising_edge(clk_125MHz) then
--    dac_cfg_state <= dac_cfg_next_state;
--  end if;
--end process;
--
--dac_cfg_next_state_proc :
--process(dac_cfg_state, set_par_state, dac_counter, spi_master_enable, spi_master_busy, cs_wait_counter)
--begin
--  dac_cfg_next_state <= dac_cfg_state;
--  spi_dac_en <= '0';
--    case (dac_cfg_state) is
--      when IDLE =>
--        if (set_par_state = CFG_DAC) then
--            dac_cfg_next_state <= SET_SPI;
--        end if;
--      when SET_SPI =>
--        if (spi_master_enable = '1') then
--          dac_cfg_next_state <= SPI_BUSY_DOWN;
--        end if;
--          spi_dac_cfg_data <= DAC_CFG(dac_counter);
--          spi_dac_en <= not spi_master_busy;
--      when SPI_BUSY_DOWN =>
--        if (spi_master_busy = '0') then 
--          dac_cfg_next_state <= CS_WAIT;
--        end if;
--      when CS_WAIT =>
--        if (cs_wait_counter >= x"0f") then
--          if dac_counter = DAC_CFG'length then
--            dac_cfg_next_state <= READY;
--          else
--            dac_cfg_next_state <= SET_SPI;
--          end if;
--        end if;
--      when READY =>
--        
--      when others =>
--        dac_cfg_next_state <= IDLE;
--    end case;
--end process;
--
--cs_wait_counter_proc :
--  process(clk_125MHz, dac_cfg_state)
--  begin
--    if (dac_cfg_state /= CS_WAIT) then
--      cs_wait_counter <= (others => '0');
--    elsif rising_edge(clk_125MHz) then
--      cs_wait_counter <= cs_wait_counter + 1;
--    end if;
--  end process;
--
--dac_counter_proc :
--  process(clk_125MHz, dac_cfg_state)
--  begin
--    if (dac_cfg_state = IDLE) then
--      dac_counter <= 0;
--    elsif rising_edge(clk_125MHz) then
--      if (spi_master_enable = '1') then
--        dac_counter <= dac_counter + 1;
--      end if;
--    end if;
--  end process;

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
process(get_par_state, state, uart_tx_ready, uart_function, get_par_addr)
begin
  get_par_next_state <= get_par_state;
    case (get_par_state) is
      when IDLE =>
        if (state = GET_PARAMETERS) then
          get_par_next_state <= HEAD;
        end if;
      when HEAD => 
        if (uart_tx_ready = '1') then
          get_par_next_state <= GET_PAR;
        end if;
      when GET_PAR =>
        if (get_par_addr >= ParametersStructure'pos(StructureLength) - 1) then
          get_par_next_state <= READY;
        end if;
      when READY => 
      when others =>
        get_par_next_state <= IDLE;
    end case;
end process;

process(get_par_state, clk_125MHz) 
begin
  if (get_par_state = idle) then 
    get_valid <= '0';
    get_par_addr <= 0;
  elsif rising_edge(clk_125MHz) then
    case (get_par_state) is
      when HEAD => 
        get_valid <= '1';
        get_data <= conv_std_logic_vector(ParametersStructure'pos(StructureLength), 14) & "00" & uart_function & id;
        GetBuff <= AllParameters;
      when GET_PAR => 
        get_valid <= '1';
        get_data <= GetBuff(get_par_addr);
        if (uart_tx_ready = '1') then
          get_par_addr <= get_par_addr + 1;
        end if;
      when others =>
        get_valid <= '0';
    end case;
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
process(get_wave_state, state, uart_tx_ready, Waveform0_Busy)
begin
  get_wave_next_state <= get_wave_state;
  Waveform0_Ready <= '0';
    case (get_wave_state) is
      when IDLE =>
        if (state = GET_WAVEFORM) then
          get_wave_next_state <= HEAD;
        end if;
      when HEAD => 
        if (uart_tx_ready = '1') then
          get_wave_next_state <= GET_WAVEFORM;
        end if;
      when GET_WAVEFORM =>
        if (Waveform0_Busy = '0') then
          get_wave_next_state <= READY;
        end if;
        Waveform0_Ready <= uart_tx_ready;
      when others =>
        get_wave_next_state <= IDLE;
    end case;
end process;

get_wave_out_proc :
  process(clk_125MHz)
  begin
    if rising_edge(clk_125MHz) then
      case(get_wave_state) is
        when HEAD => 
          get_wave_valid <= '1';
          get_wave_data  <= Waveform0_Length(13 downto 0)& "00" & func_get_waveform & id;
        when GET_WAVEFORM =>
          get_wave_valid <= Waveform0_Valid;
          get_wave_data <= Waveform0_Data;
        when others =>
          get_wave_valid <= '0';
      end case;
    end if;
  end process;

start_write_waveform <= SetupBuff(SetParametersStructure'pos(Control))(ControlStructure'pos(StartWaveformCapture)) or start_data_capture_ext;
SquaringModuleOutNot <= not SquaringModuleOut;

process(clk_125MHz)
begin
  if rising_edge(clk_125MHz) then
    waveform_in_data <= igbt & SquaringModuleOutNot & adc_data_reg_sync1(27 downto 14) & SquaringModuleOutNot & optic_rx_vec(1) & adc_data_reg_sync1(13 downto 0);
  end if;
end process;

DataCaptureModule_0_inst : ENTITY DataCaptureModule
  GENERIC MAP(
    c_max_n_word    => waveform_buff_size
  )
  PORT MAP
  (
    clk             => clk_125MHz,
    rst             => rst,

    InDSamplParam   => SetupBuff(SetParametersStructure'pos(SamplingStep)),

    InData          => waveform_in_data,

    InReady         => open,

    InStart         => start_write_waveform,
    
    InNumWord       => waveform_buff_size,
    
    OutBusy         => Waveform0_Busy,
    OutDataLength   => Waveform0_Length,
    OutData         => Waveform0_Data,
    OutValid        => Waveform0_Valid,
    OutReady        => Waveform0_Ready
  );

end Behavioral;