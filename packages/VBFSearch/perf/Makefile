JULIA ?= julia
ARGS ?=
PROFILE_ARGS ?= --group=evidence --workload=candidate_properties --n=8
.DEFAULT_GOAL := help
.PHONY: help instantiate list run test profile
help:
	@echo 'instantiate: resolve perf environment; list: workload inventory; run ARGS="...": benchmark; test: bounded smoke; profile PROFILE_ARGS="...": raw profile'
instantiate:
	JULIA_LOAD_PATH='@:@stdlib' $(JULIA) --startup-file=no --project=. -e 'using Pkg; Pkg.instantiate()'
list:
	JULIA_LOAD_PATH='@:@stdlib' $(JULIA) --startup-file=no --project=. run.jl --list $(ARGS)
run:
	JULIA_LOAD_PATH='@:@stdlib' $(JULIA) --startup-file=no --project=. run.jl $(ARGS)
test:
	JULIA_LOAD_PATH='@:@stdlib' $(JULIA) --startup-file=no --project=. test.jl
profile:
	JULIA_LOAD_PATH='@:@stdlib' $(JULIA) --startup-file=no --project=. profile.jl $(PROFILE_ARGS)
