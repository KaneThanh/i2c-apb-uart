# =============================================================================
# flow/Makefile — gom lệnh cho phần việc sau RTL (lint, synth, STA, LEC, harden, sign-off).
# Chạy từ gốc repo:  make -C flow <đích>      (mọi đường dẫn tính từ gốc repo)
# Môi trường: nix-shell của LibreLane 3.0.14 (xem 00_master_plan T01).
# Trạng thái: `make -C flow lint synth sta_pre lec_syn metrics` đã chạy hết ngày 16/11/2026 (~30 s)
#             trong nix-shell LibreLane 3.0.14 [ĐÃ ĐO]. Đích harden, sta_post, lec_pnr [CHƯA XÁC MINH qua Makefile].
# =============================================================================
ROOT      := $(abspath ..)
PDK_ROOT  ?= $(HOME)/.ciel
PDK       ?= sky130A
LIBDIR    := $(PDK_ROOT)/$(PDK)/libs.ref/sky130_fd_sc_hd/lib
SCLCFG    := $(PDK_ROOT)/$(PDK)/libs.tech/openlane/sky130_fd_sc_hd
LIB_TT    := $(LIBDIR)/sky130_fd_sc_hd__tt_025C_1v80.lib
LIB_SS    := $(LIBDIR)/sky130_fd_sc_hd__ss_100C_1v60.lib
LIB_FF    := $(LIBDIR)/sky130_fd_sc_hd__ff_n40C_1v95.lib
YOSYS     ?= yosys
VERILATOR ?= verilator
STA       ?= sta
BUILD     := $(ROOT)/build
RUN       ?= $(ROOT)/runs/wokwi

CORE_SRC  := $(addprefix $(ROOT)/rtl/,sync_2ff.v baud_gen.v uart_tx.v uart_rx.v uart_regs.v apb_uart_core.v)
APB_SRC   := $(CORE_SRC) $(ROOT)/rtl/apb_uart.v
TT_SRC    := $(CORE_SRC) $(ROOT)/rtl/spi2apb.v $(ROOT)/rtl/tt_um_hust_apb_uart.v

APB_NL    := $(BUILD)/syn/apb_uart/apb_uart.nl.v
TT_NL     := $(BUILD)/syn/tt_um_hust_apb_uart/tt_um_hust_apb_uart.nl.v
TT_PNR_NL := $(RUN)/final/nl/tt_um_hust_apb_uart.nl.v

export PDK_ROOT PDK

.PHONY: all lint synth sta_pre sta_post lec_syn lec_pnr harden metrics regress clean

all: lint synth

# ---- G2: lint + latch -------------------------------------------------------
lint:
	mkdir -p $(BUILD)/lint
	$(VERILATOR) --lint-only -Wall --top-module apb_uart $(APB_SRC) 2>&1 | tee $(BUILD)/lint/apb_uart.log
	$(VERILATOR) --lint-only -Wall --top-module tt_um_hust_apb_uart $(TT_SRC) 2>&1 | tee $(BUILD)/lint/tt_um.log
	@! grep -h "%Warning\|%Error" $(BUILD)/lint/*.log && echo "LINT PASS: 0 %Warning"

# ---- G4: netlist Yosys ------------------------------------------------------
synth:
	YOSYS=$(YOSYS) LIB_TT=$(LIB_TT) EXCLUDE_FILES="$(SCLCFG)/no_synth.cells $(SCLCFG)/drc_exclude.cells" \
	  bash synth/synth.sh apb_uart $(BUILD)/syn/apb_uart $(APB_SRC)
	YOSYS=$(YOSYS) LIB_TT=$(LIB_TT) EXCLUDE_FILES="$(SCLCFG)/no_synth.cells $(SCLCFG)/drc_exclude.cells" \
	  bash synth/synth.sh tt_um_hust_apb_uart $(BUILD)/syn/tt_um_hust_apb_uart $(TT_SRC)

# ---- G6: STA trước layout, 3 corner x 2 top --------------------------------
define sta_run
	TOP=$(1) NETLIST=$(2) SDC=$(3) LIB=$(4) CORNER=$(5) OUT=$(BUILD)/sta/$(1)/$(5) \
	OPENLANE_SDC_IDEAL_CLOCKS=$(6) SPEF=$(7) \
	  $(STA) -no_init -no_splash -exit sta/sta.tcl
endef

sta_pre: synth
	$(call sta_run,apb_uart,$(APB_NL),constraints/apb_uart.sdc,$(LIB_TT),tt,1,)
	$(call sta_run,apb_uart,$(APB_NL),constraints/apb_uart.sdc,$(LIB_SS),ss,1,)
	$(call sta_run,apb_uart,$(APB_NL),constraints/apb_uart.sdc,$(LIB_FF),ff,1,)
	$(call sta_run,tt_um_hust_apb_uart,$(TT_NL),constraints/tt_um_hust_apb_uart.sdc,$(LIB_TT),tt,1,)
	$(call sta_run,tt_um_hust_apb_uart,$(TT_NL),constraints/tt_um_hust_apb_uart.sdc,$(LIB_SS),ss,1,)
	$(call sta_run,tt_um_hust_apb_uart,$(TT_NL),constraints/tt_um_hust_apb_uart.sdc,$(LIB_FF),ff,1,)
	@for f in $(BUILD)/sta/*/*/summary.rpt; do echo "== $$f"; cat $$f; done

# Kiểm tra chéo STA sau route (LibreLane đã tự làm 9 corner; xem `make metrics`)
SPEF_NOM := $(RUN)/final/spef/nom/tt_um_hust_apb_uart.nom.spef
sta_post:
	$(call sta_run,tt_um_hust_apb_uart,$(TT_PNR_NL),constraints/tt_um_hust_apb_uart.sdc,$(LIB_SS),ss_post,0,$(SPEF_NOM))
	$(call sta_run,tt_um_hust_apb_uart,$(TT_PNR_NL),constraints/tt_um_hust_apb_uart.sdc,$(LIB_FF),ff_post,0,$(SPEF_NOM))

# ---- G6: LEC ---------------------------------------------------------------
lec_syn: synth
	bash lec/run_eqy.sh apb_uart $(APB_NL) $(BUILD)/lec/apb_uart_syn $(APB_SRC)
	bash lec/run_eqy.sh tt_um_hust_apb_uart $(TT_NL) $(BUILD)/lec/tt_um_syn $(TT_SRC)

lec_pnr:
	bash lec/run_eqy.sh tt_um_hust_apb_uart $(TT_PNR_NL) $(BUILD)/lec/tt_um_pnr $(TT_SRC)

# ---- G7: harden giống GitHub Actions của TT ---------------------------------
# Cần tt-support-tools ở $(ROOT)/tt (git clone -b ttsky26e https://github.com/TinyTapeout/tt-support-tools tt)
harden:
	cd $(ROOT) && ./tt/tt_tool.py --create-user-config && ./tt/tt_tool.py --harden --no-docker

metrics:
	python3 signoff/collect_metrics.py $(RUN) --md $(BUILD)/metrics.md

# ---- vòng hồi quy sau mỗi lần sửa RTL (T07) --------------------------------
regress: lint synth lec_syn harden metrics

clean:
	rm -rf $(BUILD)
