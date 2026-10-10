include $(dir $(abspath $(lastword $(MAKEFILE_LIST))))../../paper.mk

.PHONY: help test report theorem17 table2 table1 conjecture21 conjecture22 clean_results

n_max_ddt     ?= 10
n_max_formula ?= 20
limit         ?= 2147483647
save_results  ?= false
full_search ?= false
max_evaluations ?= 2147483647
timeout_seconds ?= 60
pair_samples ?= 16
ns ?= [5,6,7,8]

default: help

test:
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/test/runtests.jl

report:
	$(JULIA) $(JULIA_PROJECT) -e \
	  'using Dates; include(joinpath("$(MAKEFILE_DIR)", "report.jl")); \
	   paper_report(; save_results=$(save_results))'

theorem17:
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "theorem17.jl")); \
	   print_header(); theorem17_demo()'

table2:
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "table2.jl")); \
	   print_header(); table2_report(; n_max_ddt=$(n_max_ddt), n_max_formula=$(n_max_formula))'

table1:
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "table1.jl")); \
	   print_header(); table1_report(; limit=$(limit))'

conjecture21:
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "conjecture21.jl")); \
	   print_header(); conjecture21_report()'

conjecture22:
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "conjecture22.jl")); \
	   print_header(); conjecture22_report(; ns=$(ns), limit=$(limit), full_search=$(full_search), max_evaluations=$(max_evaluations), timeout_seconds=$(timeout_seconds), pair_samples=$(pair_samples))'

clean_results:
	rm -rf "$(MAKEFILE_DIR)/results"

help:
	@echo 'Kaleyski (2019) — Changing APN functions at two points'
	@echo ''
	@echo 'Targets:'
	@echo '  theorem17    Theorem 17 characterization demo on Gold x^3 n=5..8'
	@echo '  table2       Table 2: formula (34) vs DDT for x^3'
	@echo '  table1       Table 1: S1/S2 for catalog APN functions n=5..8'
	@echo '  conjecture21 Conjecture 21: power APN share S1 with x^3'
	@echo '  conjecture22 Conjecture 22: no APN two-point swap in catalog n=5..8'
	@echo '  report       Fast aggregate report (all claims, bounded)'
	@echo '  test         Run test suite'
	@echo '  clean_results  Remove results/'
	@echo ''
	@echo 'Parameters (override with make target param=value):'
	@echo '  n_max_ddt=$(n_max_ddt)       max n for DDT verification in table2'
	@echo '  n_max_formula=$(n_max_formula)   max n for formula in table2'
	@echo '  limit=$(limit)   max functions per dimension in table1/conjecture22'
	@echo '  save_results=$(save_results)   write TOML to results/'
	@echo '  ns=$(ns)   dimensions for conjecture22 (Julia vector)'
