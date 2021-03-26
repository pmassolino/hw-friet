.PHONY: clean

ICARUS_VERILOG_SIMULATOR=iverilog
ICARUS_VERILOG_VVP=vvp
ICARUS_VERILOG_DUMP_TYPE=fst

VERILOG_SOURCE_FOLDER=../verilog_source

FRIET_PC_ROUNDS_SIMPLE_SOURCE=\
	$(VERILOG_SOURCE_FOLDER)/friet_p_rc.v\
	$(VERILOG_SOURCE_FOLDER)/friet_pc_round.v\
	$(VERILOG_SOURCE_FOLDER)/friet_pc_rounds_simple.v

FRIET_P_ROUNDS_SIMPLE_FPGA_LUT4_SOURCE=\
	$(VERILOG_SOURCE_FOLDER)/friet_p_rc.v\
	$(VERILOG_SOURCE_FOLDER)/friet_p_round_fpga_lut4.v\
	$(VERILOG_SOURCE_FOLDER)/friet_p_rounds_simple_fpga_lut4.v

FRIET_P_ROUNDS_SIMPLE_FPGA_LUT6_SOURCE=\
	$(VERILOG_SOURCE_FOLDER)/friet_p_rc.v\
	$(VERILOG_SOURCE_FOLDER)/friet_p_round_fpga_lut6.v\
	$(VERILOG_SOURCE_FOLDER)/friet_p_rounds_simple_fpga_lut6.v

FRIET_P_ROUNDS_SIMPLE_ASIC_SOURCE=\
	$(VERILOG_SOURCE_FOLDER)/friet_p_xaon_gate.v\
	$(VERILOG_SOURCE_FOLDER)/friet_p_rc.v\
	$(VERILOG_SOURCE_FOLDER)/friet_p_round_asic.v\
	$(VERILOG_SOURCE_FOLDER)/friet_p_rounds_simple_asic.v

FRIET_C_STREAM_SOURCE=\
	$(FRIET_PC_ROUNDS_SIMPLE_SOURCE)\
	$(VERILOG_SOURCE_FOLDER)/friet_c_stream_buffer_in.v\
	$(VERILOG_SOURCE_FOLDER)/friet_c_stream_buffer_out.v\
	$(VERILOG_SOURCE_FOLDER)/friet_c_stream_state_machine.v\
	$(VERILOG_SOURCE_FOLDER)/friet_c_stream.v

FRIET_C_LWC_SOURCE=\
	$(FRIET_C_STREAM_SOURCE)\
	$(VERILOG_SOURCE_FOLDER)/friet_c_lwc_buffer_in.v\
	$(VERILOG_SOURCE_FOLDER)/friet_c_lwc_buffer_out.v\
	$(VERILOG_SOURCE_FOLDER)/friet_c_lwc_state_machine.v\
	$(VERILOG_SOURCE_FOLDER)/friet_c_lwc.v

FRIET_STREAM_FPGA_LUT4_SOURCE=\
	$(FRIET_P_ROUNDS_SIMPLE_FPGA_LUT4_SOURCE)\
	$(VERILOG_SOURCE_FOLDER)/friet_stream_buffer_in.v\
	$(VERILOG_SOURCE_FOLDER)/friet_stream_buffer_out.v\
	$(VERILOG_SOURCE_FOLDER)/friet_stream_state_machine.v\
	$(VERILOG_SOURCE_FOLDER)/friet_stream_fpga_lut4.v

FRIET_LWC_FPGA_LUT4_SOURCE=\
	$(FRIET_STREAM_FPGA_LUT4_SOURCE)\
	$(VERILOG_SOURCE_FOLDER)/friet_lwc_buffer_in.v\
	$(VERILOG_SOURCE_FOLDER)/friet_lwc_buffer_out.v\
	$(VERILOG_SOURCE_FOLDER)/friet_lwc_state_machine.v\
	$(VERILOG_SOURCE_FOLDER)/friet_lwc_fpga_lut4.v

FRIET_STREAM_FPGA_LUT6_SOURCE=\
	$(FRIET_P_ROUNDS_SIMPLE_FPGA_LUT6_SOURCE)\
	$(VERILOG_SOURCE_FOLDER)/friet_stream_buffer_in.v\
	$(VERILOG_SOURCE_FOLDER)/friet_stream_buffer_out.v\
	$(VERILOG_SOURCE_FOLDER)/friet_stream_state_machine.v\
	$(VERILOG_SOURCE_FOLDER)/friet_stream_fpga_lut6.v

