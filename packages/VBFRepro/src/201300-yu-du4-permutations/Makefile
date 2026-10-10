include $(dir $(abspath $(lastword $(MAKEFILE_LIST))))../paper.mk


.PHONY: help test report proposition1 proposition3 theorem1 clean_results

save_results ?= false
full_search  ?= true

default: help

test:
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/test/runtests.jl

report:
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "report.jl")); \
	   paper_report(; save_results=$(save_results))'

proposition1:
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "proposition1.jl")); \
	   print_header(); proposition1_report()'

proposition3:
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "proposition3.jl")); \
	   print_header(); proposition3_report()'

theorem1:
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "theorem1.jl")); \
	   print_header(); theorem1_report(; full_search=$(full_search))'

clean_results:
	rm -rf "$(MAKEFILE_DIR)/results"

help:
	@echo 'Yu, Wang, Li (2013)'
	@echo 'Constructing Differentially 4 Uniform Permutations from Known Ones'
	@echo ''
	@echo 'Targets:'
	@echo '  proposition1  APN swap + 1176 count (Dillon perm n=6)'
	@echo '  proposition3  I_{(0,v)} formula + δ characterization'
	@echo '  theorem1      Trace condition (n=4,6,8 exhaustive, ~11s)'
	@echo '  report        Full summary (all targets)'
	@echo '  test          Run all tests'
	@echo '  clean_results Remove generated files under results/'
	@echo ''
	@echo 'Parameters:'
	@echo '  save_results=$(save_results)'
	@echo '  full_search=$(full_search)'
