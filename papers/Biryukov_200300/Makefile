JULIA ?= julia
MAKEFILE_DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
ROOT := $(abspath $(MAKEFILE_DIR)/../..)
JULIA_PROJECT := --project=$(ROOT)

.PHONY: help test report section2 section3 section4 section5 section7 rijndael_2040 clean_results

full_search ?= false

default: help

test:
	$(JULIA) $(JULIA_PROJECT) -e 'using Pkg; Pkg.instantiate()'
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/tests/runtests.jl

report:
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include("$(MAKEFILE_DIR)report.jl"); paper_report(; full_search = $(full_search))'

section2:
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include("$(MAKEFILE_DIR)section2.jl"); section2_report()'

section3:
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include("$(MAKEFILE_DIR)section3.jl"); section3_report()'

section4:
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include("$(MAKEFILE_DIR)section4.jl"); section4_report(; full_search = $(full_search))'

section5:
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include("$(MAKEFILE_DIR)section5.jl"); section5_report()'

section7:
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include("$(MAKEFILE_DIR)section7.jl"); section7_report(; full_search = $(full_search))'

rijndael_2040:
	@echo "Running Rijndael 2040 self-equivalence count (expensive, O(2^16) LE searches)..."
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include("$(MAKEFILE_DIR)section4.jl"); section4_report(; full_search = true)'

clean_results:
	rm -rf "$(MAKEFILE_DIR)results"

help:
	@echo 'Paper: Biryukov et al. (2003) — A Toolbox for Cryptanalysis: Linear and Affine Equivalence Algorithms'
	@echo 'Targets: test  report  section2  section3  section4  section5  section7  rijndael_2040  clean_results'
	@echo 'Params:  full_search=false   (set true to compute Rijndael 2040 self-equivalences)'
