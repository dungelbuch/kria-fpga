# KR260 FPGA build
#
#   make                build everything: bitstream and XSA
#   make cores          package the user IP cores in ip_cores/ (listed in CORES)
#   make project        create the Vivado project (packages the cores first)
#   make synth          run synthesis
#   make impl           run implementation (up to route_design)
#   make bit            write the bitstream (.bit, .bit.bin) to output/
#   make xsa            export the hardware platform (XSA) for Vitis/PetaLinux to output/
#   make sim-cores      create simulation projects for the cores listed in SIM_CORES
#   make nonproject     build bitstream and XSA in non-project mode into output/nonproject/, with a summary
#   make gui            open the project in the Vivado GUI
#
# Each step runs the steps before it if they are missing or out of date.
# clean, clean-cores, clean-project, clean-synth, clean-impl, clean-sim remove the respective results.

VIVADO_SETTINGS ?= /tools/Xilinx/2025.2/Vivado/settings64.sh
# Parallel jobs for Vivado runs
JOBS ?= $(shell n=$$(nproc); echo $$(( n > 2 ? n - 2 : 1 )))

# User IP cores (folder names in ip_cores/) used by the block design
CORES = axis_dummy_data_generator_v2_0 \
        axis_ram_writer_v2_0
# User IP cores to create simulation projects for
SIM_CORES = axis_dummy_data_generator_v2_0 \
            axis_lia_fir_v1_0 \
            axis_lia_iir_v1_0

PROJ_NAME = kr260_ps
BUILD = build
OUTPUT = output
LOGS = $(BUILD)/logs

# vivado <log name> <script> [tclargs...]
vivado = bash -c '. $(VIVADO_SETTINGS) && JOBS=$(JOBS) vivado -mode batch -notrace -nojournal \
	-log $(LOGS)/$(1).log -source scripts/$(2) $(if $(3),-tclargs $(3))'

COMMON_TCL = scripts/settings.tcl src/parameters.tcl
CORE_TARGETS = $(addprefix $(BUILD)/cores/,$(addsuffix /component.xml,$(CORES)))
PROJECT_SRCS = scripts/project.tcl scripts/bd_utils.tcl $(COMMON_TCL) \
	$(wildcard src/bd/*.tcl src/hdl/* src/constraints/*)

# Stamp files mark finished steps, the Vivado project files change whenever it is opened
PROJECT_STAMP = $(BUILD)/.project.done
SYNTH_STAMP = $(BUILD)/.synth.done
IMPL_STAMP = $(BUILD)/.impl.done
BIT = $(OUTPUT)/$(PROJ_NAME).bit
XSA = $(OUTPUT)/$(PROJ_NAME).xsa

.PHONY: all cores project synth impl bit xsa sim-cores nonproject gui \
	clean clean-cores clean-project clean-synth clean-impl clean-sim
.DELETE_ON_ERROR:
.SECONDEXPANSION:

all: bit xsa

cores: $(CORE_TARGETS)
project: $(PROJECT_STAMP)
synth: $(SYNTH_STAMP)
impl: $(IMPL_STAMP)
bit: $(BIT)
xsa: $(XSA)

$(BUILD)/cores/%/component.xml: scripts/core.tcl $(COMMON_TCL) $$(wildcard ip_cores/$$*/*.tcl ip_cores/$$*/*.xdc ip_cores/$$*/hdl/*)
	@mkdir -p $(LOGS)
	$(call vivado,core_$*,core.tcl,$*)

$(PROJECT_STAMP): $(CORE_TARGETS) $(PROJECT_SRCS)
	@mkdir -p $(LOGS)
	rm -f $(SYNTH_STAMP) $(IMPL_STAMP)
	$(call vivado,project,project.tcl)
	touch $@

$(SYNTH_STAMP): $(PROJECT_STAMP) scripts/synth.tcl
	$(call vivado,synth,synth.tcl)
	touch $@

$(IMPL_STAMP): $(SYNTH_STAMP) scripts/impl.tcl
	$(call vivado,impl,impl.tcl)
	touch $@

$(BIT): $(IMPL_STAMP) scripts/bitstream.tcl
	$(call vivado,bitstream,bitstream.tcl)
	@echo "$(PROJ_NAME) built on $$(date) on $$(hostname) by $$(whoami)$$(git rev-parse --short HEAD 2>/dev/null | sed 's/^/ at commit /')" > $(OUTPUT)/info.txt

$(XSA): $(BIT) scripts/export_xsa.tcl
	$(call vivado,export_xsa,export_xsa.tcl)

sim-cores: $(addprefix $(BUILD)/sim_cores/,$(addsuffix _sim/.done,$(SIM_CORES)))

$(BUILD)/sim_cores/%_sim/.done: scripts/core_sim.tcl $(COMMON_TCL) $$(wildcard ip_cores/$$*/*.tcl ip_cores/$$*/hdl/* ip_cores/$$*/sim/* ip_cores/xlibs/*)
	@mkdir -p $(LOGS)
	$(call vivado,sim_$*,core_sim.tcl,$*)
	touch $@

# Non-project build, always runs from scratch; summary in build/nonproject/summary.txt.
# Only the step headers, errors and the summary are shown, the full output is in the log.
nonproject: SHELL = /bin/bash
nonproject: .SHELLFLAGS = -o pipefail -c
nonproject: $(CORE_TARGETS)
	@mkdir -p $(LOGS)
	@echo "Non-project build, full log in $(LOGS)/nonproject.log"
	@$(call vivado,nonproject,nonproject.tcl) | awk '/^Non-project build summary:/ { on = 1; print prev } \
		on && !/^INFO:/ || /^######## .* ########$$/ || /^ERROR:/ { print; fflush() } { prev = $$0 }'

gui: $(PROJECT_STAMP)
	bash -c '. $(VIVADO_SETTINGS) && cd $(BUILD) && vivado -nojournal -nolog $(PROJ_NAME).xpr &'

clean:
	rm -rf $(BUILD) $(OUTPUT) .Xil

clean-cores:
	rm -rf $(BUILD)/cores

clean-project:
	rm -rf $(BUILD)/$(PROJ_NAME).* $(PROJECT_STAMP) $(SYNTH_STAMP) $(IMPL_STAMP)

clean-synth:
	rm -rf $(BUILD)/$(PROJ_NAME).runs/synth_1 $(SYNTH_STAMP) $(IMPL_STAMP)

clean-impl:
	rm -rf $(BUILD)/$(PROJ_NAME).runs/impl_1 $(IMPL_STAMP)

clean-sim:
	rm -rf $(BUILD)/sim_cores
