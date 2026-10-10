# Shared execution environment; included by each paper's standalone Makefile.
JULIA ?= julia
JULIA_FLAGS ?=
MAKEFILE_DIR := $(dir $(abspath $(firstword $(MAKEFILE_LIST))))
ROOT := $(abspath $(dir $(abspath $(lastword $(MAKEFILE_LIST))))/../../..)
JULIA_PROJECT := --project="$(ROOT)"
.DEFAULT_GOAL := help

.PHONY: instantiate
instantiate:
	$(JULIA) $(JULIA_PROJECT) -e 'using Pkg; Pkg.instantiate()'
