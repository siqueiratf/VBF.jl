JULIA ?= julia

WEB := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
# Two threads in total: one default thread (exact EA test) and one interactive thread (HTTP).
THREADS := --threads=1,1
JFLAGS := $(THREADS) --project=$(WEB)

port ?= 8088
host ?= 127.0.0.1
run ?=
docs ?=

.PHONY: help instantiate serve test

help:
	@echo "Targets:"
	@echo "  make instantiate                 install HTTP.jl, JSON3 and the local VBF, VBFCatalog"
	@echo "  make serve [port=8088] [host=127.0.0.1]   start the page at http://host:port/"
	@echo "  make test                        test the request handler (no socket)"

instantiate:
	JULIA_NUM_PRECOMPILE_TASKS=2 $(JULIA) --project=$(WEB) -e 'using Pkg; Pkg.instantiate(); Pkg.precompile()'

serve:
	$(JULIA) $(JFLAGS) "$(WEB)server.jl" --port $(port) --host $(host) $(if $(run),--run "$(run)",) $(if $(docs),--docs "$(docs)",)

test:
	$(JULIA) $(JFLAGS) $(WEB)test/runtests.jl
