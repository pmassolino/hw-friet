.PHONY: clean

# Empty (no trace)
# FST - Enables FST
# Otherwise anyhting will enable VCD
DUMP_TRACE_FORMAT=FST

VERILATOR=verilator
VERILATOR_FLAGS=--cc
VERILATOR_FLAGS+=-Wall
VERILATOR_FLAGS+=-Wno-UNUSED

VERILATOR_CPP=g++
VERILATOR_CPP_WARNINGS=-Wparentheses
VERILATOR_CPP_INCLUDE_FOLDER=/usr/local/share/verilator/include
VERILATOR_CPP_SOURCE_FILES_FINAL_COMPILATION=$(VERILATOR_CPP_INCLUDE_FOLDER)/verilated.cpp

VERILATOR_CPP_DEFINES=
VERILATOR_CPP_LINK_OPTIONS=

ifdef DUMP_TRACE_FORMAT
ifeq ($(DUMP_TRACE_FORMAT), FST)
VERILATOR_FLAGS+=--trace-fst
VERILATOR_CPP_SOURCE_FILES_FINAL_COMPILATION+=$(VERILATOR_CPP_INCLUDE_FOLDER)/verilated_fst_c.cpp
VERILATOR_CPP_DEFINES+=-DDUMP_TRACE_ON -DDUMP_TRACE_FST
VERILATOR_CPP_LINK_OPTIONS+=-lz
else
VERILATOR_FLAGS+=--trace
VERILATOR_CPP_SOURCE_FILES_FINAL_COMPILATION+=$(VERILATOR_CPP_INCLUDE_FOLDER)/verilated_vcd_c.cpp
VERILATOR_CPP_DEFINES+=-DDUMP_TRACE_ON
endif
endif

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

FRIET_P_ROUNDS_SIMPLE_FPGA_LUT4_SOURCE=\
	$(VERILOG_SOURCE_FOLDER)/friet_p_rc.v\
	$(VERILOG_SOURCE_FOLDER)/friet_p_round_fpga_lut4.v\
	$(VERILOG_SOURCE_FOLDER)/friet_p_rounds_simple_fpga_lut4.v

FRIET_P_ROUNDS_SIMPLE_FPGA_LUT6_SOURCE=\
	$(VERILOG_SOURCE_FOLDER)/friet_p_rc.v\
	$(VERILOG_SOURCE_FOLDER)/friet_p_round_fpga_lut6.v\
	$(VERILOG_SOURCE_FOLDER)/friet_p_rounds_simple_fpga_lut6.v

FRIET_STREAM_FPGA_LUT4_SOURCE=\
	$(FRIET_P_ROUNDS_SIMPLE_FPGA_LUT4_SOURCE)\
	$(VERILOG_SOURCE_FOLDER)/friet_stream_buffer_in.v\
	$(VERILOG_SOURCE_FOLDER)/friet_stream_buffer_out.v\
	$(VERILOG_SOURCE_FOLDER)/friet_stream_state_machine.v\
	$(VERILOG_SOURCE_FOLDER)/friet_stream_fpga_lut4.v

FRIET_STREAM_FPGA_LUT6_SOURCE=\
	$(FRIET_P_ROUNDS_SIMPLE_FPGA_LUT6_SOURCE)\
	$(VERILOG_SOURCE_FOLDER)/friet_stream_buffer_in.v\
	$(VERILOG_SOURCE_FOLDER)/friet_stream_buffer_out.v\
	$(VERILOG_SOURCE_FOLDER)/friet_stream_state_machine.v\
	$(VERILOG_SOURCE_FOLDER)/friet_stream_fpga_lut6.v

FRIET_LWC_FPGA_LUT4_SOURCE=\
	$(FRIET_STREAM_FPGA_LUT4_SOURCE)\
	$(VERILOG_SOURCE_FOLDER)/friet_lwc_buffer_in.v\
	$(VERILOG_SOURCE_FOLDER)/friet_lwc_buffer_out.v\
	$(VERILOG_SOURCE_FOLDER)/friet_lwc_state_machine.v\
	$(VERILOG_SOURCE_FOLDER)/friet_lwc_fpga_lut4.v

FRIET_LWC_FPGA_LUT6_SOURCE=\
	$(FRIET_STREAM_FPGA_LUT6_SOURCE)\
	$(VERILOG_SOURCE_FOLDER)/friet_lwc_buffer_in.v\
	$(VERILOG_SOURCE_FOLDER)/friet_lwc_buffer_out.v\
	$(VERILOG_SOURCE_FOLDER)/friet_lwc_state_machine.v\
	$(VERILOG_SOURCE_FOLDER)/friet_lwc_fpga_lut6.v

FRIET_P_ROUNDS_SIMPLE_ASIC_SOURCE=\
	$(VERILOG_SOURCE_FOLDER)/friet_p_xaon_gate.v\
	$(VERILOG_SOURCE_FOLDER)/friet_p_rc.v\
	$(VERILOG_SOURCE_FOLDER)/friet_p_round_asic.v\
	$(VERILOG_SOURCE_FOLDER)/friet_p_rounds_simple_asic.v

FRIET_STREAM_ASIC_SOURCE=\
	$(FRIET_P_ROUNDS_SIMPLE_ASIC_SOURCE)\
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

tb_friet_c_stream_kat: $(FRIET_C_STREAM_SOURCE) tb_friet_c_stream.cpp
	$(VERILATOR) $(VERILATOR_FLAGS) -GKEY_AE_TAG_SIZE_LENGTH=1 -GKEY_TAG_SIZE="1'd0" -GAE_TAG_SIZE="1'd0" --top-module friet_c_stream $(FRIET_C_STREAM_SOURCE) tb_friet_c_stream.cpp
	make -C obj_dir -f Vfriet_c_stream.mk
	@echo "Building a Verilator-based simulation for tb_friet_c_stream"
	$(VERILATOR_CPP) $(VERILATOR_CPP_WARNINGS) $(VERILATOR_CPP_DEFINES) -DG_SKIP_KAT_AEAD_TEST=0 -DG_SKIP_INT_AEAD_TEST=1 -I $(VERILATOR_CPP_INCLUDE_FOLDER) -I obj_dir \
		$(VERILATOR_CPP_SOURCE_FILES_FINAL_COMPILATION)\
		tb_friet_c_stream.cpp $(VERILATOR_CPP_LINK_OPTIONS) obj_dir/Vfriet_c_stream__ALL.a \
		-o tb_friet_c_stream

