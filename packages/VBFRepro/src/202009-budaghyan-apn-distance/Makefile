include $(dir $(abspath $(lastword $(MAKEFILE_LIST))))../paper.mk

.PHONY: help test report proposition2 algorithm1 corollary2 proposition6 table2 table3 section5 clean_results

default: help

test:
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/test/runtests.jl

report:
	$(JULIA) $(JULIA_PROJECT) -e \
	  'using Dates; include(joinpath("$(MAKEFILE_DIR)", "report.jl")); paper_report()'

proposition2:
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "proposition2.jl")); proposition2_report()'

algorithm1:
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "algorithm1.jl")); algorithm1_report(); algorithm1_examples_report()'

corollary2:
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "corollary2.jl")); corollary2_report()'

proposition6:
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "proposition6.jl")); proposition6_report()'

table2:
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "table2.jl")); print_header(); table2_report()'

table3:
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "table3.jl")); print_header(); table3_report()'

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
	@echo '  algorithm1     Algorithm 1: shift domain filtering + Sec IV-A examples (a),(b),(c)'
	@echo '  corollary2     Cor 2 + Props 3/4/5: lower bound and invariance'
	@echo '  proposition6   Prop 6 + Table I: Gold x^3 formula + tightness witnesses'
	@echo '  table2         Table II: m_F, bounds, single-shift distance (n=4,5,6,7)'
	@echo '  table3         Table III: F_2^5 EA-representatives'
	@echo '  section5       Section V: single shift linear system (APN and non-APN F)'
	@echo '  report         Full aggregate report (all bounded checks)'
	@echo '  test           Run test suite'
	@echo '  clean_results  Remove results/'
	@echo ''
	@echo 'Scope: Exact: Props 2-6, Alg 1 + examples, Tables I/III, Table II (n=4,5,6.1,7),'
	@echo '              Section V (incl. the non-APN half and the exhaustive min distance).'
	@echo '       Blocked: Table II n=6 (except 1.1) and n=8 (Edel-Pott reps not in catalog);'
	@echo '                Table III BCP-1/BCP-2 rows (not in VBF nor the catalog).'
