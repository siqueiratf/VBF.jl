include $(dir $(abspath $(lastword $(MAKEFILE_LIST))))../../paper.mk


.PHONY: help test report proposition2 theorem9 table5 table6 \
        theorem7 theorem10 theorem11 clean_results

# Overridable parameters
max_n        ?= 8
save_results ?= false
seed         ?= 42
full_search  ?= false

default: help

test:
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/test/runtests.jl

report:
	@echo "ROOT=$(ROOT)"
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "report.jl")); \
	   paper_report(; save_results=$(save_results), full_search=$(full_search))'

proposition2:
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "proposition2.jl")); \
	   print_header(); proposition2_report(; max_n=$(max_n), save_results=$(save_results))'

theorem9:
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "theorem9.jl")); \
	   print_header(); theorem9_report(; save_results=$(save_results))'

table5:
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "table5.jl")); \
	   print_header(); table5_report(; save_results=$(save_results))'

table6:
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "table6.jl")); \
	   print_header(); table6_report(; save_results=$(save_results))'

theorem7:
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "theorem7.jl")); \
	   print_header(); theorem7_report(; full_search=$(full_search), save_results=$(save_results))'

theorem10:
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "theorem10.jl")); \
	   print_header(); theorem10_report(; save_results=$(save_results))'

theorem11:
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "theorem11.jl")); \
	   print_header(); theorem11_report(; save_results=$(save_results))'

clean_results:
	rm -rf "$(MAKEFILE_DIR)/results"

help:
	@echo 'Edel & Pott (2009) — A new APN function which is not quadratic'
	@echo ''
	@echo 'Targets:'
	@echo '  proposition2   Prop 2: x^3+tr(x^9) APN for all n (demo 2..max_n)'
	@echo '  theorem9       Thm 9: switching APN iff criterion (2.3 -> 2.11)'
	@echo '  table5         Table 5: n=6 catalogue — APN + algebraic degree'
	@echo '  table6         Table 6: n=6 invariants — Gamma/Delta-rank + Walsh'
	@echo '  theorem7       Thm 7 + Cor 8: Delta-rank crookedness bound'
	@echo '  theorem10      Thm 10: multiplier-group divisibility (published |M|)'
	@echo '  theorem11      Thm 11: the new non-quadratic APN (eq. 9)'
	@echo '  report         Fast aggregate report (full n=6 sweep, seconds)'
	@echo '  test           Run the test suite'
	@echo '  clean_results  Remove generated files under results/'
	@echo ''
	@echo 'Parameters:'
	@echo '  max_n=$(max_n)             (Proposition 2 upper dimension)'
	@echo '  full_search=$(full_search)  (true adds n=7 Corollary-8 Kasami ranks)'
	@echo '  save_results=$(save_results)  (true writes to results/)'
	@echo '  seed=$(seed)'