tb_friet_c_stream_int: $(FRIET_C_STREAM_SOURCE) tb_friet_c_stream.cpp
	$(VERILATOR) $(VERILATOR_FLAGS) -GKEY_AE_TAG_SIZE_LENGTH=2 -GKEY_TAG_SIZE="2'd2" -GAE_TAG_SIZE="2'd2" --top-module friet_c_stream $(FRIET_C_STREAM_SOURCE) tb_friet_c_stream.cpp
	make -C obj_dir -f Vfriet_c_stream.mk
	@echo "Building a Verilator-based simulation for tb_friet_c_stream"
	$(VERILATOR_CPP) $(VERILATOR_CPP_WARNINGS) $(VERILATOR_CPP_DEFINES) -DG_SKIP_KAT_AEAD_TEST=1 -DG_SKIP_INT_AEAD_TEST=0 -I $(VERILATOR_CPP_INCLUDE_FOLDER) -I obj_dir \
		$(VERILATOR_CPP_SOURCE_FILES_FINAL_COMPILATION)\
		tb_friet_c_stream.cpp $(VERILATOR_CPP_LINK_OPTIONS) obj_dir/Vfriet_c_stream__ALL.a \
		-o tb_friet_c_stream

tb_friet_c_lwc: $(FRIET_C_LWC_SOURCE) tb_friet_c_lwc.cpp
	$(VERILATOR) $(VERILATOR_FLAGS) --top-module friet_c_lwc $(FRIET_C_LWC_SOURCE) tb_friet_c_lwc.cpp
	make -C obj_dir -f Vfriet_c_lwc.mk
	@echo "Building a Verilator-based simulation for $(@)"
	$(VERILATOR_CPP) $(VERILATOR_CPP_WARNINGS) $(VERILATOR_CPP_DEFINES) -I $(VERILATOR_CPP_INCLUDE_FOLDER) -I obj_dir \
		$(VERILATOR_CPP_SOURCE_FILES_FINAL_COMPILATION)\
		$(@).cpp $(VERILATOR_CPP_LINK_OPTIONS) obj_dir/Vfriet_c_lwc__ALL.a \
		-o $(@)

tb_friet_c_lwc_1: $(FRIET_C_LWC_SOURCE) tb_friet_c_lwc.cpp
	$(VERILATOR) $(VERILATOR_FLAGS) --top-module friet_c_lwc -GCOMBINATIONAL_ROUNDS=1 $(FRIET_C_LWC_SOURCE) tb_friet_c_lwc.cpp
	make -C obj_dir -f Vfriet_c_lwc.mk
	@echo "Building a Verilator-based simulation for tb_friet_c_lwc"
	$(VERILATOR_CPP) $(VERILATOR_CPP_WARNINGS) $(VERILATOR_CPP_DEFINES) -I $(VERILATOR_CPP_INCLUDE_FOLDER) -I obj_dir \
		$(VERILATOR_CPP_SOURCE_FILES_FINAL_COMPILATION)\
		tb_friet_c_lwc.cpp $(VERILATOR_CPP_LINK_OPTIONS) obj_dir/Vfriet_c_lwc__ALL.a \
		-o tb_friet_c_lwc

tb_friet_c_lwc_2: $(FRIET_C_LWC_SOURCE) tb_friet_c_lwc.cpp
	$(VERILATOR) $(VERILATOR_FLAGS) --top-module friet_c_lwc -GCOMBINATIONAL_ROUNDS=2 $(FRIET_C_LWC_SOURCE) tb_friet_c_lwc.cpp
	make -C obj_dir -f Vfriet_c_lwc.mk
	@echo "Building a Verilator-based simulation for tb_friet_c_lwc"
	$(VERILATOR_CPP) $(VERILATOR_CPP_WARNINGS) $(VERILATOR_CPP_DEFINES) -I $(VERILATOR_CPP_INCLUDE_FOLDER) -I obj_dir \
		$(VERILATOR_CPP_SOURCE_FILES_FINAL_COMPILATION)\
		tb_friet_c_lwc.cpp $(VERILATOR_CPP_LINK_OPTIONS) obj_dir/Vfriet_c_lwc__ALL.a \
		-o tb_friet_c_lwc

tb_friet_c_lwc_3: $(FRIET_C_LWC_SOURCE) tb_friet_c_lwc.cpp
	$(VERILATOR) $(VERILATOR_FLAGS) --top-module friet_c_lwc -GCOMBINATIONAL_ROUNDS=3 $(FRIET_C_LWC_SOURCE) tb_friet_c_lwc.cpp
	make -C obj_dir -f Vfriet_c_lwc.mk
	@echo "Building a Verilator-based simulation for tb_friet_c_lwc"
	$(VERILATOR_CPP) $(VERILATOR_CPP_WARNINGS) $(VERILATOR_CPP_DEFINES) -I $(VERILATOR_CPP_INCLUDE_FOLDER) -I obj_dir \
		$(VERILATOR_CPP_SOURCE_FILES_FINAL_COMPILATION)\
		tb_friet_c_lwc.cpp $(VERILATOR_CPP_LINK_OPTIONS) obj_dir/Vfriet_c_lwc__ALL.a \
		-o tb_friet_c_lwc

tb_friet_c_lwc_4: $(FRIET_C_LWC_SOURCE) tb_friet_c_lwc.cpp
	$(VERILATOR) $(VERILATOR_FLAGS) --top-module friet_c_lwc -GCOMBINATIONAL_ROUNDS=4 $(FRIET_C_LWC_SOURCE) tb_friet_c_lwc.cpp
	make -C obj_dir -f Vfriet_c_lwc.mk
	@echo "Building a Verilator-based simulation for tb_friet_c_lwc"
	$(VERILATOR_CPP) $(VERILATOR_CPP_WARNINGS) $(VERILATOR_CPP_DEFINES) -I $(VERILATOR_CPP_INCLUDE_FOLDER) -I obj_dir \
		$(VERILATOR_CPP_SOURCE_FILES_FINAL_COMPILATION)\
		tb_friet_c_lwc.cpp $(VERILATOR_CPP_LINK_OPTIONS) obj_dir/Vfriet_c_lwc__ALL.a \
		-o tb_friet_c_lwc

tb_friet_c_lwc_6: $(FRIET_C_LWC_SOURCE) tb_friet_c_lwc.cpp
	$(VERILATOR) $(VERILATOR_FLAGS) --top-module friet_c_lwc -GCOMBINATIONAL_ROUNDS=6 $(FRIET_C_LWC_SOURCE) tb_friet_c_lwc.cpp
	make -C obj_dir -f Vfriet_c_lwc.mk
	@echo "Building a Verilator-based simulation for tb_friet_c_lwc"
	$(VERILATOR_CPP) $(VERILATOR_CPP_WARNINGS) $(VERILATOR_CPP_DEFINES) -I $(VERILATOR_CPP_INCLUDE_FOLDER) -I obj_dir \
		$(VERILATOR_CPP_SOURCE_FILES_FINAL_COMPILATION)\
		tb_friet_c_lwc.cpp $(VERILATOR_CPP_LINK_OPTIONS) obj_dir/Vfriet_c_lwc__ALL.a \
		-o tb_friet_c_lwc

