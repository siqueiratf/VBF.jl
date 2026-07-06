JULIA ?= julia
MAKEFILE_DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
ROOT := $(abspath $(MAKEFILE_DIR)/../..)
JULIA_PROJECT := --project=$(ROOT)

.PHONY: help test report section2 section3 section4 clean_results

default: help

test:
	$(JULIA) $(JULIA_PROJECT) -e 'using Pkg; Pkg.instantiate()'
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/test/runtests.jl

report:
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/report.jl

section2:
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "section2.jl")); section2_report()'

section3:
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "section3.jl")); section3_report()'

section4:
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "section4.jl")); section4_report()'

clean_results:
	rm -rf "$(MAKEFILE_DIR)/results"

help:
	@echo 'Paper: Bracken, Tan, Tan (2012) — Binomial Differentially 4 Uniform Permutations'
	@echo 'Targets: test  report  section2  section3  section4  clean_results'
	@echo 'Notes:'
	@echo '  - section2 : permutation check (n=6,12,15)'
	@echo '  - section3 : differential uniformity (n=6 fast; n=15 ~1 s, O(2^n) mem)'
	@echo '  - section4 : Walsh spectrum bound (n=6, n=15)'
	@echo '  - n=6 (k=2,s=4): degenerate monomial; n=15 (k=5,s=1,t=1): first non-degenerate APN'
	@echo '  - Theorem 1.1 t=2 non-degenerate (n=30) is out-of-scope'
