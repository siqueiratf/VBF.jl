JULIA ?= julia
MAKEFILE_DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
ROOT := $(abspath $(MAKEFILE_DIR)/../../..)
JULIA_PROJECT := --project=$(ROOT)

.PHONY: help test report clean_results \
        equivalences lemma1 proposition1 proposition2 proposition3 \
        proposition4 proposition5 proposition6

default: help

test:
	$(JULIA) $(JULIA_PROJECT) -e 'using Pkg; Pkg.instantiate()'
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/test/runtests.jl

report:
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/report.jl

equivalences:
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/equivalences.jl

lemma1:
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/lemma1.jl

proposition1:
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/proposition1.jl

proposition2:
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/proposition2.jl

proposition3:
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/proposition3.jl

proposition4:
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/proposition4.jl

proposition5:
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/proposition5.jl

proposition6:
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/proposition6.jl

clean_results:
	rm -rf "$(MAKEFILE_DIR)/results"

help:
	@echo 'Paper: Canteaut, Perrin, Tian (2019) — If a Generalised Butterfly is APN then it Operates on 6 Bits'
	@echo 'Targets: test  report  equivalences  lemma1  proposition1  proposition2  proposition3  proposition4  proposition5  proposition6  clean_results'