tb_friet_c_lwc_8: $(FRIET_C_LWC_SOURCE) tb_friet_c_lwc.cpp
	$(VERILATOR) $(VERILATOR_FLAGS) --top-module friet_c_lwc -GCOMBINATIONAL_ROUNDS=8 $(FRIET_C_LWC_SOURCE) tb_friet_c_lwc.cpp
	make -C obj_dir -f Vfriet_c_lwc.mk
	@echo "Building a Verilator-based simulation for tb_friet_c_lwc"
	$(VERILATOR_CPP) $(VERILATOR_CPP_WARNINGS) $(VERILATOR_CPP_DEFINES) -I $(VERILATOR_CPP_INCLUDE_FOLDER) -I obj_dir \
		$(VERILATOR_CPP_SOURCE_FILES_FINAL_COMPILATION)\
		tb_friet_c_lwc.cpp $(VERILATOR_CPP_LINK_OPTIONS) obj_dir/Vfriet_c_lwc__ALL.a \
		-o tb_friet_c_lwc

tb_friet_c_lwc_12: $(FRIET_C_LWC_SOURCE) tb_friet_c_lwc.cpp
	$(VERILATOR) $(VERILATOR_FLAGS) --top-module friet_c_lwc -GCOMBINATIONAL_ROUNDS=12 $(FRIET_C_LWC_SOURCE) tb_friet_c_lwc.cpp
	make -C obj_dir -f Vfriet_c_lwc.mk
	@echo "Building a Verilator-based simulation for tb_friet_c_lwc"
	$(VERILATOR_CPP) $(VERILATOR_CPP_WARNINGS) $(VERILATOR_CPP_DEFINES) -I $(VERILATOR_CPP_INCLUDE_FOLDER) -I obj_dir \
		$(VERILATOR_CPP_SOURCE_FILES_FINAL_COMPILATION)\
		tb_friet_c_lwc.cpp $(VERILATOR_CPP_LINK_OPTIONS) obj_dir/Vfriet_c_lwc__ALL.a \
		-o tb_friet_c_lwc

tb_friet_stream_fpga_lut4_kat: $(FRIET_STREAM_FPGA_LUT4_SOURCE) tb_friet_stream_fpga_lut4.cpp
	$(VERILATOR) $(VERILATOR_FLAGS) -GKEY_AE_TAG_SIZE_LENGTH=1 -GKEY_TAG_SIZE="1'd0" -GAE_TAG_SIZE="1'd0" --top-module friet_stream_fpga_lut4 $(FRIET_STREAM_FPGA_LUT4_SOURCE) tb_friet_stream_fpga_lut4.cpp
	make -C obj_dir -f Vfriet_stream_fpga_lut4.mk
	@echo "Building a Verilator-based simulation for tb_friet_stream_fpga_lut4"
	$(VERILATOR_CPP) $(VERILATOR_CPP_WARNINGS) $(VERILATOR_CPP_DEFINES) -DG_SKIP_KAT_AEAD_TEST=0 -DG_SKIP_INT_AEAD_TEST=1 -I $(VERILATOR_CPP_INCLUDE_FOLDER) -I obj_dir \
		$(VERILATOR_CPP_SOURCE_FILES_FINAL_COMPILATION)\
		tb_friet_stream_fpga_lut4.cpp $(VERILATOR_CPP_LINK_OPTIONS) obj_dir/Vfriet_stream_fpga_lut4__ALL.a \
		-o tb_friet_stream_fpga_lut4

tb_friet_stream_fpga_lut4_int: $(FRIET_STREAM_FPGA_LUT4_SOURCE) tb_friet_stream_fpga_lut4.cpp
	$(VERILATOR) $(VERILATOR_FLAGS) -GKEY_AE_TAG_SIZE_LENGTH=2 -GKEY_TAG_SIZE="2'd2" -GAE_TAG_SIZE="2'd2" --top-module friet_stream_fpga_lut4 $(FRIET_STREAM_FPGA_LUT4_SOURCE) tb_friet_stream_fpga_lut4.cpp
	make -C obj_dir -f Vfriet_stream_fpga_lut4.mk
	@echo "Building a Verilator-based simulation for tb_friet_stream_fpga_lut4"
	$(VERILATOR_CPP) $(VERILATOR_CPP_WARNINGS) $(VERILATOR_CPP_DEFINES) -DG_SKIP_KAT_AEAD_TEST=1 -DG_SKIP_INT_AEAD_TEST=0 -I $(VERILATOR_CPP_INCLUDE_FOLDER) -I obj_dir \
		$(VERILATOR_CPP_SOURCE_FILES_FINAL_COMPILATION)\
		tb_friet_stream_fpga_lut4.cpp $(VERILATOR_CPP_LINK_OPTIONS) obj_dir/Vfriet_stream_fpga_lut4__ALL.a \
		-o tb_friet_stream_fpga_lut4

tb_friet_lwc_fpga_lut4: $(FRIET_LWC_FPGA_LUT4_SOURCE) tb_friet_lwc_fpga_lut4.cpp
	$(VERILATOR) $(VERILATOR_FLAGS) --top-module friet_lwc_fpga_lut4 $(FRIET_LWC_FPGA_LUT4_SOURCE) tb_friet_lwc_fpga_lut4.cpp
	make -C obj_dir -f Vfriet_lwc_fpga_lut4.mk
	@echo "Building a Verilator-based simulation for $(@)"
	$(VERILATOR_CPP) $(VERILATOR_CPP_WARNINGS) $(VERILATOR_CPP_DEFINES) -I $(VERILATOR_CPP_INCLUDE_FOLDER) -I obj_dir \
		$(VERILATOR_CPP_SOURCE_FILES_FINAL_COMPILATION)\
		$(@).cpp $(VERILATOR_CPP_LINK_OPTIONS) obj_dir/Vfriet_lwc_fpga_lut4__ALL.a \
		-o $(@)

