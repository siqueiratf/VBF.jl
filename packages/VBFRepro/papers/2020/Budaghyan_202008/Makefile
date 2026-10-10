include $(dir $(abspath $(lastword $(MAKEFILE_LIST))))../../paper.mk

.PHONY: help test report section4 section5 section6 section7 section7d section7d_discover proposition_vi1 table1 clean_results

max_evaluations ?= 1000000
timeout_seconds ?= 60
seed ?= 20261010
save_results ?= false

default: help

test:
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/test/runtests.jl

report:
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/report.jl

section4:
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "section4.jl")); section4_report()'

section5:
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "section5.jl")); section5_report()'

section6:
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "section6.jl")); section6_report()'

section7:
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "section7.jl")); section7_report()'

proposition_vi1:
	$(JULIA) $(JULIA_PROJECT) -e 'include("$(MAKEFILE_DIR)/proposition_vi1.jl"); proposition_vi1_report()'

section7d:
	$(JULIA) $(JULIA_PROJECT) -e 'include("$(MAKEFILE_DIR)/section7d.jl"); section7d_report()'

section7d_discover:
	$(JULIA) $(JULIA_PROJECT) -e 'include("$(MAKEFILE_DIR)/section7d.jl"); r=section7d_discover(; seed=$(seed), max_evaluations=$(max_evaluations), timeout_seconds=$(timeout_seconds)); println((outcome=outcome_tag(r.outcome), evaluations=r.evaluations, apn_trials=r.apn_trials, covered=length(r.covered), required=length(r.required), undecided=r.undecided)); $(save_results) && println(section7d_save_evidence(r))'

table1:
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "table1.jl")); table1_report()'

clean_results:
	rm -rf "$(MAKEFILE_DIR)/results"

help:
	@echo 'Paper: Budaghyan et al. (2020) — Constructing APN Functions Through Isotopic Shifts'
	@echo 'Targets: test  report  section4  section5  section6  section7  table1  clean_results'
