# Copyright (C) 1991-2013 Altera Corporation
# Your use of Altera Corporation's design tools, logic functions 
# and other software and tools, and its AMPP partner logic 
# functions, and any output files from any of the foregoing 
# (including device programming or simulation files), and any 
# associated documentation or information are expressly subject 
# to the terms and conditions of the Altera Program License 
# Subscription Agreement, Altera MegaCore Function License 
# Agreement, or other applicable license agreement, including, 
# without limitation, that your use is for the sole purpose of 
# programming logic devices manufactured by Altera and sold by 
# Altera or its authorized distributors.  Please refer to the 
# applicable agreement for further details.

# Quartus II: Generate Tcl File for Project
# File: version_1_00.tcl
# Generated on: Fri Feb 14 12:18:10 2020

# Load Quartus II Tcl Project package
package require ::quartus::project

set need_to_close_project 0
set make_assignments 1

# Check that the right project is open
if {[is_project_open]} {
	if {[string compare $quartus(project) "version_1_00"]} {
		puts "Project version_1_00 is not open"
		set make_assignments 0
	}
} else {
	# Only open if not already open
	if {[project_exists version_1_00]} {
		project_open -revision version_1_00 version_1_00
	} else {
		project_new -revision version_1_00 version_1_00
	}
	set need_to_close_project 1
}

# Make assignments
if {$make_assignments} {
	set_global_assignment -name FAMILY "Cyclone III"
	set_global_assignment -name DEVICE EP3C25E144C7
	set_global_assignment -name TOP_LEVEL_ENTITY QuadratorTop
	set_global_assignment -name ORIGINAL_QUARTUS_VERSION 13.1
	set_global_assignment -name PROJECT_CREATION_TIME_DATE "11:03:38  FEBRUARY 14, 2020"
	set_global_assignment -name LAST_QUARTUS_VERSION 13.1
	set_global_assignment -name PROJECT_OUTPUT_DIRECTORY output_files
	set_global_assignment -name MIN_CORE_JUNCTION_TEMP 0
	set_global_assignment -name MAX_CORE_JUNCTION_TEMP 85
	set_global_assignment -name ERROR_CHECK_FREQUENCY_DIVISOR 1
	set_global_assignment -name NOMINAL_CORE_SUPPLY_VOLTAGE 1.2V
	set_global_assignment -name EDA_DESIGN_ENTRY_SYNTHESIS_TOOL "Precision Synthesis"
	set_global_assignment -name EDA_LMF_FILE mentor.lmf -section_id eda_design_synthesis
	set_global_assignment -name EDA_INPUT_DATA_FORMAT EDIF -section_id eda_design_synthesis
	set_global_assignment -name EDA_SIMULATION_TOOL "ModelSim-Altera (VHDL)"
	set_global_assignment -name EDA_OUTPUT_DATA_FORMAT VHDL -section_id eda_simulation
	set_global_assignment -name VHDL_FILE QuadratorTop.vhd
	set_global_assignment -name PARTITION_NETLIST_TYPE SOURCE -section_id Top
	set_global_assignment -name PARTITION_FITTER_PRESERVATION_LEVEL PLACEMENT_AND_ROUTING -section_id Top
	set_global_assignment -name PARTITION_COLOR 16764057 -section_id Top
	set_global_assignment -name STRATIX_DEVICE_IO_STANDARD "2.5 V"
	set_global_assignment -name QIP_FILE ClockGenerator.qip
	set_location_assignment PIN_91 -to adc_clkout_n
	set_location_assignment PIN_90 -to adc_clkout_p
	set_location_assignment PIN_105 -to adc_cs
	set_location_assignment PIN_49 -to adc_d1[13]
	set_location_assignment PIN_50 -to adc_d1[12]
	set_location_assignment PIN_51 -to adc_d1[11]
	set_location_assignment PIN_58 -to adc_d1[10]
	set_location_assignment PIN_59 -to adc_d1[9]
	set_location_assignment PIN_60 -to adc_d1[8]
	set_location_assignment PIN_64 -to adc_d1[7]
	set_location_assignment PIN_65 -to adc_d1[6]
	set_location_assignment PIN_66 -to adc_d1[5]
	set_location_assignment PIN_67 -to adc_d1[4]
	set_location_assignment PIN_68 -to adc_d1[3]
	set_location_assignment PIN_69 -to adc_d1[2]
	set_location_assignment PIN_71 -to adc_d1[1]
	set_location_assignment PIN_72 -to adc_d1[0]
	set_location_assignment PIN_110 -to adc_d2[13]
	set_location_assignment PIN_111 -to adc_d2[12]
	set_location_assignment PIN_112 -to adc_d2[11]
	set_location_assignment PIN_113 -to adc_d2[10]
	set_location_assignment PIN_114 -to adc_d2[9]
	set_location_assignment PIN_115 -to adc_d2[8]
	set_location_assignment PIN_119 -to adc_d2[7]
	set_location_assignment PIN_120 -to adc_d2[6]
	set_location_assignment PIN_121 -to adc_d2[5]
	set_location_assignment PIN_125 -to adc_d2[4]
	set_location_assignment PIN_132 -to adc_d2[3]
	set_location_assignment PIN_133 -to adc_d2[2]
	set_location_assignment PIN_135 -to adc_d2[1]
	set_location_assignment PIN_136 -to adc_d2[0]
	set_location_assignment PIN_87 -to adc_enc_n
	set_location_assignment PIN_86 -to adc_enc_p
	set_location_assignment PIN_46 -to adc_of[1]
	set_location_assignment PIN_44 -to adc_of[0]
	set_location_assignment PIN_22 -to clk50MHz
	set_location_assignment PIN_106 -to dac_cs
	set_location_assignment PIN_99 -to gtp[3]
	set_location_assignment PIN_28 -to gtp[2]
	set_location_assignment PIN_83 -to gtp[1]
	set_location_assignment PIN_85 -to gtp[0]
	set_location_assignment PIN_137 -to reset_n
	set_location_assignment PIN_7 -to rtp[3]
	set_location_assignment PIN_4 -to rtp[2]
	set_location_assignment PIN_79 -to rtp[1]
	set_location_assignment PIN_80 -to rtp[0]
	set_location_assignment PIN_77 -to rxd_1
	set_location_assignment PIN_100 -to spi_miso
	set_location_assignment PIN_103 -to spi_mosi
	set_location_assignment PIN_104 -to spi_sck
	set_location_assignment PIN_10 -to sync_out_vec[2]
	set_location_assignment PIN_11 -to sync_in_vec[2]
	set_location_assignment PIN_33 -to sync_in_vec[1]
	set_location_assignment PIN_32 -to sync_out_vec[1]
	set_location_assignment PIN_144 -to sync_in_vec[0]
	set_location_assignment PIN_143 -to sync_out_vec[0]
	set_location_assignment PIN_76 -to txd_1
	set_location_assignment PIN_30 -to uart_rx
	set_location_assignment PIN_31 -to uart_tx
	set_instance_assignment -name IO_STANDARD "2.5 V" -to uart_rx
	set_instance_assignment -name IO_STANDARD "2.5 V" -to uart_tx
	set_instance_assignment -name IO_STANDARD "2.5 V" -to txd_1
	set_instance_assignment -name IO_STANDARD "2.5 V" -to rxd_1
	set_instance_assignment -name PARTITION_HIERARCHY root_partition -to | -section_id Top

	# Commit assignments
	export_assignments

	# Close project
	if {$need_to_close_project} {
		project_close
	}
}
