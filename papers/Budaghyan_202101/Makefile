JULIA ?= julia
MAKEFILE_DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
ROOT          := $(abspath $(MAKEFILE_DIR)/../..)
JULIA_PROJECT := --project=$(ROOT)

.PHONY: help test report proposition2_1 theorem3_1 proposition3_2 theorem3_2 clean_results

default: help

test:
	$(JULIA) $(JULIA_PROJECT) -e 'using Pkg; Pkg.instantiate()'
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/test/runtests.jl

report:
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/report.jl

proposition2_1:
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/proposition2_1.jl

theorem3_1:
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/theorem3_1.jl

proposition3_2:
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/proposition3_2.jl

theorem3_2:
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/theorem3_2.jl

clean_results:
	rm -rf "$(MAKEFILE_DIR)/results"

help:
	@echo 'Paper: Budaghyan_202101 — Generalized Isotopic Shift Construction for APN Functions'
	@echo 'Targets: test  report  proposition2_1  theorem3_1  proposition3_2  theorem3_2'
