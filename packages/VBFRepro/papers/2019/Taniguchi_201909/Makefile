include $(dir $(abspath $(lastword $(MAKEFILE_LIST))))../../paper.mk

.PHONY: help test report theorem3 theorem4 fact section2 theorem5 clean_results

default: help

test:
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/tests/runtests.jl

report:
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/report.jl

theorem3:
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/theorem3.jl

theorem4:
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/theorem4.jl

fact:
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/fact_helleseth_kholosha.jl

section2:
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/section2_carlet_zhou_pott.jl

theorem5:
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/theorem5_presemifield.jl

clean_results:
	rm -rf "$(MAKEFILE_DIR)/results"

help:
	@echo 'Paper: Taniguchi_201909 — On some quadratic APN functions'
	@echo 'Targets: test  report  theorem3  theorem4  fact  section2  theorem5  clean_results'
