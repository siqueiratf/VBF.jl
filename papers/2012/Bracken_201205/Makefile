JULIA ?= julia
MAKEFILE_DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
ROOT := $(abspath $(MAKEFILE_DIR)/../../..)
JULIA_PROJECT := --project=$(ROOT)

.PHONY: help test report section2 section3 section4 section5 theorem1_1 \
        problem5_1 clean_results

default: help

test:
	$(JULIA) $(JULIA_PROJECT) -e 'using Pkg; Pkg.instantiate()'
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/test/runtests.jl

report:
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/report.jl

section2:
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "section2.jl")); section2_report()'

section3:
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "section3.jl")); section3_report()'

section4:
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "section4.jl")); section4_report()'

section5:
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "section5.jl")); section5_report()'

theorem1_1:
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "theorem1_1.jl")); theorem1_1_report()'

problem5_1:
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "problem5_1.jl")); problem5_1_report()'

clean_results:
	rm -rf "$(MAKEFILE_DIR)/results"

help:
	@echo 'Paper: Bracken, Tan, Tan (2012) — Binomial Differentially 4 Uniform Permutations'
	@echo 'Targets: test  report  section2  section3  section4  section5  theorem1_1'
	@echo '         problem5_1  clean_results'
	@echo 'All runtimes below were measured on THIS machine with @elapsed'
	@echo '(Julia 1.12.6, AMD Ryzen 5 5600G, single-threaded):'
	@echo '  - section2   : permutation grid, all 12 feasible (k,s) with n=3k<=15   0.18 s'
	@echo '  - section3   : differential SPECTRUM {0,2^t}; 1.7 s per n=15 instance  ~5 s'
	@echo '  - section4   : Lemma 4.1 + Walsh value set; 4.9 s per n=15 instance   ~13 s'
	@echo '  - section5   : Table 1 rows + CCZ separation from the inverse          ~4 s'
	@echo '  - theorem1_1 : n=30 genuine t=2 instance; rank-based differential'
	@echo '                 evidence (0.46 s / 2000 samples) + budgeted permutation'
	@echo '                 prefix (0.81 s at limit=2^18). The exhaustive 2^30 scan'
	@echo '                 is opt-in via full_search=true: ~55 min extrapolated.'
	@echo '                 paper_report gates it behind its OWN n30_full_search=true,'
	@echo '                 so widening the cheap grid can never trigger it.'
	@echo '  - problem5_1 : open problem at (k,s)=(5,1); sampled by default (~5 s),'
	@echo '                 full 993-pair scan via full_search=true (52.5 s).'
	@echo 'Notes:'
	@echo '  - n=6 (k=2,s=4) is a DEGENERATE monomial, linear-equivalent to Gold x^5'
	@echo '  - the smallest genuine binomial with t=2 is n=30 (k=10,s=2)'
