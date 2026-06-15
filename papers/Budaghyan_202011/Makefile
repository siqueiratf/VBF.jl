JULIA ?= julia

MAKEFILE_DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
ROOT := $(abspath $(MAKEFILE_DIR)/../..)
JULIA_PROJECT := --project=$(ROOT)

.PHONY: help test report observation1 proposition1 theorem4 table3 clean_results

n ?= 10

default: help

test:
	$(JULIA) $(JULIA_PROJECT) -e 'using Pkg; Pkg.instantiate()'
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/test/runtests.jl

report:
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/report.jl

observation1:
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "helpers.jl")); \
	   include(joinpath("$(MAKEFILE_DIR)", "observation1.jl")); \
	   print_header(); observation1_report()'

proposition1:
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "helpers.jl")); \
	   include(joinpath("$(MAKEFILE_DIR)", "proposition1.jl")); \
	   print_header(); proposition1_report()'

theorem4:
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "helpers.jl")); \
	   include(joinpath("$(MAKEFILE_DIR)", "theorem4.jl")); \
	   print_header(); theorem4_report(; n=$(n))'

table3:
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "helpers.jl")); \
	   include(joinpath("$(MAKEFILE_DIR)", "table3.jl")); \
	   print_header(); table3_report()'

clean_results:
	rm -rf "$(MAKEFILE_DIR)/results"

help:
	@echo 'Budaghyan, Helleseth, Kaleyski (2020) — A New Family of APN Quadrinomials'
	@echo 'IEEE Trans. Inf. Theory 66(11):7081–7087'
	@echo ''
	@echo 'Targets:'
	@echo '  test          Run all tests'
	@echo '  report        Full paper report'
	@echo '  observation1  Verify C_3, C_7 APN over GF(2^10)'
	@echo '  proposition1  Verify system E_i ↔ APN criterion for all i ∈ 1..9'
	@echo '  theorem4      Verify four Theorem 4 i-values give APN (param: n=10)'
	@echo '  table3        Table III: Walsh spectra + EA-mugshot comparison'
	@echo ''
	@echo 'Parameters:'
	@echo '  n=$(n)   (dimension for theorem4 target)'
