JULIA ?= julia

MAKEFILE_DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
ROOT := $(abspath $(MAKEFILE_DIR)/../../..)
JULIA_PROJECT := --project=$(ROOT)

.PHONY: help test lemma2_1 theorem3_3 report clean_results

limit        ?= 2147483647
save_results ?= false
seed         ?= 42

default: help

test:
	$(JULIA) $(JULIA_PROJECT) -e 'using Pkg; Pkg.instantiate()'
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/test/runtests.jl

lemma2_1:
	@echo "ROOT=$(ROOT)"
	@echo "Lemma 2.1 — APN via subfield trace components (limit=$(limit))"
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "helpers.jl")); \
	   include(joinpath("$(MAKEFILE_DIR)", "lemma2_1.jl")); \
	   print_header(); lemma2_1_report(; m=5, a=2, b=2, limit=$(limit))'

theorem3_3:
	@echo "ROOT=$(ROOT)"
	@echo "Theorem 3.3 Case iii — F15 APN + mugshot comparison (save_results=$(save_results))"
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "helpers.jl")); \
	   include(joinpath("$(MAKEFILE_DIR)", "theorem3_3.jl")); \
	   print_header(); theorem3_3_report(; m_values=[5,7], a=2, b=2, save_results=$(save_results))'

report:
	@echo "ROOT=$(ROOT)"
	@echo "Running paper report (save_results=$(save_results))"
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "report.jl")); \
	   paper_report(; save_results=$(save_results))'

clean_results:
	rm -rf "$(MAKEFILE_DIR)/results"

help:
	@echo 'Zheng, Kan, Li, Peng, Tang (2022) — Constructing New APN Functions'
	@echo '  through Relative Trace Functions — arXiv:2101.11535v1'
	@echo ''
	@echo 'Targets:'
	@echo '  lemma2_1      Lemma 2.1: APN criterion via subfield trace components'
	@echo '  theorem3_3    Theorem 3.3 Case iii: F15 APN + CCZ-inequiv via mugshot'
	@echo '  report        Aggregate paper report (fast: n=10 DDT + n=14 streaming)'
	@echo '  test          Run all tests'
	@echo '  clean_results Remove generated files under results/'
	@echo ''
	@echo 'Parameters (override with make target param=value):'
	@echo '  limit=$(limit)            (lemma2_1: max u values to check)'
	@echo '  save_results=$(save_results)    (true writes to results/)'