tb_friet_lwc_fpga_lut4_1: $(FRIET_LWC_FPGA_LUT4_SOURCE) tb_friet_lwc_fpga_lut4.cpp
	$(VERILATOR) $(VERILATOR_FLAGS) --top-module friet_lwc_fpga_lut4 -GCOMBINATIONAL_ROUNDS=1 $(FRIET_LWC_FPGA_LUT4_SOURCE) tb_friet_lwc_fpga_lut4.cpp
	make -C obj_dir -f Vfriet_lwc_fpga_lut4.mk
	@echo "Building a Verilator-based simulation for tb_friet_lwc_fpga_lut4"
	$(VERILATOR_CPP) $(VERILATOR_CPP_WARNINGS) $(VERILATOR_CPP_DEFINES) -I $(VERILATOR_CPP_INCLUDE_FOLDER) -I obj_dir \
		$(VERILATOR_CPP_SOURCE_FILES_FINAL_COMPILATION)\
		tb_friet_lwc_fpga_lut4.cpp $(VERILATOR_CPP_LINK_OPTIONS) obj_dir/Vfriet_lwc_fpga_lut4__ALL.a \
		-o tb_friet_lwc_fpga_lut4

tb_friet_lwc_fpga_lut4_2: $(FRIET_LWC_FPGA_LUT4_SOURCE) tb_friet_lwc_fpga_lut4.cpp
	$(VERILATOR) $(VERILATOR_FLAGS) --top-module friet_lwc_fpga_lut4 -GCOMBINATIONAL_ROUNDS=2 $(FRIET_LWC_FPGA_LUT4_SOURCE) tb_friet_lwc_fpga_lut4.cpp
	make -C obj_dir -f Vfriet_lwc_fpga_lut4.mk
	@echo "Building a Verilator-based simulation for tb_friet_lwc_fpga_lut4"
	$(VERILATOR_CPP) $(VERILATOR_CPP_WARNINGS) $(VERILATOR_CPP_DEFINES) -I $(VERILATOR_CPP_INCLUDE_FOLDER) -I obj_dir \
		$(VERILATOR_CPP_SOURCE_FILES_FINAL_COMPILATION)\
		tb_friet_lwc_fpga_lut4.cpp $(VERILATOR_CPP_LINK_OPTIONS) obj_dir/Vfriet_lwc_fpga_lut4__ALL.a \
		-o tb_friet_lwc_fpga_lut4

tb_friet_lwc_fpga_lut4_3: $(FRIET_LWC_FPGA_LUT4_SOURCE) tb_friet_lwc_fpga_lut4.cpp
	$(VERILATOR) $(VERILATOR_FLAGS) --top-module friet_lwc_fpga_lut4 -GCOMBINATIONAL_ROUNDS=3 $(FRIET_LWC_FPGA_LUT4_SOURCE) tb_friet_lwc_fpga_lut4.cpp
	make -C obj_dir -f Vfriet_lwc_fpga_lut4.mk
	@echo "Building a Verilator-based simulation for tb_friet_lwc_fpga_lut4"
	$(VERILATOR_CPP) $(VERILATOR_CPP_WARNINGS) $(VERILATOR_CPP_DEFINES) -I $(VERILATOR_CPP_INCLUDE_FOLDER) -I obj_dir \
		$(VERILATOR_CPP_SOURCE_FILES_FINAL_COMPILATION)\
		tb_friet_lwc_fpga_lut4.cpp $(VERILATOR_CPP_LINK_OPTIONS) obj_dir/Vfriet_lwc_fpga_lut4__ALL.a \
		-o tb_friet_lwc_fpga_lut4

tb_friet_lwc_fpga_lut4_4: $(FRIET_LWC_FPGA_LUT4_SOURCE) tb_friet_lwc_fpga_lut4.cpp
	$(VERILATOR) $(VERILATOR_FLAGS) --top-module friet_lwc_fpga_lut4 -GCOMBINATIONAL_ROUNDS=4 $(FRIET_LWC_FPGA_LUT4_SOURCE) tb_friet_lwc_fpga_lut4.cpp
	make -C obj_dir -f Vfriet_lwc_fpga_lut4.mk
	@echo "Building a Verilator-based simulation for tb_friet_lwc_fpga_lut4"
	$(VERILATOR_CPP) $(VERILATOR_CPP_WARNINGS) $(VERILATOR_CPP_DEFINES) -I $(VERILATOR_CPP_INCLUDE_FOLDER) -I obj_dir \
		$(VERILATOR_CPP_SOURCE_FILES_FINAL_COMPILATION)\
		tb_friet_lwc_fpga_lut4.cpp $(VERILATOR_CPP_LINK_OPTIONS) obj_dir/Vfriet_lwc_fpga_lut4__ALL.a \
		-o tb_friet_lwc_fpga_lut4

tb_friet_lwc_fpga_lut4_6: $(FRIET_LWC_FPGA_LUT4_SOURCE) tb_friet_lwc_fpga_lut4.cpp
	$(VERILATOR) $(VERILATOR_FLAGS) --top-module friet_lwc_fpga_lut4 -GCOMBINATIONAL_ROUNDS=6 $(FRIET_LWC_FPGA_LUT4_SOURCE) tb_friet_lwc_fpga_lut4.cpp
	make -C obj_dir -f Vfriet_lwc_fpga_lut4.mk
	@echo "Building a Verilator-based simulation for tb_friet_lwc_fpga_lut4"
	$(VERILATOR_CPP) $(VERILATOR_CPP_WARNINGS) $(VERILATOR_CPP_DEFINES) -I $(VERILATOR_CPP_INCLUDE_FOLDER) -I obj_dir \
		$(VERILATOR_CPP_SOURCE_FILES_FINAL_COMPILATION)\
		tb_friet_lwc_fpga_lut4.cpp $(VERILATOR_CPP_LINK_OPTIONS) obj_dir/Vfriet_lwc_fpga_lut4__ALL.a \
		-o tb_friet_lwc_fpga_lut4

tb_friet_lwc_fpga_lut4_8: $(FRIET_LWC_FPGA_LUT4_SOURCE) tb_friet_lwc_fpga_lut4.cpp
	$(VERILATOR) $(VERILATOR_FLAGS) --top-module friet_lwc_fpga_lut4 -GCOMBINATIONAL_ROUNDS=8 $(FRIET_LWC_FPGA_LUT4_SOURCE) tb_friet_lwc_fpga_lut4.cpp
	make -C obj_dir -f Vfriet_lwc_fpga_lut4.mk
	@echo "Building a Verilator-based simulation for tb_friet_lwc_fpga_lut4"
	$(VERILATOR_CPP) $(VERILATOR_CPP_WARNINGS) $(VERILATOR_CPP_DEFINES) -I $(VERILATOR_CPP_INCLUDE_FOLDER) -I obj_dir \
		$(VERILATOR_CPP_SOURCE_FILES_FINAL_COMPILATION)\
		tb_friet_lwc_fpga_lut4.cpp $(VERILATOR_CPP_LINK_OPTIONS) obj_dir/Vfriet_lwc_fpga_lut4__ALL.a \
		-o tb_friet_lwc_fpga_lut4

