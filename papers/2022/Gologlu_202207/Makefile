JULIA ?= julia
MAKEFILE_DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
ROOT := $(abspath $(MAKEFILE_DIR)/../../..)
JULIA_PROJECT := --project=$(ROOT)

.PHONY: help test report theorem3_2 proposition3_4 table1 table2 clean_results

default: help

test:
	$(JULIA) $(JULIA_PROJECT) -e 'using Pkg; Pkg.instantiate()'
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/test/runtests.jl

report:
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/report.jl

full:
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/report.jl --full

theorem3_2:
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "theorem3_2.jl")); \
	   theorem3_2_report(; m_values=[3,5,7])'

proposition3_4:
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "proposition3_4.jl")); \
	   proposition3_4_report()'

table1:
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "table1.jl")); \
	   table1_report(; include_table3=true)'

table2:
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "table2.jl")); \
	   table2_report(; i_values=[1,2,3], include_taniguchi=true)'

clean_results:
	rm -rf "$(MAKEFILE_DIR)/results"

help:
	@echo 'Paper: Gologlu (2022) — Biprojective APN Functions'
	@echo 'Targets:'
	@echo '  test           fast test suite (m=3,5 only)'
	@echo '  report         full report without n=14 computation'
	@echo '  full           report + Table II (n=14, ~minutes)'
	@echo '  theorem3_2     APN verification for F1/F2/F3'
	@echo '  proposition3_4 eta_m(NBF) bounds'
	@echo '  table1         NF sequences n=10 (Table I + III)'
	@echo '  table2         NF sequences n=14 (Table II, slow)'
