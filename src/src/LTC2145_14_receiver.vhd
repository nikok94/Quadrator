--------------------------------------------------------------------------------
--
--   FileName:         LTC2145_14_receiver.vhd
--   Dependencies:     none
--   Design Software:  Quartus II Version 9.0 Build 132 SJ Full Version
--
--   HDL CODE IS PROVIDED "AS IS."  DIGI-KEY EXPRESSLY DISCLAIMS ANY
--   WARRANTY OF ANY KIND, WHETHER EXPRESS OR IMPLIED, INCLUDING BUT NOT
--   LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A
--   PARTICULAR PURPOSE, OR NON-INFRINGEMENT. IN NO EVENT SHALL DIGI-KEY
--   BE LIABLE FOR ANY INCIDENTAL, SPECIAL, INDIRECT OR CONSEQUENTIAL
--   DAMAGES, LOST PROFITS OR LOST DATA, HARM TO YOUR EQUIPMENT, COST OF
--   PROCUREMENT OF SUBSTITUTE GOODS, TECHNOLOGY OR SERVICES, ANY CLAIMS
--   BY THIRD PARTIES (INCLUDING BUT NOT LIMITED TO ANY DEFENSE THEREOF),
--   ANY CLAIMS FOR INDEMNITY OR CONTRIBUTION, OR OTHER SIMILAR COSTS.
--
--   Version History
--   Version 1.0 7/23/2010 Scott Larson
--     Initial Public Release
--   Version 1.1 4/11/2013 Scott Larson
--     Corrected ModelSim simulation error (explicitly reset clk_toggles signal)
--    
--------------------------------------------------------------------------------

LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.std_logic_arith.all;
USE ieee.std_logic_unsigned.all;

library work;
use work.ddr_receiver;
use work.altddio_ia;



ENTITY LTC2145_14_receiver IS
  GENERIC(
    ddr_mode    : boolean := true
    );
  PORT(
    rst             : in std_logic;
    ltc_clk         : in std_logic;
    ltc_d0          : in std_logic_vector(13 downto 0);
    ltc_d1          : in std_logic_vector(13 downto 0);
    ltc_of          : in std_logic_vector(1 downto 0);
    data0           : out std_logic_vector(13 downto 0);
    overflow0       : out std_logic;
    data1           : out std_logic_vector(13 downto 0);
    overflow1       : out std_logic;
    clk             : out std_logic
  );
END LTC2145_14_receiver;

ARCHITECTURE logic OF LTC2145_14_receiver IS
  signal o_f        : std_logic_vector(1 downto 0);

BEGIN

ddr_mode_true_gen : if ddr_mode = true generate

  gen_for :  for i in ltc_d0'length/2 - 1 downto 0 generate

  ddr0_inst : entity altddio_ia
    PORT MAP
    (
        aclr           => rst,
        datain(0)      => ltc_d0(i*2 + 1),
        inclock        => ltc_clk,
        dataout_h(0)   => data0(i*2 + 1),
        dataout_l(0)   => data0(i*2)
    );

  ddr1_inst : entity altddio_ia
    PORT MAP
    (
        aclr           => rst,
        datain(0)      => ltc_d1(i*2 + 1),
        inclock        => ltc_clk,
        dataout_h(0)   => data1(i*2 + 1),
        dataout_l(0)   => data1(i*2)
    );
  end generate gen_for;

    ddr_of_inst : entity altddio_ia
    PORT MAP
    (
        aclr           => rst,
        datain(0)      => ltc_of(0),
        inclock        => ltc_clk,
        dataout_h(0)   => o_f(1),
        dataout_l(0)   => o_f(0)
    );
    clk <= ltc_clk;
    overflow1 <= o_f(0);
    overflow0 <= o_f(1);
end  generate ddr_mode_true_gen;

ddr_mode_false_gen : if ddr_mode /= true generate
    data0 <= ltc_d0;
    data1 <= ltc_d1;
    overflow1 <= ltc_of(1);
    overflow0 <= ltc_of(0);
    clk <= ltc_clk;
end  generate;

END logic;
