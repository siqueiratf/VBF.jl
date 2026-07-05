JULIA ?= julia
MAKEFILE_DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
ROOT := $(abspath $(MAKEFILE_DIR)/../..)
JULIA_PROJECT := --project=$(ROOT)

.PHONY: help test report theorem3_1 theorem4_4 theorem5_1 theorem5_4 \
        theorem5_6 theorem6_2 section6_1 section6_1_deep theorem7_1 \
        theorem7_2 section7_example proposition7_5 clean_results

default: help

test:
	$(JULIA) $(JULIA_PROJECT) -e 'using Pkg; Pkg.instantiate()'
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/test/runtests.jl

report:
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/report.jl

theorem3_1:
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/theorem3_1.jl

theorem4_4:
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/theorem4_4.jl

theorem5_1:
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/theorem5_1.jl

theorem5_4:
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/theorem5_4.jl

theorem5_6:
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/theorem5_6.jl

theorem6_2:
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/theorem6_2.jl

section6_1:
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/section6_1.jl

# Section 6.1.2 aggregate n=10 sweep (est. 15-30 min)
section6_1_deep:
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "section6_1.jl")); \
	   print_header(); section6_1_report(full_search=true); section6_1_n12_report()'

theorem7_1:
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/theorem7_1.jl

theorem7_2:
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/theorem7_2.jl

section7_example:
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/section7_example.jl

proposition7_5:
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "proposition7_5.jl")); \
	   print_header(); proposition7_5_report(skip=false)'

clean_results:
	rm -rf "$(MAKEFILE_DIR)/results"

help:
	@echo 'Paper: Calderini-Budaghyan-Carlet (2021) — On Known APN and AB Constructions'
	@echo 'Targets: test  report  theorem3_1  theorem4_4  theorem5_1  theorem5_4'
	@echo '         theorem5_6  theorem6_2  section6_1  section6_1_deep  theorem7_1'
	@echo '         theorem7_2  section7_example  proposition7_5  clean_results'
