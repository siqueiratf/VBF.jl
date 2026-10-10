include $(dir $(abspath $(lastword $(MAKEFILE_LIST))))../paper.mk

.PHONY: help test report clean_results table7_full \
        proposition14 section3_2 proposition18 proposition22 corollary24 \
        proposition25 algorithm1 proposition35_36 section4_3 section4_4 section4_5

limit ?= 16
full_search ?= false
check_ortho ?= false
save_results ?= false
max_evaluations ?= 2147483647
timeout_seconds ?= 60

default: help

test:
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/test/runtests.jl

report:
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/report.jl

proposition14:
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/proposition14.jl

section3_2:
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/section3_2.jl

proposition18:
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/proposition18.jl

proposition22:
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/proposition22.jl

corollary24:
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/corollary24.jl

proposition25:
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/proposition25.jl

algorithm1:
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/algorithm1.jl

proposition35_36:
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/proposition35_36.jl

section4_3:
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/section4_3.jl

section4_4:
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/section4_4.jl

section4_5:
	$(JULIA) $(JULIA_PROJECT) -e 'include(joinpath("$(MAKEFILE_DIR)", "section4_5.jl")); section4_5_report(; limit=$(limit), full_search=$(full_search), check_ortho=$(check_ortho), max_evaluations=$(max_evaluations), timeout_seconds=$(timeout_seconds), save_results=$(save_results))'

table7_full:
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "section4_4.jl")); \
	   section4_4_report(; verify_min_ea = true)'

clean_results:
	rm -rf "$(MAKEFILE_DIR)/results"

help:
	@echo 'Paper: Canteaut–Couvreur–Perrin (2022) — Recovering or Testing EA Equivalence'
	@echo 'Targets: test  report  proposition14  section3_2  proposition18'
	@echo '         proposition22  corollary24  proposition25  algorithm1'
	@echo '         proposition35_36  section4_3  section4_4  clean_results'
	@echo '  table7_full — Table 7 min #EA sweep for all 13 Banff functions (~25-30 min)'
