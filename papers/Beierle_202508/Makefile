JULIA ?= julia

MAKEFILE_DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
ROOT := $(abspath $(MAKEFILE_DIR)/../..)
JULIA_PROJECT := --project=$(ROOT)

.PHONY: help test report paper_counts component_profiles extension_criteria \
        estimators dataset_validation catalog_validation clean_results

limit ?= 2147483647
max_evaluations ?= 1048576
sample_size ?= 0
dataset_path ?=
save_results ?= false
seed ?= 42
full_search ?= false
check_ortho ?= false

default: help

test:
	$(JULIA) $(JULIA_PROJECT) -e 'using Pkg; Pkg.instantiate()'
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/test/runtests.jl

report:
	$(JULIA) $(JULIA_PROJECT) -e 'include(joinpath("$(MAKEFILE_DIR)", "report.jl")); paper_report(; dataset_path="$(dataset_path)", dataset_sample_size=$(sample_size), check_ortho=$(check_ortho), save_results=$(save_results))'

paper_counts:
	$(JULIA) $(JULIA_PROJECT) -e 'include(joinpath("$(MAKEFILE_DIR)", "paper_counts.jl")); print_header(); paper_counts_report()'

component_profiles:
	$(JULIA) $(JULIA_PROJECT) -e 'include(joinpath("$(MAKEFILE_DIR)", "component_profiles.jl")); print_header(); component_profiles_report()'

extension_criteria:
	$(JULIA) $(JULIA_PROJECT) -e 'include(joinpath("$(MAKEFILE_DIR)", "extension_criteria.jl")); print_header(); extension_criteria_report()'

estimators:
	$(JULIA) $(JULIA_PROJECT) -e 'include(joinpath("$(MAKEFILE_DIR)", "estimators.jl")); print_header(); estimators_report()'

dataset_validation:
	$(JULIA) $(JULIA_PROJECT) -e 'include(joinpath("$(MAKEFILE_DIR)", "dataset_validation.jl")); print_header(); dataset_validation_report(; dataset_path="$(dataset_path)", sample_size=$(sample_size), check_ortho=$(check_ortho))'

catalog_validation:
	$(JULIA) $(JULIA_PROJECT) -e 'include(joinpath("$(MAKEFILE_DIR)", "catalog_validation.jl")); print_header(); catalog_validation_report()'

clean_results:
	rm -rf "$(MAKEFILE_DIR)/results"

help:
	@echo 'Paper: Beierle et al. 2025 - Millions of inequivalent quadratic APN functions in eight variables'
	@echo 'Targets:'
	@echo '  test                  Run paper tests'
	@echo '  report                Run bounded aggregate report'
	@echo '  paper_counts          Check Table 4.1 and Theorem 5.1 arithmetic'
	@echo '  component_profiles    Check component rank/moment identities on small APN examples'
	@echo '  extension_criteria    Check Lemma 4.6, Lemma 4.7, and Theorem 4.9 small cases'
	@echo '  estimators            Recompute Section 5 total-class estimates'
	@echo '  dataset_validation    Stream-validate local Zenodo LUT samples'
	@echo '  catalog_validation    Compare local pre-2025 bulk-corpus counts'
	@echo '  clean_results         Remove generated files under results/'
	@echo ''
	@echo 'Parameters:'
	@echo '  sample_size=$(sample_size)       dataset samples to read; 0 reads none'
	@echo '  dataset_path=$(dataset_path)     local new_apns.txt path; empty uses env/default'
	@echo '  check_ortho=$(check_ortho)       true also constructs ortho derivative for samples'
	@echo '  save_results=$(save_results)     true writes results/report.toml'
	@echo '  limit=$(limit)'
	@echo '  max_evaluations=$(max_evaluations)'
	@echo '  seed=$(seed)'
	@echo '  full_search=$(full_search)       reserved opt-in flag; default false'
