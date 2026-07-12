JULIA ?= julia

MAKEFILE_DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
ROOT := $(abspath $(MAKEFILE_DIR)/../..)
JULIA_PROJECT := --project=$(ROOT)

.PHONY: help test theorem1 remark2 remark3 report clean_results

max_n ?= 100

default: help

test:
	$(JULIA) $(JULIA_PROJECT) -e 'using Pkg; Pkg.instantiate()'
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/test/runtests.jl

theorem1:
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "theorem1.jl")); \
	   print_header(); theorem1_report(; max_n=$(max_n))'

remark2:
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "remark2.jl")); \
	   print_header(); remark2_report(; max_n=$(max_n))'

remark3:
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "remark3.jl")); \
	   print_header(); remark3_report()'

report:
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/report.jl

clean_results:
	rm -rf "$(MAKEFILE_DIR)/results"

help:
	@echo 'Kaleyski, Nesheim, Stănică (2022) — A doubly-infinite family of 0-APN monomials'
	@echo ''
	@echo 'Targets:'
	@echo '  theorem1    Theorem 1 verification + paper bug demo'
	@echo '  remark2     Remark 2 computational experiments'
	@echo '  remark3     Remark 3 Gold/Inverse special cases'
	@echo '  report      Full paper report'
	@echo '  test        Run all tests'
	@echo '  clean_results  Remove generated files under results/'
	@echo ''
	@echo 'Parameters:'
	@echo '  max_n=$(max_n)    Maximum dimension for 0-APN checks'