tb_friet_lwc_fpga_lut4_12: $(FRIET_LWC_FPGA_LUT4_SOURCE) tb_friet_lwc_fpga_lut4.cpp
	$(VERILATOR) $(VERILATOR_FLAGS) --top-module friet_lwc_fpga_lut4 -GCOMBINATIONAL_ROUNDS=12 $(FRIET_LWC_FPGA_LUT4_SOURCE) tb_friet_lwc_fpga_lut4.cpp
	make -C obj_dir -f Vfriet_lwc_fpga_lut4.mk
	@echo "Building a Verilator-based simulation for tb_friet_lwc_fpga_lut4"
	$(VERILATOR_CPP) $(VERILATOR_CPP_WARNINGS) $(VERILATOR_CPP_DEFINES) -I $(VERILATOR_CPP_INCLUDE_FOLDER) -I obj_dir \
		$(VERILATOR_CPP_SOURCE_FILES_FINAL_COMPILATION)\
		tb_friet_lwc_fpga_lut4.cpp $(VERILATOR_CPP_LINK_OPTIONS) obj_dir/Vfriet_lwc_fpga_lut4__ALL.a \
		-o tb_friet_lwc_fpga_lut4

tb_friet_stream_fpga_lut6_kat: $(FRIET_STREAM_FPGA_LUT6_SOURCE) tb_friet_stream_fpga_lut6.cpp
	$(VERILATOR) $(VERILATOR_FLAGS) -GKEY_AE_TAG_SIZE_LENGTH=1 -GKEY_TAG_SIZE="1'd0" -GAE_TAG_SIZE="1'd0" --top-module friet_stream_fpga_lut6 $(FRIET_STREAM_FPGA_LUT6_SOURCE) tb_friet_stream_fpga_lut6.cpp
	make -C obj_dir -f Vfriet_stream_fpga_lut6.mk
	@echo "Building a Verilator-based simulation for tb_friet_stream_fpga_lut6"
	$(VERILATOR_CPP) $(VERILATOR_CPP_WARNINGS) $(VERILATOR_CPP_DEFINES) -DG_SKIP_KAT_AEAD_TEST=0 -DG_SKIP_INT_AEAD_TEST=1 -I $(VERILATOR_CPP_INCLUDE_FOLDER) -I obj_dir \
		$(VERILATOR_CPP_SOURCE_FILES_FINAL_COMPILATION)\
		tb_friet_stream_fpga_lut6.cpp $(VERILATOR_CPP_LINK_OPTIONS) obj_dir/Vfriet_stream_fpga_lut6__ALL.a \
		-o tb_friet_stream_fpga_lut6

tb_friet_stream_fpga_lut6_int: $(FRIET_STREAM_FPGA_LUT6_SOURCE) tb_friet_stream_fpga_lut6.cpp
	$(VERILATOR) $(VERILATOR_FLAGS) -GKEY_AE_TAG_SIZE_LENGTH=2 -GKEY_TAG_SIZE="2'd2" -GAE_TAG_SIZE="2'd2" --top-module friet_stream_fpga_lut6 $(FRIET_STREAM_FPGA_LUT6_SOURCE) tb_friet_stream_fpga_lut6.cpp
	make -C obj_dir -f Vfriet_stream_fpga_lut6.mk
	@echo "Building a Verilator-based simulation for tb_friet_stream_fpga_lut6"
	$(VERILATOR_CPP) $(VERILATOR_CPP_WARNINGS) $(VERILATOR_CPP_DEFINES) -DG_SKIP_KAT_AEAD_TEST=1 -DG_SKIP_INT_AEAD_TEST=0 -I $(VERILATOR_CPP_INCLUDE_FOLDER) -I obj_dir \
		$(VERILATOR_CPP_SOURCE_FILES_FINAL_COMPILATION)\
		tb_friet_stream_fpga_lut6.cpp $(VERILATOR_CPP_LINK_OPTIONS) obj_dir/Vfriet_stream_fpga_lut6__ALL.a \
		-o tb_friet_stream_fpga_lut6

tb_friet_lwc_fpga_lut6: $(FRIET_LWC_FPGA_LUT6_SOURCE) tb_friet_lwc_fpga_lut6.cpp
	$(VERILATOR) $(VERILATOR_FLAGS) --top-module friet_lwc_fpga_lut6 $(FRIET_LWC_FPGA_LUT6_SOURCE) tb_friet_lwc_fpga_lut6.cpp
	make -C obj_dir -f Vfriet_lwc_fpga_lut6.mk
	@echo "Building a Verilator-based simulation for $(@)"
	$(VERILATOR_CPP) $(VERILATOR_CPP_WARNINGS) $(VERILATOR_CPP_DEFINES) -I $(VERILATOR_CPP_INCLUDE_FOLDER) -I obj_dir \
		$(VERILATOR_CPP_SOURCE_FILES_FINAL_COMPILATION)\
		$(@).cpp $(VERILATOR_CPP_LINK_OPTIONS) obj_dir/Vfriet_lwc_fpga_lut6__ALL.a \
		-o $(@)

tb_friet_lwc_fpga_lut6_1: $(FRIET_LWC_FPGA_LUT6_SOURCE) tb_friet_lwc_fpga_lut6.cpp
	$(VERILATOR) $(VERILATOR_FLAGS) --top-module friet_lwc_fpga_lut6 -GCOMBINATIONAL_ROUNDS=1 $(FRIET_LWC_FPGA_LUT6_SOURCE) tb_friet_lwc_fpga_lut6.cpp
	make -C obj_dir -f Vfriet_lwc_fpga_lut6.mk
	@echo "Building a Verilator-based simulation for tb_friet_lwc_fpga_lut6"
	$(VERILATOR_CPP) $(VERILATOR_CPP_WARNINGS) $(VERILATOR_CPP_DEFINES) -I $(VERILATOR_CPP_INCLUDE_FOLDER) -I obj_dir \
		$(VERILATOR_CPP_SOURCE_FILES_FINAL_COMPILATION)\
		tb_friet_lwc_fpga_lut6.cpp $(VERILATOR_CPP_LINK_OPTIONS) obj_dir/Vfriet_lwc_fpga_lut6__ALL.a \
		-o tb_friet_lwc_fpga_lut6

