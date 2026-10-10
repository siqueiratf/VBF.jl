include $(dir $(abspath $(lastword $(MAKEFILE_LIST))))../../paper.mk


.PHONY: help test report theorem3_2 table3_1 theorem3_7 example4_2 prior_art clean_results

n            ?= 5
save_results ?= false
seed         ?= 42
full_search  ?= false
max_evaluations ?= 1048576
timeout_seconds ?= Inf

default: help

test:
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/test/runtests.jl

report:
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "report.jl")); \
	   paper_report(; save_results=$(save_results))'

theorem3_2:
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "theorem3_2.jl")); \
	   print_header(); theorem3_2_report(; n=$(n), full_search=$(full_search), max_evaluations=$(max_evaluations), timeout_seconds=$(timeout_seconds))'

table3_1:
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "table3_1.jl")); \
	   print_header(); table3_1_report()'

theorem3_7:
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "theorem3_7.jl")); \
	   print_header(); theorem3_7_report()'

example4_2:
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "example4_2.jl")); \
	   print_header(); example4_2_report()'

prior_art:
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/prior_art.jl

clean_results:
	rm -rf "$(MAKEFILE_DIR)/results"

help:
	@echo 'Taniguchi, Polujan, Pott, Arshad (2025)'
	@echo 'Changing APN functions on affine subspaces of small codimensions'
	@echo ''
	@echo 'Targets:'
	@echo '  theorem3_2    H-equiv characterization + Example 3.3 counting (params: n)'
	@echo '  table3_1      Table 3.1: 13 linearized polynomials, APN + EA-class'
	@echo '  theorem3_7    Theorem 3.7: exponential sum criterion on Table 3.1'
	@echo '  example4_2    Example 4.2: codim-2 APN on GF(2^8)'
	@echo '  report        Fast summary (no heavy searches)'
	@echo '  test          Run all tests'
	@echo '  clean_results Remove generated files under results/'
	@echo ''
	@echo 'Parameters (override with make target param=value):'
	@echo '  n=$(n)                (theorem3_2 dimension, default 5)'
	@echo '  save_results=$(save_results)  (true writes to results/)'
	@echo '  seed=$(seed)'
