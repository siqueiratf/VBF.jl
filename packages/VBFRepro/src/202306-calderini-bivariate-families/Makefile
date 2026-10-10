include $(dir $(abspath $(lastword $(MAKEFILE_LIST))))../paper.mk

.PHONY: help test report theorem3 theorem4 theorem5 section4_1 table3 remark1 clean_results

full_search ?= false

default: help

test:
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/test/runtests.jl

report:
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/report.jl

theorem3:
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/theorem3.jl

theorem4:
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/theorem4.jl

theorem5:
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/theorem5.jl

section4_1:
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "section4_1.jl")); \
	   paper_banner(); section4_1_report(full_search=true)'

table3:
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/table3.jl

remark1:
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/remark1.jl

clean_results:
	rm -rf "$(MAKEFILE_DIR)/results"

help:
	@echo 'Paper: Calderini_202306 — Extending two families of bivariate APN functions'
	@echo 'Targets: test  report  theorem3  theorem4  theorem5  section4_1  table3  remark1  clean_results'
	@echo 'Params:  full_search (default false; true adds n=12 N_F, Table 3 rows, Remark 1)'
	@echo 'Slow:    table3 ~10 min (14+ nonbent signatures at n=12); remark1 ~minutes (CCZ)'
