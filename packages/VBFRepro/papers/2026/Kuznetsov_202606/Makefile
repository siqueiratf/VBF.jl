include $(dir $(abspath $(lastword $(MAKEFILE_LIST))))../../paper.mk

.PHONY: help test report section4 algorithm1 theorem4 theorem6 theorem6_exact table2 table3 phase2 novelty clean_results

# Overridable parameters
sample_size ?= 100
seed        ?= 42

default: help

test:
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/test/runtests.jl

report:
	SAMPLE_SIZE=$(sample_size) SEED=$(seed) \
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/report.jl

section4:
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "section4.jl")); section4_report()'

algorithm1:
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "algorithm1.jl")); \
	   algorithm1_report(stdout; sample_size=$(sample_size), seed=$(seed))'

theorem4:
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "theorem4.jl")); theorem4_report()'

theorem6:
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "theorem6.jl")); theorem6_report()'

theorem6_exact:
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "theorem6_exact.jl")); theorem6_exact_report()'

table2:
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "table2.jl")); table2_report()'

table3:
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "table3.jl")); table3_report()'

phase2:
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "report.jl")); phase2_report()'

# Coverage-aware named-source signature report; missing sources are inconclusive.
novelty:
	$(JULIA) $(JULIA_PROJECT) -t auto $(MAKEFILE_DIR)/novelty_report.jl

clean_results:
	rm -rf "$(MAKEFILE_DIR)/results"

help:
	@echo 'Paper: Kuznetsov (2026) — Quadratic APN Functions via Gröbner Basis Search'
	@echo 'Paper targets:  test  report  section4  algorithm1  theorem4  theorem6  table2  table3  phase2  novelty  clean_results'
	@echo '                (theorem6 audits the Main result against the σ-index oracle)'
	@echo 'Params:         sample_size=$(sample_size)  seed=$(seed)'
	@echo 'theorem6_exact replays EA graph witnesses against the tracked Edel-Pott corpus.'
