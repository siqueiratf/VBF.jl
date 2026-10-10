include $(dir $(abspath $(lastword $(MAKEFILE_LIST))))../paper.mk

.PHONY: help test report proposition1 proposition4 algorithm1 algorithm2 algorithm3 section5 clean_results

n_values     ?= [5,6]
limit        ?= 2147483647
save_results ?= false

default: help

test:
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/test/runtests.jl

report:
	$(JULIA) $(JULIA_PROJECT) -e \
	  'using Dates; include(joinpath("$(MAKEFILE_DIR)", "report.jl")); paper_report()'

proposition1:
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "proposition1.jl")); \
	   print_header(); proposition1_report()'

proposition4:
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "proposition4.jl")); \
	   print_header(); proposition4_report()'

algorithm1:
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "algorithm1.jl")); \
	   print_header(); algorithm1_report()'

algorithm2:
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "algorithm2.jl")); \
	   print_header(); algorithm2_report()'

algorithm3:
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "algorithm3.jl")); \
	   print_header(); algorithm3_report()'

section5:
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "section5.jl")); \
	   section5_report(; n_values=$(n_values), limit=$(limit))'

clean_results:
	rm -rf "$(MAKEFILE_DIR)/results"

help:
	@echo 'Kaleyski (2022) — Deciding EA-equivalence via invariants'
	@echo ''
	@echo 'Targets:'
	@echo '  proposition1   Prop 1/Cor 3: sigma multiset EA-invariance'
	@echo '  proposition4   Prop 4: Walsh formula == direct enumeration'
	@echo '  algorithm1     Algorithm 1: partition by sigma_4 multiplicities'
	@echo '  algorithm2     Algorithm 2: outer permutation enumeration (counts)'
	@echo '  algorithm3     Algorithm 3: inner permutation recovery'
	@echo '  section5       Section 5: partition stats for catalog APN'
	@echo '  report         Fast aggregate report (all claims, bounded)'
	@echo '  test           Run test suite (fast, n ≤ 6)'
	@echo '  clean_results  Remove results/'
	@echo ''
	@echo 'Parameters (override with make target param=value):'
	@echo '  n_values=$(n_values)   list of n to survey in section5'
	@echo '  limit=$(limit)         max functions per n in section5'
	@echo '  save_results=$(save_results)   write TOML to results/'
	@echo ''
	@echo 'Note: Table 1 timing and Table 2 are excluded (timing experiments).'
