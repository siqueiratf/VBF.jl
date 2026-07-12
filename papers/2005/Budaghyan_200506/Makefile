JULIA ?= julia
MAKEFILE_DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
ROOT := $(abspath $(MAKEFILE_DIR)/../../..)
JULIA_PROJECT := --project=$(ROOT)

.PHONY: help test report theorem1 remark4 theorem2 theorem3 theorem4 clean_results

sample_size  ?= 500
full_search  ?= false
seed         ?= 42

default: help

test:
	$(JULIA) $(JULIA_PROJECT) -e 'using Pkg; Pkg.instantiate()'
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/test/runtests.jl

report:
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/report.jl

theorem1:
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/theorem1.jl

remark4:
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "remark4.jl")); \
	   remark4_check(; sample_size=$(sample_size), full_search=$(full_search), seed=$(seed), io=stdout)'

theorem2:
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/theorem2.jl

theorem3:
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/theorem3.jl

theorem4:
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/theorem4.jl

clean_results:
	rm -rf "$(MAKEFILE_DIR)/results"

help:
	@echo 'Paper: Budaghyan, Carlet, Pott (2006) — New Classes of AB and APN Polynomials'
	@echo 'Targets: test  report  theorem1  remark4  theorem2  theorem3  theorem4  clean_results'
	@echo 'Params:  sample_size=$(sample_size)  full_search=$(full_search)  seed=$(seed)'
	@echo 'Note: remark4 full_search=true runs all 2^25 linear maps (slow)'
