include $(dir $(abspath $(lastword $(MAKEFILE_LIST))))../paper.mk


.PHONY: help test report clean_results \
        theorem1 proposition1 corollary1 proposition2 theorem2 corollary2 \
        section2_1 dependence_search theorem3 corollary3 corollary4 proposition3

# Overridable parameters
limit        ?= 2147483647
n_max        ?= 8
save_results ?= false
seed         ?= 42
full_search  ?= false

default: help

test:
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/test/runtests.jl

report:
	@echo "ROOT=$(ROOT)"
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "report.jl")); \
	   paper_report(; save_results=$(save_results), full_search=$(full_search), n_max=$(n_max))'

theorem1:
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "theorem1.jl")); print_header(); theorem1_report()'

proposition1:
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "proposition1.jl")); print_header(); proposition1_report()'

corollary1:
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "corollary1.jl")); print_header(); corollary1_report(; n_max=$(n_max))'

proposition2:
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "proposition2.jl")); print_header(); proposition2_report()'

theorem2:
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "theorem2.jl")); print_header(); theorem2_report()'

corollary2:
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "corollary2.jl")); print_header(); corollary2_report()'

section2_1:
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "section2_1.jl")); print_header(); section2_1_examples()'

dependence_search:
	@echo "Opt-in §2.1 linear-dependence search (n from n_max-ish; default n=5)"
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "section2_1.jl")); print_header(); dependence_search(; n=5, r=1, save_results=$(save_results))'

theorem3:
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "theorem3.jl")); print_header(); theorem3_report()'

corollary3:
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "corollary3.jl")); print_header(); corollary3_report()'

corollary4:
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "corollary4.jl")); print_header(); corollary4_report()'

proposition3:
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "proposition3.jl")); print_header(); proposition3_report()'

clean_results:
	rm -rf "$(MAKEFILE_DIR)/results"

help:
	@echo 'Budaghyan, Carlet, Leander (2009) — Constructing new APN functions from known ones'
	@echo ''
	@echo 'Targets (one per paper claim):'
	@echo '  theorem1      Theorem 1: ℓ_a conditions ⇒ F+f APN (+ Remarks 1,2)'
	@echo '  proposition1  Proposition 1: three differentially-4-uniform constructions'
	@echo '  corollary1    Corollary 1: x³+tr(x⁹) APN for n=3..n_max (flagship)'
	@echo '  proposition2  Proposition 2: F, G EA-equivalent (n=6)'
	@echo '  theorem2      Theorem 2: generalization to f:GF(2ⁿ)→GF(2ᵐ), m|n'
	@echo '  corollary2    Corollary 2: F, F΄ APN, F΄=F^{2^m}, Gold witness'
	@echo '  section2_1    §2.1 examples: x⁵+tr(x³) (n=5), x⁹+tr(x³) (n=8)'
	@echo '  dependence_search  §2.1 linear-dependence search (opt-in, bounded)'
	@echo '  theorem3      Theorem 3: CCZ-inequiv to Gold (n=7)'
	@echo '  corollary3    Corollary 3: EA-inequiv to any power fn (n=7)'
	@echo '  corollary4    Corollary 4: Δ-rank 212 vs 338/436 (n=7) [headline]'
	@echo '  proposition3  Proposition 3: non-quadratic APN CCZ-equiv to F'
	@echo '  report        Fast aggregate report (no opt-in search)'
	@echo '  test          Run the test suite'
	@echo '  clean_results Remove generated files under results/'
	@echo ''
	@echo 'Parameters (make target param=value):'
	@echo '  limit=$(limit)  n_max=$(n_max)  save_results=$(save_results)  seed=$(seed)  full_search=$(full_search)'