tb_friet_lwc_fpga_lut6_2: $(FRIET_LWC_FPGA_LUT6_SOURCE) tb_friet_lwc_fpga_lut6.cpp
	$(VERILATOR) $(VERILATOR_FLAGS) --top-module friet_lwc_fpga_lut6 -GCOMBINATIONAL_ROUNDS=2 $(FRIET_LWC_FPGA_LUT6_SOURCE) tb_friet_lwc_fpga_lut6.cpp
	make -C obj_dir -f Vfriet_lwc_fpga_lut6.mk
	@echo "Building a Verilator-based simulation for tb_friet_lwc_fpga_lut6"
	$(VERILATOR_CPP) $(VERILATOR_CPP_WARNINGS) $(VERILATOR_CPP_DEFINES) -I $(VERILATOR_CPP_INCLUDE_FOLDER) -I obj_dir \
		$(VERILATOR_CPP_SOURCE_FILES_FINAL_COMPILATION)\
		tb_friet_lwc_fpga_lut6.cpp $(VERILATOR_CPP_LINK_OPTIONS) obj_dir/Vfriet_lwc_fpga_lut6__ALL.a \
		-o tb_friet_lwc_fpga_lut6

tb_friet_lwc_fpga_lut6_3: $(FRIET_LWC_FPGA_LUT6_SOURCE) tb_friet_lwc_fpga_lut6.cpp
	$(VERILATOR) $(VERILATOR_FLAGS) --top-module friet_lwc_fpga_lut6 -GCOMBINATIONAL_ROUNDS=3 $(FRIET_LWC_FPGA_LUT6_SOURCE) tb_friet_lwc_fpga_lut6.cpp
	make -C obj_dir -f Vfriet_lwc_fpga_lut6.mk
	@echo "Building a Verilator-based simulation for tb_friet_lwc_fpga_lut6"
	$(VERILATOR_CPP) $(VERILATOR_CPP_WARNINGS) $(VERILATOR_CPP_DEFINES) -I $(VERILATOR_CPP_INCLUDE_FOLDER) -I obj_dir \
		$(VERILATOR_CPP_SOURCE_FILES_FINAL_COMPILATION)\
		tb_friet_lwc_fpga_lut6.cpp $(VERILATOR_CPP_LINK_OPTIONS) obj_dir/Vfriet_lwc_fpga_lut6__ALL.a \
		-o tb_friet_lwc_fpga_lut6

tb_friet_lwc_fpga_lut6_4: $(FRIET_LWC_FPGA_LUT6_SOURCE) tb_friet_lwc_fpga_lut6.cpp
	$(VERILATOR) $(VERILATOR_FLAGS) --top-module friet_lwc_fpga_lut6 -GCOMBINATIONAL_ROUNDS=4 $(FRIET_LWC_FPGA_LUT6_SOURCE) tb_friet_lwc_fpga_lut6.cpp
	make -C obj_dir -f Vfriet_lwc_fpga_lut6.mk
	@echo "Building a Verilator-based simulation for tb_friet_lwc_fpga_lut6"
	$(VERILATOR_CPP) $(VERILATOR_CPP_WARNINGS) $(VERILATOR_CPP_DEFINES) -I $(VERILATOR_CPP_INCLUDE_FOLDER) -I obj_dir \
		$(VERILATOR_CPP_SOURCE_FILES_FINAL_COMPILATION)\
		tb_friet_lwc_fpga_lut6.cpp $(VERILATOR_CPP_LINK_OPTIONS) obj_dir/Vfriet_lwc_fpga_lut6__ALL.a \
		-o tb_friet_lwc_fpga_lut6

tb_friet_lwc_fpga_lut6_6: $(FRIET_LWC_FPGA_LUT6_SOURCE) tb_friet_lwc_fpga_lut6.cpp
	$(VERILATOR) $(VERILATOR_FLAGS) --top-module friet_lwc_fpga_lut6 -GCOMBINATIONAL_ROUNDS=6 $(FRIET_LWC_FPGA_LUT6_SOURCE) tb_friet_lwc_fpga_lut6.cpp
	make -C obj_dir -f Vfriet_lwc_fpga_lut6.mk
	@echo "Building a Verilator-based simulation for tb_friet_lwc_fpga_lut6"
	$(VERILATOR_CPP) $(VERILATOR_CPP_WARNINGS) $(VERILATOR_CPP_DEFINES) -I $(VERILATOR_CPP_INCLUDE_FOLDER) -I obj_dir \
		$(VERILATOR_CPP_SOURCE_FILES_FINAL_COMPILATION)\
		tb_friet_lwc_fpga_lut6.cpp $(VERILATOR_CPP_LINK_OPTIONS) obj_dir/Vfriet_lwc_fpga_lut6__ALL.a \
		-o tb_friet_lwc_fpga_lut6

tb_friet_lwc_fpga_lut6_8: $(FRIET_LWC_FPGA_LUT6_SOURCE) tb_friet_lwc_fpga_lut6.cpp
	$(VERILATOR) $(VERILATOR_FLAGS) --top-module friet_lwc_fpga_lut6 -GCOMBINATIONAL_ROUNDS=8 $(FRIET_LWC_FPGA_LUT6_SOURCE) tb_friet_lwc_fpga_lut6.cpp
	make -C obj_dir -f Vfriet_lwc_fpga_lut6.mk
	@echo "Building a Verilator-based simulation for tb_friet_lwc_fpga_lut6"
	$(VERILATOR_CPP) $(VERILATOR_CPP_WARNINGS) $(VERILATOR_CPP_DEFINES) -I $(VERILATOR_CPP_INCLUDE_FOLDER) -I obj_dir \
		$(VERILATOR_CPP_SOURCE_FILES_FINAL_COMPILATION)\
		tb_friet_lwc_fpga_lut6.cpp $(VERILATOR_CPP_LINK_OPTIONS) obj_dir/Vfriet_lwc_fpga_lut6__ALL.a \
		-o tb_friet_lwc_fpga_lut6

tb_friet_lwc_fpga_lut6_12: $(FRIET_LWC_FPGA_LUT6_SOURCE) tb_friet_lwc_fpga_lut6.cpp
	$(VERILATOR) $(VERILATOR_FLAGS) --top-module friet_lwc_fpga_lut6 -GCOMBINATIONAL_ROUNDS=12 $(FRIET_LWC_FPGA_LUT6_SOURCE) tb_friet_lwc_fpga_lut6.cpp
	make -C obj_dir -f Vfriet_lwc_fpga_lut6.mk
	@echo "Building a Verilator-based simulation for tb_friet_lwc_fpga_lut6"
	$(VERILATOR_CPP) $(VERILATOR_CPP_WARNINGS) $(VERILATOR_CPP_DEFINES) -I $(VERILATOR_CPP_INCLUDE_FOLDER) -I obj_dir \
		$(VERILATOR_CPP_SOURCE_FILES_FINAL_COMPILATION)\
		tb_friet_lwc_fpga_lut6.cpp $(VERILATOR_CPP_LINK_OPTIONS) obj_dir/Vfriet_lwc_fpga_lut6__ALL.a \
		-o tb_friet_lwc_fpga_lut6

