JULIA ?= julia
MAKEFILE_DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
ROOT := $(abspath $(MAKEFILE_DIR)/../..)
JULIA_PROJECT := --project=$(ROOT)

.PHONY: help test report clean_results \
        proposition14 section3_2 proposition22 corollary24 \
        algorithm1 section4_3

default: help

test:
	$(JULIA) $(JULIA_PROJECT) -e 'using Pkg; Pkg.instantiate()'
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/test/runtests.jl

report:
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/report.jl

proposition14:
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/proposition14.jl

section3_2:
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/section3_2.jl

proposition22:
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/proposition22.jl

corollary24:
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/corollary24.jl

algorithm1:
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/algorithm1.jl

section4_3:
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/section4_3.jl

clean_results:
	rm -rf "$(MAKEFILE_DIR)/results"

help:
	@echo 'Paper: Canteaut–Couvreur–Perrin (2022) — Recovering or Testing EA Equivalence'
	@echo 'Targets: test  report  proposition14  section3_2  proposition22'
	@echo '         corollary24  algorithm1  section4_3  clean_results'
