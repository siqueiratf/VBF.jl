include $(dir $(abspath $(lastword $(MAKEFILE_LIST))))../paper.mk

.PHONY: help test report theorem2 theorem4 proposition1 proposition2 theorem5 theorem6 remark3 clean_results

full_search ?= false

default: help

test:
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/test/runtests.jl

report:
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/report.jl

theorem2:
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/theorem2.jl

theorem4:
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/theorem4.jl

proposition1:
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/proposition1.jl

proposition2:
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/proposition2.jl

theorem5:
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/theorem5.jl

theorem6:
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/theorem6.jl

remark3:
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "remark3.jl")); \
	   remark3_report(; full_search=$(full_search), io=stdout)'

clean_results:
	rm -rf "$(MAKEFILE_DIR)/results"

help:
	@echo 'Paper: Li, Wang (2014) -- Differentially 4-Uniform Perms from Quadratic APN Perms'
	@echo 'Targets: test  report  theorem2  theorem4  proposition1  proposition2'
	@echo '         theorem5  theorem6  remark3  clean_results'
	@echo 'Params:  full_search=$(full_search)  (enable slow n=8 CCZ checks in remark3)'
