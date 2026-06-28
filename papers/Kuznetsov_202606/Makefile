JULIA ?= julia
MAKEFILE_DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
ROOT := $(abspath $(MAKEFILE_DIR)/../..)
JULIA_PROJECT := --project=$(ROOT)

.PHONY: help test report section4 algorithm1 theorem4 table2 table3 clean_results

# Overridable parameters
sample_size ?= 100
seed        ?= 42

default: help

test:
	$(JULIA) $(JULIA_PROJECT) -e 'using Pkg; Pkg.instantiate()'
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/test/runtests.jl

report:
	SAMPLE_SIZE=$(sample_size) SEED=$(seed) \
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/report.jl

section4:
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "section4.jl")); section4_report()'

algorithm1:
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "algorithm1.jl")); \
	   algorithm1_report(stdout; sample_size=$(sample_size), seed=$(seed))'

theorem4:
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "theorem4.jl")); theorem4_report()'

table2:
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "table2.jl")); table2_report()'

table3:
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "table3.jl")); table3_report()'

clean_results:
	rm -rf "$(MAKEFILE_DIR)/results"

help:
	@echo 'Paper: Kuznetsov (2026) — Quadratic APN Functions via Gröbner Basis Search'
	@echo 'Targets:  test  report  section4  algorithm1  theorem4  table2  table3  clean_results'
	@echo 'Params:   sample_size=$(sample_size)  seed=$(seed)'
