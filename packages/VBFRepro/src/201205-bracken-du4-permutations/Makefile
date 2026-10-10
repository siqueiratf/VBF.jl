include $(dir $(abspath $(lastword $(MAKEFILE_LIST))))../paper.mk

.PHONY: verify_certificate
coefficients_csv ?=
verify_certificate:
	$(JULIA) --startup-file=no $(MAKEFILE_DIR)/test/verify_certificate.jl "$(coefficients_csv)"

.PHONY: help test report section2 section3 section4 section5 theorem1_1 \
        orbit_certificate problem5_1 clean_results

max_coefficients ?= 256
timeout_seconds ?= 30
full_search ?= false
save_results ?= false

default: help

test:
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
	  'include(joinpath("$(MAKEFILE_DIR)", "theorem1_1.jl")); theorem1_1_report(full_search=parse(Bool,"$(full_search)"), max_coefficients=parse(Int,"$(max_coefficients)"), timeout_seconds=parse(Float64,"$(timeout_seconds)"), save_results=parse(Bool,"$(save_results)"))'

orbit_certificate: theorem1_1

problem5_1:
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "problem5_1.jl")); problem5_1_report()'

clean_results:
	rm -rf "$(MAKEFILE_DIR)/results"

help:
	@echo 'Paper: Bracken, Tan, Tan (2012) — Binomial Differentially 4 Uniform Permutations'
	@echo 'Targets: test  report  section2  section3  section4  section5  theorem1_1'
	@echo '         orbit_certificate  problem5_1  clean_results'
	@echo 'All runtimes below were measured on THIS machine with @elapsed'
	@echo '(Julia 1.12.6, AMD Ryzen 5 5600G, single-threaded):'
	@echo '  - section2   : permutation grid, all 12 feasible (k,s) with n=3k<=15   0.18 s'
	@echo '  - section3   : differential SPECTRUM {0,2^t}; 1.7 s per n=15 instance  ~5 s'
	@echo '  - section4   : Lemma 4.1 + Walsh value set; 4.9 s per n=15 instance   ~13 s'
	@echo '  - section5   : Table 1 rows + CCZ separation from the inverse          ~4 s'
	@echo '  - theorem1_1 / orbit_certificate: n=30 exact normalized coefficients;'
	@echo '                 default 256 cases; full_search=true requests all 49981.'
	@echo '                 timeout_seconds=120 save_results=true for full evidence.'
	@echo '                 Only a completed certificate proves the finite instance.'
	@echo '  - problem5_1 : open problem at (k,s)=(5,1); sampled by default (~5 s),'
	@echo '                 full 993-pair scan via full_search=true (52.5 s).'
	@echo 'Notes:'
	@echo '  - n=6 (k=2,s=4) is a DEGENERATE monomial, linear-equivalent to Gold x^5'
	@echo '  - the smallest genuine binomial with t=2 is n=30 (k=10,s=2)'
