JULIA ?= julia
MAKEFILE_DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
ROOT := $(abspath $(MAKEFILE_DIR)/../..)
JULIA_PROJECT := --project=$(ROOT)

.PHONY: help test report clean_results \
        proposition3_5 proposition3_7 proposition3_12 corollary3_14 \
        algorithm1 section4_3

default: help

test:
	$(JULIA) $(JULIA_PROJECT) -e 'using Pkg; Pkg.instantiate()'
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/test/runtests.jl

report:
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/report.jl

proposition3_5:
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/proposition3_5.jl

proposition3_7:
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/proposition3_7.jl

proposition3_12:
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/proposition3_12.jl

corollary3_14:
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/corollary3_14.jl

algorithm1:
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/algorithm1.jl

section4_3:
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/section4_3.jl

clean_results:
	rm -rf "$(MAKEFILE_DIR)/results"

help:
	@echo 'Paper: Canteaut–Couvreur–Perrin (2022) — Recovering or Testing EA Equivalence'
	@echo 'Targets: test  report  proposition3_5  proposition3_7  proposition3_12'
	@echo '         corollary3_14  algorithm1  section4_3  clean_results'
