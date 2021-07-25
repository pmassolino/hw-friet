# read all source files
set verilog_sources_file [open $::env(SYNTH_VERILOG_FILES_FOLDER)/source_list.txt r]
while { [gets $verilog_sources_file line] >= 0 } {
    yosys read_verilog -I$::env(SYNTH_VERILOG_FILES_FOLDER) $::env(SYNTH_VERILOG_FILES_FOLDER)/$line
}
# Change the parameters that have been setted
set temp_i 0
while { $temp_i < $::env(SYNTH_VERILOG_TOP_NUMBER_PARAMETERS) } {
    set parameter_name SYNTH_VERILOG_TOP_PARAMETER_NAME_$temp_i
    set parameter_value SYNTH_VERILOG_TOP_PARAMETER_VALUE_$temp_i
    yosys chparam -set $::env($parameter_name) $::env($parameter_value) "$::env(SYNTH_TOP_UNIT_NAME)"
    incr temp_i 1
}
# Check, expand and clean up design hierarchy
yosys hierarchy -check -top "$::env(SYNTH_TOP_UNIT_NAME)"
#
# Begin translation process and coarse optimizations
#
# Convert high-level behavioral parts ("processes") to d-type flip-flops and muxes
yosys proc
# Flatten design
yosys flatten
# Perform const folding and simple expression rewriting
yosys opt_expr
# Remove unused cells and wires
yosys opt_clean
# Check for obvious problems in the design
yosys check
# Perform simple optimizations
yosys opt
# Reduce the word size of operations if possible
yosys wreduce
# Extract ALU and MACC cells
yosys alumacc
# perform sat-based resource sharing
yosys share
# Perform simple optimizations
yosys opt
# extract and optimize finite state machines
yosys fsm
# Perform simple optimizations
yosys opt -fast
# Translate memories to basic cells
yosys memory -nomap
# Remove unused cells and wires
yosys opt_clean
#
# More fine optimizations
#
# Perform simple optimizations
yosys opt -fast -full
# Translate multiport memories to basic cells
yosys memory_map
# Perform simple optimizations
yosys opt -full
# Generic technology mapper
yosys techmap
# Perform simple optimizations
yosys opt
# Use ABC for technology mapping
yosys abc -g AND, OR, XOR
#
yosys opt_clean
# Print some statistics
yosys stat -top $::env(SYNTH_TOP_UNIT_NAME)
#
yosys write_verilog [expr {"$::env(SYNTH_OUTPUT_CIRCUIT_FOLDER)/$::env(SYNTH_OUTPUT_CIRCUIT_FILENAME).v"}]