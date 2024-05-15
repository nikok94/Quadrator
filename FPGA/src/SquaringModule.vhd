library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.Std_Logic_Arith.all;

library work;
use work.IntToFloat;
use work.MultFloat;
use work.AddFloat;
use work.DivFloat;
use work.FloatCompare;
use work.SubtractionFloat;

entity SquaringModule is
  Port(
    clk         : in std_logic;
    curren_int  : in integer;
    volt_int    : in integer;
    kuc_float   : in std_logic_vector(31 downto 0);
    kil_float   : in std_logic_vector(31 downto 0);
    c1_float    : in std_logic_vector(31 downto 0);
    l1_float    : in std_logic_vector(31 downto 0);
    k_float     : in std_logic_vector(31 downto 0);
    ut_float    : in std_logic_vector(31 downto 0);
    
    uc_float    : out std_logic_vector(31 downto 0);
    il_float    : out std_logic_vector(31 downto 0);
    ec1_float   : out std_logic_vector(31 downto 0);
    el1_float   : out std_logic_vector(31 downto 0);
    ecomm_float : out std_logic_vector(31 downto 0);
    igbt        : out std_logic
  );
end SquaringModule;

architecture Behavioral of SquaringModule is
  signal I_float                          : std_logic_vector(31 downto 0);
  signal U_float                          : std_logic_vector(31 downto 0);
  signal UC1_f                            : std_logic_vector(31 downto 0);
  signal IL1_f                            : std_logic_vector(31 downto 0);
  signal UC1_2_f                          : std_logic_vector(31 downto 0);
  signal IL1_2_f                          : std_logic_vector(31 downto 0);
  signal EC1_f                            : std_logic_vector(31 downto 0);
  signal EL1_f                            : std_logic_vector(31 downto 0);
  signal Ures                             : std_logic_vector(31 downto 0);
  signal Ires                             : std_logic_vector(31 downto 0);
  signal Ecomm                            : std_logic_vector(31 downto 0);
  signal Ecomm_MultDelay                  : std_logic_vector(31 downto 0);
  signal Ecomm_MultDelay_SubDelay         : std_logic_vector(31 downto 0);
  signal EcommLessEset                    : std_logic;
  signal UtSubU                           : std_logic_vector(31 downto 0);
  signal UtSubU_MultK                     : std_logic_vector(31 downto 0);
  signal UtSubU_MultK_AddUt               : std_logic_vector(31 downto 0);
  signal UtSubU_MultK_AddUt_xx2           : std_logic_vector(31 downto 0);
  signal UtSubU_MultK_AddUt_xx2_MultC     : std_logic_vector(31 downto 0);


begin
IntToFloat_Cur_inst : IntToFloat 
  PORT MAP (
    clock    => clk,
    dataa    => conv_std_logic_vector(curren_int, 32),
    result   => I_float
  );
  
IntToFloat_Volt_inst : IntToFloat 
  PORT MAP (
    clock   => clk,
    dataa   => conv_std_logic_vector(volt_int, 32),
    result  => U_float
  );

MultFloat_I_inst : MultFloat 
  PORT MAP (
    clock    => clk,
    dataa    => I_float,
    datab    => kil_float,
    result   => IL1_f
  );

MultFloat_U_inst : MultFloat 
  PORT MAP (
    clock   => clk,
    dataa   => U_float,
    datab   => kuc_float,
    result  => UC1_f
  );
  
UtSubU_inst:  ENTITY SubtractionFloat
  PORT MAP
  (
    clock   => clk,
    dataa   => ut_float,
    datab   => UC1_f,
    result  => UtSubU
  );

UtSubU_MultK_inst : MultFloat 
  PORT MAP (
    clock   => clk,
    dataa   => UtSubU,
    datab   => k_float,
    result  => UtSubU_MultK
  );

UtSubU_MultK_AddUt_inst : AddFloat 
  PORT MAP (
    clock   => clk,
    dataa   => UtSubU_MultK,
    datab   => ut_float,
    result  => UtSubU_MultK_AddUt
  );

UtSubU_MultK_AddUt_xx2_inst : MultFloat 
  PORT MAP (
    clock   => clk,
    dataa   => UtSubU_MultK_AddUt,
    datab   => UtSubU_MultK_AddUt,
    result  => UtSubU_MultK_AddUt_xx2
  );

UtSubU_MultK_AddUt_xx2_MultC_inst  : MultFloat 
  PORT MAP (
    clock   => clk,
    dataa   => c1_float,
    datab   => UtSubU_MultK_AddUt_xx2,
    result  => UtSubU_MultK_AddUt_xx2_MultC
  );

MultFloat_IL1_2_f_inst : MultFloat 
  PORT MAP (
    clock   => clk,
    dataa   => IL1_f,
    datab   => IL1_f,
    result  => IL1_2_f
  );

MultFloat_UC1_2_f_inst : MultFloat 
  PORT MAP (
    clock   => clk,
    dataa   => UC1_f,
    datab   => UC1_f,
    result  => UC1_2_f
  );

MultFloat_EL1_f_inst : MultFloat 
  PORT MAP (
    clock   => clk,
    dataa   => IL1_2_f,
    datab   => l1_float,
    result  => EL1_f
  );

MultFloat_EC1_f_inst : MultFloat 
  PORT MAP (
    clock   => clk,
    dataa   => UC1_2_f,
    datab   => c1_float,
    result  => EC1_f
  );

AddFloat_inst : AddFloat 
  PORT MAP (
    clock   => clk,
    dataa   => EC1_f,
    datab   => EL1_f,
    result  => Ecomm
  );

Ecomm_MultDelay_inst : MultFloat 
  PORT MAP (
    clock   => clk,
    dataa   => Ecomm,
    datab   => x"3f800000",
    result  => Ecomm_MultDelay
  );

Ecomm_MultDelay_SubDelay_inst : SubtractionFloat
  PORT MAP (
    clock   => clk,
    dataa   => Ecomm,
    datab   => x"00000000",
    result  => Ecomm_MultDelay_SubDelay
  );

CompareFloat  :ENTITY FloatCompare
  PORT MAP
  (
    clock   => clk,
    dataa   => Ecomm_MultDelay_SubDelay,
    datab   => UtSubU_MultK_AddUt_xx2_MultC,
    agb     => open,
    alb     => EcommLessEset
  );

igbt <= EcommLessEset;

il_float <= IL1_f;
uc_float <= UC1_f;
ec1_float <= EC1_f;
el1_float <= EL1_f;
ecomm_float <= Ecomm;

end Behavioral;