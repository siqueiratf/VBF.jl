JULIA ?= julia
MAKEFILE_DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
ROOT := $(abspath $(MAKEFILE_DIR)/../../..)
JULIA_PROJECT := --project=$(ROOT)

.PHONY: help test report construction1 theorem2 theorem3 table3 example1 clean_results

default: help

test:
	$(JULIA) $(JULIA_PROJECT) -e 'using Pkg; Pkg.instantiate()'
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/test/runtests.jl

report:
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/report.jl

construction1:
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/construction1.jl

theorem2:
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/theorem2.jl

theorem3:
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/theorem3.jl

table3:
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/table3.jl

example1:
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/example1.jl

clean_results:
	rm -rf "$(MAKEFILE_DIR)/results"

help:
	@echo 'Paper: Tang_201510 — Differentially 4-Uniform Bijections by Permuting the Inverse Function'
	@echo 'Targets: test  report  construction1  theorem2  theorem3  table3  example1  clean_results'
