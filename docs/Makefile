JULIA ?= julia
DOCS := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
APP := $(abspath $(DOCS)/../apps/apn-inspector)
port ?= 8088
host ?= 127.0.0.1
run ?=

.PHONY: instantiate build serve

instantiate:
	$(JULIA) --project="$(DOCS)" -e 'using Pkg; Pkg.instantiate()'

build: instantiate
	DOCS_DEPLOY=false $(JULIA) --project="$(DOCS)" "$(DOCS)make.jl"

serve: build
	$(MAKE) -C "$(APP)" instantiate
	$(MAKE) -C "$(APP)" serve docs="$(DOCS)build" port="$(port)" host="$(host)" run="$(if $(run),$(abspath $(run)),)"
