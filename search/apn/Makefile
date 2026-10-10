JULIA ?= julia
ROOT := $(abspath $(dir $(lastword $(MAKEFILE_LIST)))/../..)
HERE := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
JFLAGS ?= --startup-file=no --compiled-modules=no --project=$(ROOT)

.PHONY: test
test:
	$(JULIA) $(JFLAGS) $(HERE)/test/cli.jl
	$(JULIA) $(JFLAGS) $(HERE)/test/runtests.jl
