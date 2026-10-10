JULIA ?= julia
ROOT := $(abspath $(dir $(lastword $(MAKEFILE_LIST)))/../..)
.PHONY: test
test:
	$(JULIA) --startup-file=no --project=$(ROOT) -e 'using Pkg; Pkg.test("VBFSearch")'
