JULIA ?= julia

MAKEFILE_DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
ROOT         := $(abspath $(MAKEFILE_DIR)/../..)
JULIA_PROJECT := --project=$(ROOT)

.PHONY: help test report theorem1 proposition4 theorem6 proposition8 section5a clean_results

m    ?= 3
i    ?= 1
full ?= false

default: help

test:
	$(JULIA) $(JULIA_PROJECT) -e 'using Pkg; Pkg.instantiate()'
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/tests/runtests.jl

report:
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "report.jl")); paper_report(full=$(full))'

theorem1:
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "helpers.jl")); \
	   include(joinpath("$(MAKEFILE_DIR)", "theorem1.jl")); \
	   print_header(); theorem1_report(m=$(m), i=$(i))'

proposition4:
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "helpers.jl")); \
	   include(joinpath("$(MAKEFILE_DIR)", "theorem1.jl")); \
	   include(joinpath("$(MAKEFILE_DIR)", "proposition4.jl")); \
	   print_header(); proposition4_report(ms=[$(m)])'

theorem6:
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "helpers.jl")); \
	   include(joinpath("$(MAKEFILE_DIR)", "theorem6.jl")); \
	   print_header(); theorem6_report(m=$(m), i=$(i))'

proposition8:
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "helpers.jl")); \
	   include(joinpath("$(MAKEFILE_DIR)", "theorem6.jl")); \
	   include(joinpath("$(MAKEFILE_DIR)", "proposition8.jl")); \
	   print_header(); proposition8_report(ms=[$(m)])'

section5a:
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "helpers.jl")); \
	   include(joinpath("$(MAKEFILE_DIR)", "theorem1.jl")); \
	   include(joinpath("$(MAKEFILE_DIR)", "theorem6.jl")); \
	   include(joinpath("$(MAKEFILE_DIR)", "section5a.jl")); \
	   print_header(); section5a_report()'

clean_results:
	rm -rf "$(MAKEFILE_DIR)/results"

help:
	@echo 'Li & Kaleyski (2024) — Two New Infinite Families of APN Functions in Trivariate Form'
	@echo ''
	@echo 'Targets:'
	@echo '  test          Run all tests'
	@echo '  report        Full paper report (default: m≤4; full=true adds m=5)'
	@echo '  theorem1      Family 1 APN+permutation (Theorems 1 & 3)'
	@echo '  proposition4  Explicit i=1, gcd(m,7)=1 case (Family 1)'
	@echo '  theorem6      Family 2 APN+permutation (Theorems 6 & 7)'
	@echo '  proposition8  Explicit i=1, gcd(m,7)=1 case (Family 2)'
	@echo '  section5a     Table IV orthoderivative spectra (n=9)'
	@echo '  clean_results Remove results/ directory'
	@echo ''
	@echo 'Parameters (override with make target param=value):'
	@echo '  m=$(m)       Subfield dimension (n=3m)'
	@echo '  i=$(i)       Frobenius exponent (q=2^i)'
	@echo '  full=$(full) Include m=5 in report (slower)'