tb_friet_stream_asic_kat: $(FRIET_STREAM_ASIC_SOURCE) tb_friet_stream_asic.cpp
	$(VERILATOR) $(VERILATOR_FLAGS) -GKEY_AE_TAG_SIZE_LENGTH=1 -GKEY_TAG_SIZE="1'd0" -GAE_TAG_SIZE="1'd0" --top-module friet_stream_asic $(FRIET_STREAM_ASIC_SOURCE) tb_friet_stream_asic.cpp
	make -C obj_dir -f Vfriet_stream_asic.mk
	@echo "Building a Verilator-based simulation for tb_friet_stream_asic"
	$(VERILATOR_CPP) $(VERILATOR_CPP_WARNINGS) $(VERILATOR_CPP_DEFINES) -DG_SKIP_KAT_AEAD_TEST=0 -DG_SKIP_INT_AEAD_TEST=1 -I $(VERILATOR_CPP_INCLUDE_FOLDER) -I obj_dir \
		$(VERILATOR_CPP_SOURCE_FILES_FINAL_COMPILATION)\
		tb_friet_stream_asic.cpp $(VERILATOR_CPP_LINK_OPTIONS) obj_dir/Vfriet_stream_asic__ALL.a \
		-o tb_friet_stream_asic

tb_friet_stream_asic_int: $(FRIET_STREAM_ASIC_SOURCE) tb_friet_stream_asic.cpp
	$(VERILATOR) $(VERILATOR_FLAGS) -GKEY_AE_TAG_SIZE_LENGTH=2 -GKEY_TAG_SIZE="2'd2" -GAE_TAG_SIZE="2'd2" --top-module friet_stream_fpga_lut4 $(FRIET_STREAM_ASIC_SOURCE) tb_friet_stream_asic.cpp
	make -C obj_dir -f Vfriet_stream_asic.mk
	@echo "Building a Verilator-based simulation for tb_friet_stream_asic"
	$(VERILATOR_CPP) $(VERILATOR_CPP_WARNINGS) $(VERILATOR_CPP_DEFINES) -DG_SKIP_KAT_AEAD_TEST=1 -DG_SKIP_INT_AEAD_TEST=0 -I $(VERILATOR_CPP_INCLUDE_FOLDER) -I obj_dir \
		$(VERILATOR_CPP_SOURCE_FILES_FINAL_COMPILATION)\
		tb_friet_stream_asic.cpp $(VERILATOR_CPP_LINK_OPTIONS) obj_dir/Vfriet_stream_asic__ALL.a \
		-o tb_friet_stream_asic

tb_friet_lwc_asic: $(FRIET_LWC_ASIC_SOURCE) tb_friet_lwc_asic.cpp
	$(VERILATOR) $(VERILATOR_FLAGS) --top-module friet_lwc_asic $(FRIET_LWC_ASIC_SOURCE) tb_friet_lwc_asic.cpp
	make -C obj_dir -f Vfriet_lwc_asic.mk
	@echo "Building a Verilator-based simulation for $(@)"
	$(VERILATOR_CPP) $(VERILATOR_CPP_WARNINGS) $(VERILATOR_CPP_DEFINES) -I $(VERILATOR_CPP_INCLUDE_FOLDER) -I obj_dir \
		$(VERILATOR_CPP_SOURCE_FILES_FINAL_COMPILATION)\
		$(@).cpp $(VERILATOR_CPP_LINK_OPTIONS) obj_dir/Vfriet_lwc_asic__ALL.a \
		-o $(@)

tb_friet_lwc_asic_1: $(FRIET_LWC_ASIC_SOURCE) tb_friet_lwc_asic.cpp
	$(VERILATOR) $(VERILATOR_FLAGS) --top-module friet_lwc_asic -GCOMBINATIONAL_ROUNDS=1 $(FRIET_LWC_ASIC_SOURCE) tb_friet_lwc_asic.cpp
	make -C obj_dir -f Vfriet_lwc_asic.mk
	@echo "Building a Verilator-based simulation for tb_friet_lwc_asic"
	$(VERILATOR_CPP) $(VERILATOR_CPP_WARNINGS) $(VERILATOR_CPP_DEFINES) -I $(VERILATOR_CPP_INCLUDE_FOLDER) -I obj_dir \
		$(VERILATOR_CPP_SOURCE_FILES_FINAL_COMPILATION)\
		tb_friet_lwc_asic.cpp $(VERILATOR_CPP_LINK_OPTIONS) obj_dir/Vfriet_lwc_asic__ALL.a \
		-o tb_friet_lwc_asic

tb_friet_lwc_asic_2: $(FRIET_LWC_ASIC_SOURCE) tb_friet_lwc_asic.cpp
	$(VERILATOR) $(VERILATOR_FLAGS) --top-module friet_lwc_asic -GCOMBINATIONAL_ROUNDS=2 $(FRIET_LWC_ASIC_SOURCE) tb_friet_lwc_asic.cpp
	make -C obj_dir -f Vfriet_lwc_asic.mk
	@echo "Building a Verilator-based simulation for tb_friet_lwc_asic"
	$(VERILATOR_CPP) $(VERILATOR_CPP_WARNINGS) $(VERILATOR_CPP_DEFINES) -I $(VERILATOR_CPP_INCLUDE_FOLDER) -I obj_dir \
		$(VERILATOR_CPP_SOURCE_FILES_FINAL_COMPILATION)\
		tb_friet_lwc_asic.cpp $(VERILATOR_CPP_LINK_OPTIONS) obj_dir/Vfriet_lwc_asic__ALL.a \
		-o tb_friet_lwc_asic

tb_friet_lwc_asic_3: $(FRIET_LWC_ASIC_SOURCE) tb_friet_lwc_asic.cpp
	$(VERILATOR) $(VERILATOR_FLAGS) --top-module friet_lwc_asic -GCOMBINATIONAL_ROUNDS=3 $(FRIET_LWC_ASIC_SOURCE) tb_friet_lwc_asic.cpp
	make -C obj_dir -f Vfriet_lwc_asic.mk
	@echo "Building a Verilator-based simulation for tb_friet_lwc_asic"
	$(VERILATOR_CPP) $(VERILATOR_CPP_WARNINGS) $(VERILATOR_CPP_DEFINES) -I $(VERILATOR_CPP_INCLUDE_FOLDER) -I obj_dir \
		$(VERILATOR_CPP_SOURCE_FILES_FINAL_COMPILATION)\
		tb_friet_lwc_asic.cpp $(VERILATOR_CPP_LINK_OPTIONS) obj_dir/Vfriet_lwc_asic__ALL.a \
		-o tb_friet_lwc_asic