FRIET_LWC_FPGA_LUT6_SOURCE=\
	$(FRIET_STREAM_FPGA_LUT6_SOURCE)\
	$(VERILOG_SOURCE_FOLDER)/friet_lwc_buffer_in.v\
	$(VERILOG_SOURCE_FOLDER)/friet_lwc_buffer_out.v\
	$(VERILOG_SOURCE_FOLDER)/friet_lwc_state_machine.v\
	$(VERILOG_SOURCE_FOLDER)/friet_lwc_fpga_lut6.v

FRIET_STREAM_ASIC_SOURCE=\
	$(FRIET_P_ROUNDS_SIMPLE_FPGA_LUT4_SOURCE)\
	$(VERILOG_SOURCE_FOLDER)/friet_stream_buffer_in.v\
	$(VERILOG_SOURCE_FOLDER)/friet_stream_buffer_out.v\
	$(VERILOG_SOURCE_FOLDER)/friet_stream_state_machine.v\
	$(VERILOG_SOURCE_FOLDER)/friet_stream_asic.v

FRIET_LWC_ASIC_SOURCE=\
	$(FRIET_STREAM_ASIC_SOURCE)\
	$(VERILOG_SOURCE_FOLDER)/friet_lwc_buffer_in.v\
	$(VERILOG_SOURCE_FOLDER)/friet_lwc_buffer_out.v\
	$(VERILOG_SOURCE_FOLDER)/friet_lwc_state_machine.v\
	$(VERILOG_SOURCE_FOLDER)/friet_lwc_asic.v

TB_FRIET_PC_ROUNDS_SIMPLE_SOURCE=\
	$(FRIET_PC_ROUNDS_SIMPLE_SOURCE)\
	$(VERILOG_SOURCE_FOLDER)/tb_friet_pc_rounds_simple.v

TB_FRIET_P_ROUNDS_SIMPLE_FPGA_LUT4_SOURCE=\
	$(FRIET_P_ROUNDS_SIMPLE_FPGA_LUT4_SOURCE)\
	$(VERILOG_SOURCE_FOLDER)/tb_friet_p_rounds_simple_fpga_lut4.v

TB_FRIET_P_ROUNDS_SIMPLE_FPGA_LUT6_SOURCE=\
	$(FRIET_P_ROUNDS_SIMPLE_FPGA_LUT6_SOURCE)\
	$(VERILOG_SOURCE_FOLDER)/tb_friet_p_rounds_simple_fpga_lut6.v

TB_FRIET_P_ROUNDS_SIMPLE_ASIC_SOURCE=\
	$(FRIET_P_ROUNDS_SIMPLE_ASIC_SOURCE)\
	$(VERILOG_SOURCE_FOLDER)/tb_friet_p_rounds_simple_asic.v

TB_FRIET_C_LWC_SOURCE=\
	$(FRIET_C_LWC_SOURCE)\
	$(VERILOG_SOURCE_FOLDER)/tb_friet_c_lwc.v

TB_FRIET_LWC_FPGA_LUT4_SOURCE=\
	$(FRIET_LWC_FPGA_LUT4_SOURCE)\
	$(VERILOG_SOURCE_FOLDER)/tb_friet_lwc_fpga_lut4.v

TB_FRIET_LWC_FPGA_LUT6_SOURCE=\
	$(FRIET_LWC_FPGA_LUT6_SOURCE)\
	$(VERILOG_SOURCE_FOLDER)/tb_friet_lwc_fpga_lut6.v

TB_FRIET_LWC_ASIC_SOURCE=\
	$(FRIET_LWC_ASIC_SOURCE)\
	$(VERILOG_SOURCE_FOLDER)/tb_friet_lwc_asic.v

tb_friet_pc_rounds_simple: $(TB_FRIET_PC_ROUNDS_SIMPLE_SOURCE)
	IVERILOG_DUMPER="$(ICARUS_VERILOG_DUMP_TYPE)" $(ICARUS_VERILOG_SIMULATOR) -s $@ -o $@_design $(TB_FRIET_PC_ROUNDS_SIMPLE_SOURCE)
	$(ICARUS_VERILOG_VVP) $@_design -$(ICARUS_VERILOG_DUMP_TYPE)

tb_friet_p_rounds_simple_fpga_lut4: $(TB_FRIET_P_ROUNDS_SIMPLE_FPGA_LUT4_SOURCE)
	IVERILOG_DUMPER="$(ICARUS_VERILOG_DUMP_TYPE)" $(ICARUS_VERILOG_SIMULATOR) -s $@ -o $@_design $(TB_FRIET_P_ROUNDS_SIMPLE_FPGA_LUT4_SOURCE)
	$(ICARUS_VERILOG_VVP) $@_design -$(ICARUS_VERILOG_DUMP_TYPE)

