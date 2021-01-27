.PHONY: clean

ICARUS_VERILOG_SIMULATOR=iverilog
ICARUS_VERILOG_VVP=vvp
ICARUS_VERILOG_DUMP_TYPE=fst

VERILOG_SOURCE_FOLDER=../verilog_source

FRIET_PC_ROUNDS_SIMPLE_SOURCE=\
	$(VERILOG_SOURCE_FOLDER)/friet_pc_round.v\
	$(VERILOG_SOURCE_FOLDER)/friet_p_rc.v\
	$(VERILOG_SOURCE_FOLDER)/friet_pc_rounds_simple.v

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

TB_FRIET_PC_ROUNDS_SIMPLE_SOURCE=\
	$(FRIET_PC_ROUNDS_SIMPLE_SOURCE)\
	$(VERILOG_SOURCE_FOLDER)/tb_friet_pc_rounds_simple.v

TB_FRIET_LWC_SOURCE=\
	$(GIMLI_LWC_SOURCE)\
	$(VERILOG_SOURCE_FOLDER)/tb_friet_lwc.v

tb_friet_pc_rounds_simple: $(TB_FRIET_PC_ROUNDS_SIMPLE_SOURCE)
	IVERILOG_DUMPER="$(ICARUS_VERILOG_DUMP_TYPE)" $(ICARUS_VERILOG_SIMULATOR) -s $@ -o $@_design $(TB_FRIET_PC_ROUNDS_SIMPLE_SOURCE)
	$(ICARUS_VERILOG_VVP) $@_design -$(ICARUS_VERILOG_DUMP_TYPE)

tb_gimli_lwc: $(TB_FRIET_LWC_SOURCE)
	IVERILOG_DUMPER="$(ICARUS_VERILOG_DUMP_TYPE)" $(ICARUS_VERILOG_SIMULATOR) -s $@ -o $@_design $(TB_FRIET_LWC_SOURCE)
	$(ICARUS_VERILOG_VVP) $@_design -$(ICARUS_VERILOG_DUMP_TYPE)

clean:
	@echo "Cleaning up..."
	rm -f "dump"
	rm -f "tb_friet_pc_rounds_simple_dump"
	rm -f "tb_friet_pc_rounds_simple_design"
	rm -f "tb_friet_pc_lwc_design"
	@echo "Cleaning done."