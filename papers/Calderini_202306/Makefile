JULIA ?= julia
MAKEFILE_DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
ROOT := $(abspath $(MAKEFILE_DIR)/../..)
JULIA_PROJECT := --project=$(ROOT)

.PHONY: help test report theorem3 theorem4 section4_1 clean_results

full_search ?= false

default: help

test:
	$(JULIA) $(JULIA_PROJECT) -e 'using Pkg; Pkg.instantiate()'
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/test/runtests.jl

report:
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/report.jl

theorem3:
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/theorem3.jl

theorem4:
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/theorem4.jl

section4_1:
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "section4_1.jl")); \
	   paper_banner(); section4_1_report(full_search=true)'

clean_results:
	rm -rf "$(MAKEFILE_DIR)/results"

help:
	@echo 'Paper: Calderini_202306 — Extending two families of bivariate APN functions'
	@echo 'Targets: test  report  theorem3  theorem4  section4_1  clean_results'
	@echo 'Params:  full_search (default false, set true for n=12 N_F computation)'
