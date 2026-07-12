JULIA ?= julia
MAKEFILE_DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
ROOT := $(abspath $(MAKEFILE_DIR)/../../..)
JULIA_PROJECT := --project=$(ROOT)

.PHONY: help test report theorem2 theorem3 lemma1 algorithm1 section5_1 section5_3

default: help

test:
	$(JULIA) $(JULIA_PROJECT) -e 'using Pkg; Pkg.instantiate()'
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/tests/runtests.jl

report:
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/report.jl

theorem2:
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/theorem2.jl

theorem3:
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/theorem3.jl

lemma1:
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/lemma1.jl

algorithm1:
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/algorithm1.jl

section5_1:
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/section5_1.jl

section5_3:
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/section5_3.jl

help:
	@echo 'Paper: Ichanska-Berg-Kaleyski-Yu 2024 — Pushing the QAM method for finding APN functions further'
	@echo 'Targets: test  report  theorem2  theorem3  lemma1  algorithm1  section5_1  section5_3'
