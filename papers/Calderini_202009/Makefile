JULIA ?= julia
MAKEFILE_DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
ROOT := $(abspath $(MAKEFILE_DIR)/../..)
JULIA_PROJECT := --project=$(ROOT)

.PHONY: help test report section3 section4 section5 section6 clean_results

default: help

test:
	$(JULIA) $(JULIA_PROJECT) -e 'using Pkg; Pkg.instantiate()'
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/tests/runtests.jl

report:
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "report.jl")); paper_report()'

section3:
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "section3.jl")); section3_report()'

section4:
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "section4.jl")); section4_report()'

section5:
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "section5.jl")); section5_report()'

section6:
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "section6.jl")); section6_report()'

clean_results:
	rm -rf "$(MAKEFILE_DIR)/results"

help:
	@echo 'Calderini (2020) — On the EA-classes of known APN functions in small dimensions'
	@echo 'Cryptography and Communications 12:821-840'
	@echo ''
	@echo 'Targets:'
	@echo '  section3   Observation 1, Corollary 1, Propositions (n=4,5)'
	@echo '  section4   C1..C4 code matrix dimensions, Theorem 5 (stated), Theorem 6 demo'
	@echo '  section5   Table 1 catalog mapping, Section 5.1 Kim/Dillon analysis'
	@echo '  section6   Theorem 7 (n=5,6), Theorem 8 (n=5)'
	@echo '  report     Full aggregate report (all bounded checks)'
	@echo '  test       Run test suite'
	@echo ''
	@echo 'Scope: EXACT: Obs1, Cor1, C1..C4 dims, Sec5.1, Thm7/8.'
	@echo '       LOADED: Table 1 EA-class counts (requires MAGMA).'
	@echo '       OUT-SCOPE: Tables 2/3/4 (n>=7 Walsh-zero enum too slow).'
