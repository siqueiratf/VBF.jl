JULIA ?= julia
DOCS := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
INSPECTOR := $(DOCS)inspector/
port ?= 8088
host ?= 127.0.0.1
run ?=
campaign ?=

.PHONY: instantiate inspector-instantiate build serve serve-built serve-inspector serve-search test test-search

instantiate:
	$(JULIA) --project="$(DOCS)" -e 'using Pkg; Pkg.instantiate()'

inspector-instantiate:
	JULIA_NUM_PRECOMPILE_TASKS=2 $(JULIA) --project="$(INSPECTOR)" -e 'using Pkg; Pkg.instantiate()'

build: instantiate
	$(JULIA) --project="$(DOCS)" "$(DOCS)make.jl"

serve: build
	$(MAKE) -C "$(DOCS)" serve-built port="$(port)" host="$(host)" run="$(run)"

serve-built: inspector-instantiate
	$(JULIA) --threads=1,1 --project="$(INSPECTOR)" "$(INSPECTOR)server.jl" --docs "$(DOCS)build" --port $(port) --host $(host) $(if $(run),--run "$(abspath $(run))",)

serve-inspector: inspector-instantiate
	$(JULIA) --threads=1,1 --project="$(INSPECTOR)" "$(INSPECTOR)server.jl" --port $(port) --host $(host) $(if $(run),--run "$(abspath $(run))",)

serve-search: inspector-instantiate
	$(JULIA) --threads=1,1 --project="$(INSPECTOR)" "$(INSPECTOR)closure_monitor.jl" --campaign "$(abspath $(campaign))" --port $(port) --host $(host) $(if $(run),--run "$(abspath $(run))",)

test: inspector-instantiate
	$(JULIA) --threads=1,1 --project="$(INSPECTOR)" "$(INSPECTOR)test/runtests.jl"

test-search: inspector-instantiate
	$(JULIA) --threads=1,1 --project="$(INSPECTOR)" "$(INSPECTOR)test/closure_monitor.jl"
	$(JULIA) --threads=1,1 --project="$(INSPECTOR)" "$(INSPECTOR)test/closure_graph.jl"
	$(JULIA) --threads=1,1 --project="$(INSPECTOR)" "$(INSPECTOR)test/live_structure.jl"
