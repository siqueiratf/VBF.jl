JULIA ?= julia
DOCS := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
INSPECTOR := $(DOCS)inspector/
port ?= 8088
host ?= 127.0.0.1
run ?=

.PHONY: instantiate inspector-instantiate build serve serve-built serve-inspector test

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

test: inspector-instantiate
	$(JULIA) --threads=1,1 --project="$(INSPECTOR)" "$(INSPECTOR)test/runtests.jl"