tb_friet_p_rounds_simple_fpga_lut6: $(TB_FRIET_P_ROUNDS_SIMPLE_FPGA_LUT6_SOURCE)
	IVERILOG_DUMPER="$(ICARUS_VERILOG_DUMP_TYPE)" $(ICARUS_VERILOG_SIMULATOR) -s $@ -o $@_design $(TB_FRIET_P_ROUNDS_SIMPLE_FPGA_LUT6_SOURCE)
	$(ICARUS_VERILOG_VVP) $@_design -$(ICARUS_VERILOG_DUMP_TYPE)

tb_friet_p_rounds_simple_asic: $(TB_FRIET_P_ROUNDS_SIMPLE_ASIC_SOURCE)
	IVERILOG_DUMPER="$(ICARUS_VERILOG_DUMP_TYPE)" $(ICARUS_VERILOG_SIMULATOR) -s $@ -o $@_design $(TB_FRIET_P_ROUNDS_SIMPLE_ASIC_SOURCE)
	$(ICARUS_VERILOG_VVP) $@_design -$(ICARUS_VERILOG_DUMP_TYPE)

tb_friet_c_lwc: $(TB_FRIET_C_LWC_SOURCE)
	IVERILOG_DUMPER="$(ICARUS_VERILOG_DUMP_TYPE)" $(ICARUS_VERILOG_SIMULATOR) -s $@ -o $@_design $(TB_FRIET_C_LWC_SOURCE)
	$(ICARUS_VERILOG_VVP) $@_design -$(ICARUS_VERILOG_DUMP_TYPE)

tb_friet_lwc_fpga_lut4: $(TB_FRIET_LWC_FPGA_LUT4_SOURCE)
	IVERILOG_DUMPER="$(ICARUS_VERILOG_DUMP_TYPE)" $(ICARUS_VERILOG_SIMULATOR) -s $@ -o $@_design $(TB_FRIET_LWC_FPGA_LUT4_SOURCE)
	$(ICARUS_VERILOG_VVP) $@_design -$(ICARUS_VERILOG_DUMP_TYPE)

tb_friet_lwc_fpga_lut6: $(TB_FRIET_LWC_FPGA_LUT6_SOURCE)
	IVERILOG_DUMPER="$(ICARUS_VERILOG_DUMP_TYPE)" $(ICARUS_VERILOG_SIMULATOR) -s $@ -o $@_design $(TB_FRIET_LWC_FPGA_LUT6_SOURCE)
	$(ICARUS_VERILOG_VVP) $@_design -$(ICARUS_VERILOG_DUMP_TYPE)

tb_friet_lwc_asic: $(TB_FRIET_LWC_ASIC_SOURCE)
	IVERILOG_DUMPER="$(ICARUS_VERILOG_DUMP_TYPE)" $(ICARUS_VERILOG_SIMULATOR) -s $@ -o $@_design $(TB_FRIET_LWC_ASIC_SOURCE)
	$(ICARUS_VERILOG_VVP) $@_design -$(ICARUS_VERILOG_DUMP_TYPE)

clean:
	@echo "Cleaning up..."
	rm -f "dump"
	rm -f "tb_friet_pc_rounds_simple_dump"
	rm -f "tb_friet_pc_rounds_simple_design"
	rm -f "tb_friet_p_rounds_simple_fpga_lut4_dump"
	rm -f "tb_friet_p_rounds_simple_fpga_lut4_design"
	rm -f "tb_friet_p_rounds_simple_fpga_lut6_dump"
	rm -f "tb_friet_p_rounds_simple_fpga_lut6_design"
	rm -f "tb_friet_p_rounds_simple_asic_dump"
	rm -f "tb_friet_p_rounds_simple_asic_design"
	rm -f "tb_friet_c_lwc_dump"
	rm -f "tb_friet_c_lwc_design"
	rm -f "tb_friet_lwc_fpga_lut4_dump"
	rm -f "tb_friet_lwc_fpga_lut4_design"
	rm -f "tb_friet_lwc_fpga_lut6_dump"
	rm -f "tb_friet_lwc_fpga_lut6_design"
	rm -f "tb_friet_lwc_asic_dump"
	rm -f "tb_friet_lwc_asic_design"
	@echo "Cleaning done."