tb_friet_lwc_asic_4: $(FRIET_LWC_ASIC_SOURCE) tb_friet_lwc_asic.cpp
	$(VERILATOR) $(VERILATOR_FLAGS) --top-module friet_lwc_asic -GCOMBINATIONAL_ROUNDS=4 $(FRIET_LWC_ASIC_SOURCE) tb_friet_lwc_asic.cpp
	make -C obj_dir -f Vfriet_lwc_asic.mk
	@echo "Building a Verilator-based simulation for tb_friet_lwc_asic"
	$(VERILATOR_CPP) $(VERILATOR_CPP_WARNINGS) $(VERILATOR_CPP_DEFINES) -I $(VERILATOR_CPP_INCLUDE_FOLDER) -I obj_dir \
		$(VERILATOR_CPP_SOURCE_FILES_FINAL_COMPILATION)\
		tb_friet_lwc_asic.cpp $(VERILATOR_CPP_LINK_OPTIONS) obj_dir/Vfriet_lwc_asic__ALL.a \
		-o tb_friet_lwc_asic

tb_friet_lwc_asic_6: $(FRIET_LWC_ASIC_SOURCE) tb_friet_lwc_asic.cpp
	$(VERILATOR) $(VERILATOR_FLAGS) --top-module friet_lwc_asic -GCOMBINATIONAL_ROUNDS=6 $(FRIET_LWC_ASIC_SOURCE) tb_friet_lwc_asic.cpp
	make -C obj_dir -f Vfriet_lwc_asic.mk
	@echo "Building a Verilator-based simulation for tb_friet_lwc_asic"
	$(VERILATOR_CPP) $(VERILATOR_CPP_WARNINGS) $(VERILATOR_CPP_DEFINES) -I $(VERILATOR_CPP_INCLUDE_FOLDER) -I obj_dir \
		$(VERILATOR_CPP_SOURCE_FILES_FINAL_COMPILATION)\
		tb_friet_lwc_asic.cpp $(VERILATOR_CPP_LINK_OPTIONS) obj_dir/Vfriet_lwc_asic__ALL.a \
		-o tb_friet_lwc_asic

tb_friet_lwc_asic_8: $(FRIET_LWC_ASIC_SOURCE) tb_friet_lwc_asic.cpp
	$(VERILATOR) $(VERILATOR_FLAGS) --top-module friet_lwc_asic -GCOMBINATIONAL_ROUNDS=8 $(FRIET_LWC_ASIC_SOURCE) tb_friet_lwc_asic.cpp
	make -C obj_dir -f Vfriet_lwc_asic.mk
	@echo "Building a Verilator-based simulation for tb_friet_lwc_asic"
	$(VERILATOR_CPP) $(VERILATOR_CPP_WARNINGS) $(VERILATOR_CPP_DEFINES) -I $(VERILATOR_CPP_INCLUDE_FOLDER) -I obj_dir \
		$(VERILATOR_CPP_SOURCE_FILES_FINAL_COMPILATION)\
		tb_friet_lwc_asic.cpp $(VERILATOR_CPP_LINK_OPTIONS) obj_dir/Vfriet_lwc_asic__ALL.a \
		-o tb_friet_lwc_asic

tb_friet_lwc_asic_12: $(FRIET_LWC_ASIC_SOURCE) tb_friet_lwc_asic.cpp
	$(VERILATOR) $(VERILATOR_FLAGS) --top-module friet_lwc_asic -GCOMBINATIONAL_ROUNDS=12 $(FRIET_LWC_ASIC_SOURCE) tb_friet_lwc_asic.cpp
	make -C obj_dir -f Vfriet_lwc_asic.mk
	@echo "Building a Verilator-based simulation for tb_friet_lwc_asic"
	$(VERILATOR_CPP) $(VERILATOR_CPP_WARNINGS) $(VERILATOR_CPP_DEFINES) -I $(VERILATOR_CPP_INCLUDE_FOLDER) -I obj_dir \
		$(VERILATOR_CPP_SOURCE_FILES_FINAL_COMPILATION)\
		tb_friet_lwc_asic.cpp $(VERILATOR_CPP_LINK_OPTIONS) obj_dir/Vfriet_lwc_asic__ALL.a \
		-o tb_friet_lwc_asic

clean:
	@echo "Cleaning up..."
	rm -r -f obj_dir
	rm -r -f tb_friet_c_stream
	rm -r -f tb_friet_c_stream.vcd
	rm -r -f tb_friet_c_stream.fst
	rm -r -f tb_friet_c_stream.fst.hier
	rm -r -f tb_friet_c_lwc
	rm -r -f tb_friet_c_lwc.vcd
	rm -r -f tb_friet_c_lwc.fst
	rm -r -f tb_friet_c_lwc.fst.hier
	rm -r -f tb_friet_stream_fpga_lut4
	rm -r -f tb_friet_stream_fpga_lut4.vcd
	rm -r -f tb_friet_stream_fpga_lut4.fst
	rm -r -f tb_friet_stream_fpga_lut4.fst.hier
	rm -r -f tb_friet_lwc_fpga_lut4
	rm -r -f tb_friet_lwc_fpga_lut4.vcd
	rm -r -f tb_friet_lwc_fpga_lut4.fst
	rm -r -f tb_friet_lwc_fpga_lut4.fst.hier
	rm -r -f tb_friet_stream_fpga_lut6
	rm -r -f tb_friet_stream_fpga_lut6.vcd
	rm -r -f tb_friet_stream_fpga_lut6.fst
	rm -r -f tb_friet_stream_fpga_lut6.fst.hier
	rm -r -f tb_friet_lwc_fpga_lut6
	rm -r -f tb_friet_lwc_fpga_lut6.vcd
	rm -r -f tb_friet_lwc_fpga_lut6.fst
	rm -r -f tb_friet_lwc_fpga_lut6.fst.hier
	rm -r -f tb_friet_stream_asic
	rm -r -f tb_friet_stream_asic.vcd
	rm -r -f tb_friet_stream_asic.fst
	rm -r -f tb_friet_stream_asic.fst.hier
	rm -r -f tb_friet_lwc_asic
	rm -r -f tb_friet_lwc_asic.vcd
	rm -r -f tb_friet_lwc_asic.fst
	rm -r -f tb_friet_lwc_asic.fst.hier
	@echo "Cleaning done."