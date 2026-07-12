JULIA ?= julia
MAKEFILE_DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
ROOT := $(abspath $(MAKEFILE_DIR)/../..)
JULIA_PROJECT := --project=$(ROOT)

.PHONY: help test report theorem2 proposition1 algorithm1 table1 table2 table3 table4 clean_results

max_evaluations ?= 16777216

default: help

test:
	$(JULIA) $(JULIA_PROJECT) -e 'using Pkg; Pkg.instantiate()'
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/test/runtests.jl

report:
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/report.jl

theorem2:
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include("$(MAKEFILE_DIR)/theorem2.jl"); theorem2_report()'

proposition1:
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include("$(MAKEFILE_DIR)/proposition1.jl"); proposition1_report()'

algorithm1:
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include("$(MAKEFILE_DIR)/algorithm1.jl"); algorithm1_report(; max_evaluations=$(max_evaluations))'

table1:
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include("$(MAKEFILE_DIR)/table1.jl"); table1_report()'

table2:
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include("$(MAKEFILE_DIR)/table2.jl"); table2_report()'

table3:
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include("$(MAKEFILE_DIR)/table3.jl"); table3_report()'

table4:
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include("$(MAKEFILE_DIR)/table4.jl"); table4_report()'

clean_results:
	rm -rf "$(MAKEFILE_DIR)/results"

help:
	@echo 'Paper: Yu, Kaleyski, Budaghyan, Li (2020)'
	@echo '  Classification of quadratic APN functions with F₂ coefficients, n≤9'
	@echo 'Targets: test  report  theorem2  proposition1  algorithm1'
	@echo '         table1  table2  table3  table4  clean_results'
	@echo 'Params:  max_evaluations (default: 2^24)'
