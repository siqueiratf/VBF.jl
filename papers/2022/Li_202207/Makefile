JULIA ?= julia

MAKEFILE_DIR  := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
ROOT          := $(abspath $(MAKEFILE_DIR)/../../..)
JULIA_PROJECT := --project=$(ROOT)

.PHONY: help test report theorem2 theorem3 clean_results

m    ?= 4
s    ?= 1
v    ?= 1
full ?= false

default: help

test:
	$(JULIA) $(JULIA_PROJECT) -e 'using Pkg; Pkg.instantiate()'
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/tests/runtests.jl

report:
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "report.jl")); paper_report(full=$(full))'

theorem2:
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "helpers.jl")); \
	   include(joinpath("$(MAKEFILE_DIR)", "theorem2.jl")); \
	   print_header(); theorem2_report(ms=[$(m)])'

theorem3:
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "helpers.jl")); \
	   include(joinpath("$(MAKEFILE_DIR)", "theorem3.jl")); \
	   print_header(); theorem3_report(ms=[$(m)], s=$(s), v=$(v))'

clean_results:
	rm -rf "$(MAKEFILE_DIR)/results"

help:
	@echo 'Li, Zhou, Li, Qu (2022) — Two New Families of Quadratic APN Functions'
	@echo 'IEEE Trans. Inf. Theory, Vol. 68, No. 7, pp. 4761–4769'
	@echo ''
	@echo 'Targets:'
	@echo '  test       Run test suite'
	@echo '  report     Full paper report (Theorems 2 and 3)'
	@echo '  theorem2   Bivariate APN check for given m  (gcd(3,m)=1 required)'
	@echo '  theorem3   Univariate APN check for given m,s  (gcd(s,m)=1 required)'
	@echo '  clean_results  Remove results/ directory'
	@echo ''
	@echo 'Parameters (override with make target param=value):'
	@echo '  m=$(m)      Subfield dimension'
	@echo '  s=$(s)      Frobenius exponent in L for theorem3'
	@echo '  v=$(v)      Nonzero scalar in f(z) for theorem3'
	@echo '  full=$(full)  Include larger m values in report'
