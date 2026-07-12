JULIA ?= julia

MAKEFILE_DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
ROOT := $(abspath $(MAKEFILE_DIR)/../../..)
JULIA_PROJECT := --project=$(ROOT)

.PHONY: help test report observation1 proposition1 lemma3 theorem2 lemma4 corollary1 table3 clean_results

n ?= 10

default: help

test:
	$(JULIA) $(JULIA_PROJECT) -e 'using Pkg; Pkg.instantiate()'
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/test/runtests.jl

report:
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/report.jl

observation1:
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "helpers.jl")); \
	   include(joinpath("$(MAKEFILE_DIR)", "observation1.jl")); \
	   print_banner(PAPER_BANNER...); observation1_report()'

proposition1:
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "helpers.jl")); \
	   include(joinpath("$(MAKEFILE_DIR)", "proposition1.jl")); \
	   print_banner(PAPER_BANNER...); proposition1_report()'

lemma3:
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "helpers.jl")); \
	   include(joinpath("$(MAKEFILE_DIR)", "lemma3.jl")); \
	   print_banner(PAPER_BANNER...); lemma3_report()'

theorem2:
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "helpers.jl")); \
	   include(joinpath("$(MAKEFILE_DIR)", "theorem2.jl")); \
	   print_banner(PAPER_BANNER...); theorem2_report(; n=$(n))'

lemma4:
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "helpers.jl")); \
	   include(joinpath("$(MAKEFILE_DIR)", "lemma4.jl")); \
	   print_banner(PAPER_BANNER...); lemma4_report(; n=$(n))'

corollary1:
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "helpers.jl")); \
	   include(joinpath("$(MAKEFILE_DIR)", "corollary1.jl")); \
	   print_banner(PAPER_BANNER...); corollary1_report(; n=$(n))'

table3:
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "helpers.jl")); \
	   include(joinpath("$(MAKEFILE_DIR)", "table3.jl")); \
	   print_banner(PAPER_BANNER...); table3_report()'

clean_results:
	rm -rf "$(MAKEFILE_DIR)/results"

help:
	@echo 'Budaghyan, Helleseth, Kaleyski (2020) — A New Family of APN Quadrinomials'
	@echo 'IEEE Trans. Inf. Theory 66(11):7081–7087'
	@echo ''
	@echo 'Targets:'
	@echo '  test          Run all tests'
	@echo '  report        Full paper report'
	@echo '  observation1  Verify C_3, C_7 APN over GF(2^10)'
	@echo '  proposition1  Verify E_i trivial => C_i APN for all i in 1..9'
	@echo '  lemma3        Verify P(N) has exactly the roots {0,1,S,S+1}'
	@echo '  theorem2      Verify the four Theorem 2 i-values give APN (param: n=10)'
	@echo '  lemma4        Verify the odd-k i-values of Lemma 4 (param: n=10)'
	@echo '  corollary1    Verify the 8 claimed cases; item 8 is a paper erratum'
	@echo '  table3        Table III: all rows + ortho-derivative novelty comparison'
	@echo ''
	@echo 'Parameters:'
	@echo '  n=$(n)   (dimension for theorem2 / lemma4 / corollary1)'
