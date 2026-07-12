JULIA ?= julia
MAKEFILE_DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
ROOT := $(abspath $(MAKEFILE_DIR)/../..)
JULIA_PROJECT := --project=$(ROOT)

.PHONY: help test report proposition2 algorithm1 corollary2 proposition6 table2 section5 clean_results

default: help

test:
	$(JULIA) $(JULIA_PROJECT) -e 'using Pkg; Pkg.instantiate()'
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/test/runtests.jl

report:
	$(JULIA) $(JULIA_PROJECT) -e \
	  'using Dates; include(joinpath("$(MAKEFILE_DIR)", "report.jl")); paper_report()'

proposition2:
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "proposition2.jl")); proposition2_report()'

algorithm1:
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "algorithm1.jl")); algorithm1_report()'

corollary2:
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "corollary2.jl")); corollary2_report()'

proposition6:
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "proposition6.jl")); proposition6_report()'

table2:
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "table2.jl")); print_header(); table2_report()'

section5:
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "section5.jl")); print_header(); section5_report()'

clean_results:
	rm -rf "$(MAKEFILE_DIR)/results"

help:
	@echo 'Budaghyan, Carlet, Helleseth, Kaleyski (2020) — On the Distance Between APN Functions'
	@echo ''
	@echo 'Targets:'
	@echo '  proposition2   Prop 2: APN conditions for K-point modification'
	@echo '  algorithm1     Algorithm 1: shift domain filtering'
	@echo '  corollary2     Cor 2 + Props 3/4/5: lower bound and invariance'
	@echo '  proposition6   Prop 6 + Table I: Gold x^3 formula'
	@echo '  table2         Table II: switching class m_F values'
	@echo '  section5       Section V: single shift linear system'
	@echo '  report         Full aggregate report (all bounded checks)'
	@echo '  test           Run test suite'
	@echo '  clean_results  Remove results/'
	@echo ''
	@echo 'Scope: Exact: Props 2-6, Alg 1, Table I, Section V.'
	@echo '       Bounded: Table II (monomials; n=6 polynomial reps need VBFCatalog).'
	@echo '       Skipped: full n<=8 table, Table III distances, timing benchmarks.'
