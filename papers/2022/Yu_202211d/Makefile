JULIA ?= julia

MAKEFILE_DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
ROOT := $(abspath $(MAKEFILE_DIR)/../../..)
JULIA_PROJECT := --project=$(ROOT)

.PHONY: help test qam_correspondence conjecture2_search proposition3_partitions \
        theorem6_model paper_invariants small_searches \
        catalog_validation report clean_results

limit ?= 2147483647
max_evaluations ?= 1048576
sample_size ?= 25
samples ?= 2000
save_results ?= true
seed ?= 42
full_search ?= false

default: help

test:
	$(JULIA) $(JULIA_PROJECT) -e 'using Pkg; Pkg.instantiate()'
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/test/runtests.jl

qam_correspondence:
	@echo "ROOT=$(ROOT)"
	@echo "Running QAM/APN correspondence checks"
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "qam_correspondence.jl")); \
	   print_header(); qam_correspondence_report()'

conjecture2_search:
	@echo "ROOT=$(ROOT)"
	@echo "Running Conjecture 2 H_8 model + bounded search (max_evaluations=$(max_evaluations))"
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "conjecture2_search.jl")); \
	   print_header(); conjecture2_report(; max_evaluations=$(max_evaluations))'

proposition3_partitions:
	@echo "ROOT=$(ROOT)"
	@echo "Running Proposition 3 candidate-set restriction checks"
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "proposition3_partitions.jl")); \
	   print_header(); proposition3_report()'

theorem6_model:
	@echo "ROOT=$(ROOT)"
	@echo "Running Theorem 6 new-model checks (samples=$(samples))"
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "theorem6_model.jl")); \
	   print_header(); theorem6_report(; samples=$(samples))'

paper_invariants:
	@echo "ROOT=$(ROOT)"
	@echo "Running class-invariant checks (ortho-derivative, Sigma_4, Walsh, ranks)"
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "conjecture2_search.jl")); \
	   include(joinpath("$(MAKEFILE_DIR)", "paper_invariants.jl")); \
	   print_header(); paper_invariants_report()'

small_searches:
	@echo "ROOT=$(ROOT)"
	@echo "Running small QAM searches (limit=$(limit), max_evaluations=$(max_evaluations))"
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "small_searches.jl")); \
	   print_header(); \
	   small_searches_report(; limit=$(limit), max_evaluations=$(max_evaluations), save_results=$(save_results))'

catalog_validation:
	@echo "ROOT=$(ROOT)"
	@echo "Running catalog validation (sample_size=$(sample_size), seed=$(seed))"
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "catalog_validation.jl")); \
	   print_header(); \
	   catalog_validation_report(; sample_size=$(sample_size), seed=$(seed))'

report:
	@echo "ROOT=$(ROOT)"
	@echo "Running full paper report (save_results=$(save_results))"
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "report.jl")); \
	   paper_report(; save_results=$(save_results))'

clean_results:
	rm -rf "$(MAKEFILE_DIR)/results"

help:
	@echo 'Available commands for Yu–Perrin 2022 (QAM method):'
	@echo '  test                     Run tests'
	@echo '  qam_correspondence       QAM/APN correspondence checks (Definition QAM / Theorem 1)'
	@echo '  conjecture2_search       H_8 model + bounded modified-entry search (Conjecture 2)'
	@echo '  proposition3_partitions  Candidate-set restriction checks (Theorem 2 / Proposition 3)'
	@echo '  theorem6_model           New-model QAM test for the last two columns (Theorem 6)'
	@echo '  paper_invariants         Ortho-derivative (Definition 2) / Sigma_4 / Walsh / Gamma-Delta-ranks'
	@echo '  small_searches           Bounded small-dimensional QAM searches'
	@echo '  catalog_validation       Validate Yu–Perrin corpus from VBFCatalog (optional)'
	@echo '  report                   Full paper reproduction report (save_results=true writes results/report.toml)'
	@echo '  clean_results            Remove generated files under results/'
	@echo ''
	@echo 'Parameters (override with make target param=value):'
	@echo '  limit=$(limit)'
	@echo '  max_evaluations=$(max_evaluations)'
	@echo '  sample_size=$(sample_size)'
	@echo '  samples=$(samples)'
	@echo '  save_results=$(save_results)   (report -> results/report.toml; small_searches -> results/small_searches.toml)'
	@echo '  seed=$(seed)'
	@echo '  full_search=$(full_search)   (opt-in for expensive/full searches; default false)'
