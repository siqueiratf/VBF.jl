JULIA ?= julia

MAKEFILE_DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
ROOT := $(abspath $(MAKEFILE_DIR)/../../..)
JULIA_PROJECT := --project=$(ROOT)

.PHONY: help test report proposition2 section4 section5 table3 clean_results

limit        ?= 2147483647
sample_size  ?= 25
save_results ?= false
seed         ?= 42
full_search  ?= false

default: help

test:
	$(JULIA) $(JULIA_PROJECT) -e 'using Pkg; Pkg.instantiate()'
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/test/runtests.jl

proposition2:
	@echo "ROOT=$(ROOT)"
	@echo "§3 Secondary approach / Proposition 2 (save_results=$(save_results))"
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "proposition2.jl")); \
	   print_header(); section3_report(; save_results=$(save_results))'

section4:
	@echo "ROOT=$(ROOT)"
	@echo "§4 Cyclic approach + new n=7 function (save_results=$(save_results))"
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "section4.jl")); \
	   print_header(); section4_report(; save_results=$(save_results))'

section5:
	@echo "ROOT=$(ROOT)"
	@echo "§5 Classification data for n=7 (save_results=$(save_results))"
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "section5.jl")); \
	   print_header(); section5_report(; save_results=$(save_results))'

table3:
	@echo "ROOT=$(ROOT)"
	@echo "§6 Table 3 stacked APN examples (save_results=$(save_results))"
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "table3.jl")); \
	   print_header(); table3_report(; save_results=$(save_results))'

report:
	@echo "ROOT=$(ROOT)"
	@echo "Running full paper report (save_results=$(save_results))"
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/report.jl

clean_results:
	rm -rf "$(MAKEFILE_DIR)/results"

help:
	@echo 'Kalgin & Idrisova (2020) — The classification of quadratic APN functions in 7 variables'
	@echo ''
	@echo 'Targets:'
	@echo '  proposition2   §3 Secondary APN extension approach (Proposition 2)'
	@echo '  section4       §4 Cyclic matrix T + verify new n=7 APN function'
	@echo '  section5       §5 Five second-row cases, 488 CCZ-class data'
	@echo '  table3         §6 Table 3 stacked APN function examples (n=4,5,6)'
	@echo '  report         Full paper report'
	@echo '  test           Run all tests'
	@echo '  clean_results  Remove generated files under results/'
	@echo ''
	@echo 'Parameters (override with make target param=value):'
	@echo '  limit=$(limit)'
	@echo '  save_results=$(save_results)  (true writes to results/)'
	@echo '  seed=$(seed)'
	@echo '  full_search=$(full_search)    (true for exhaustive n=6 cyclic search)'
