include $(dir $(abspath $(lastword $(MAKEFILE_LIST))))../../paper.mk

.PHONY: help test report clean_results theorem1 theorem2 theorem3 theorem4 theorem5 theorem6 example1 table1 table2 proposition5

limit          ?= 2147483647
save_results   ?= false
max_evaluations ?= 2147483647
timeout_seconds ?= 60

default: help

test:
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/test/runtests.jl

report:
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/report.jl

clean_results:
	rm -rf "$(MAKEFILE_DIR)/results"

theorem1:
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "theorem1.jl")); \
	   print_header(); theorem1_report()'

theorem2:
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "theorem2.jl")); \
	   print_header(); theorem2_report()'

theorem3:
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "theorem3.jl")); \
	   print_header(); theorem3_report()'

theorem4:
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "theorem4.jl")); \
	   print_header(); theorem4_report()'

theorem5:
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "theorem5.jl")); \
	   print_header(); theorem5_report()'

theorem6:
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "theorem6.jl")); \
	   print_header(); theorem6_report()'

example1:
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "example1.jl")); \
	   print_header(); example1_report()'

table1:
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "table1.jl")); \
	   print_header(); table1_report()'

table2:
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "table2.jl")); \
	   print_header(); table2_report()'

proposition5:
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "proposition5.jl")); \
	   proposition5_family_report(max_evaluations=$(max_evaluations),timeout_seconds=$(timeout_seconds),save_results=$(save_results))'

help:
	@echo 'Paper: Zha_201401 — Differentially 4-uniform permutations from inverse'
	@echo 'Targets: test  report  theorem1..6  example1  table1  table2  proposition5  clean_results'
	@echo 'Params:  limit  save_results  max_evaluations  timeout_seconds'
