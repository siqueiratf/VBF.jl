JULIA ?= julia
ROOT := $(abspath $(dir $(abspath $(lastword $(MAKEFILE_LIST))))/../..)
paper ?=
target ?= report
timeout ?= 900

.DEFAULT_GOAL := help
.PHONY: help list run test instantiate
help:
	@echo 'make -C packages/VBFRepro list'
	@echo 'make -C packages/VBFRepro run paper=202211-yu-qam target=qam_correspondence timeout=900'
	@echo 'make -C packages/VBFRepro test'
instantiate:
	$(JULIA) --project="$(ROOT)" -e 'using Pkg; Pkg.instantiate()'
list:
	$(JULIA) --project="$(ROOT)" -e 'using VBFRepro; foreach(p -> println(p.id), discover_papers())'
run:
	VBF_REPRO_PAPER="$(paper)" VBF_REPRO_TARGET="$(target)" VBF_REPRO_TIMEOUT="$(timeout)" $(JULIA) --project="$(ROOT)" -e 'using VBFRepro; result=run_paper(ENV["VBF_REPRO_PAPER"];target=ENV["VBF_REPRO_TARGET"],timeout_seconds=parse(Float64,ENV["VBF_REPRO_TIMEOUT"])); println(result); result.status=="passed" || exit(1)'
test:
	$(JULIA) --project="$(ROOT)" -e 'using Pkg; Pkg.test("VBFRepro")'
