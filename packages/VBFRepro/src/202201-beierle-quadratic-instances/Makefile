include $(dir $(abspath $(lastword $(MAKEFILE_LIST))))../paper.mk


.PHONY: help test dataset_counts verify_apn verify_quadratic \
        table1_invariants walsh_spectrum multiplier_group \
        proposition1 catalog_validation report clean_results \
        algorithm1 lemma4 lemma5

limit        ?= 2147483647
sample_size  ?= 100
save_results ?= false
seed         ?= 42
full_search  ?= false
n            ?= 5
max_solutions ?= 3
max_dim      ?= 7

default: help

test:
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/test/runtests.jl

dataset_counts:
	@echo "ROOT=$(ROOT)"
	@echo "Counting and validating dataset files"
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "helpers.jl")); \
	   include(joinpath("$(MAKEFILE_DIR)", "dataset_validation.jl")); \
	   print_header(); dataset_counts()'

verify_apn:
	@echo "ROOT=$(ROOT)"
	@echo "Verifying APN property (sample_size=$(sample_size), full_search=$(full_search))"
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "helpers.jl")); \
	   include(joinpath("$(MAKEFILE_DIR)", "dataset_validation.jl")); \
	   print_header(); verify_apn(; sample_size=$(sample_size), full_search=$(full_search))'

verify_quadratic:
	@echo "ROOT=$(ROOT)"
	@echo "Verifying algebraic degree 2 (sample_size=$(sample_size), full_search=$(full_search))"
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "helpers.jl")); \
	   include(joinpath("$(MAKEFILE_DIR)", "dataset_validation.jl")); \
	   print_header(); verify_quadratic(; sample_size=$(sample_size), full_search=$(full_search))'

table1_invariants:
	@echo "ROOT=$(ROOT)"
	@echo "Table1 reconstruction UNSUPPORTED; reporting gap (max_dim=$(max_dim), save_results=$(save_results))"
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "helpers.jl")); \
	   include(joinpath("$(MAKEFILE_DIR)", "table1_invariants.jl")); \
	   print_header(); check_ranks(; max_dim=$(max_dim), save_results=$(save_results))'

walsh_spectrum:
	@echo "ROOT=$(ROOT)"
	@echo "Table1 reconstruction UNSUPPORTED; reporting gap (save_results=$(save_results))"
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "helpers.jl")); \
	   include(joinpath("$(MAKEFILE_DIR)", "table1_invariants.jl")); \
	   print_header(); check_walsh(; save_results=$(save_results))'

multiplier_group:
	@echo "ROOT=$(ROOT)"
	@echo "Multiplier group order [OUT-OF-SCOPE STUB]"
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "helpers.jl")); \
	   include(joinpath("$(MAKEFILE_DIR)", "table1_invariants.jl")); \
	   print_header(); multiplier_group_order()'

proposition1:
	@echo "ROOT=$(ROOT)"
	@echo "Proposition 1: CCZ-distinctness via ortho-derivative (sample_size=$(sample_size), seed=$(seed))"
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "helpers.jl")); \
	   include(joinpath("$(MAKEFILE_DIR)", "proposition1.jl")); \
	   print_header(); ccz_distinctness(; sample_size=$(sample_size), seed=$(seed), save_results=$(save_results))'

algorithm1:
	@echo "ROOT=$(ROOT)"
	@echo "Algorithm 1: QuadraticAPNSearch n=$(n) (seed=$(seed), max_solutions=$(max_solutions))"
	$(JULIA) $(JULIA_PROJECT) -e \
	  'using VBF; include(joinpath("$(MAKEFILE_DIR)", "algorithm1.jl")); \
	   sols = quadratic_apn_search($(n); seed=$(seed), max_solutions=$(max_solutions)); \
	   println("Found: ", length(sols)); for s in sols; println(s.lut); end'

lemma4:
	@echo "ROOT=$(ROOT)"
	@echo "Lemma 4: fixed-point filter demo (identity vs. one-fixed-point map, n=4)"
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "lemma4.jl")); \
	   id4=[0,1,2,3]; one=[0,0,3,2]; \
	   println("fix_A=",fixed_point_count(id4)," fix_B=",fixed_point_count(one)); \
	   println("lemma4_excludes: ",lemma4_excludes(id4,one))'

lemma5:
	@echo "ROOT=$(ROOT)"
	@echo "Lemma 5: cycle-count filter demo (n=8 min cycles)"
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "lemma5.jl")); \
	   for nn in [7,8,9,10]; println("n=",nn," min_cycles=",lemma5_min_cycles(nn)); end'

catalog_validation:
	@echo "ROOT=$(ROOT)"
	@echo "Cross-checking catalog corpus (sample_size=$(sample_size))"
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "helpers.jl")); \
	   include(joinpath("$(MAKEFILE_DIR)", "catalog_validation.jl")); \
	   print_header(); catalog_cross_check(; sample_size=$(sample_size))'

report:
	@echo "ROOT=$(ROOT)"
	@echo "Running paper report (save_results=$(save_results))"
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "report.jl")); \
	   paper_report(; save_results=$(save_results))'

clean_results:
	rm -rf "$(MAKEFILE_DIR)/results"

help:
	@echo 'Beierle & Leander (2022) — New Instances of Quadratic APN Functions'
	@echo ''
	@echo 'Targets:'
	@echo '  dataset_counts      Count lines + well-formedness check on all three datasets'
	@echo '  verify_apn          Verify APN property (differential_uniformity == 2)'
	@echo '  verify_quadratic    Verify algebraic degree == 2'
	@echo '  table1_invariants   Report unsupported Table1 reconstruction'
	@echo '  walsh_spectrum      Report unsupported Table1 reconstruction'
	@echo '  multiplier_group    Multiplier group order stub (out-of-scope, prints TODO)'
	@echo '  proposition1        Proposition 1: CCZ-distinctness via ortho-derivative vs. Gold family'
	@echo '  algorithm1          Algorithm 1: QuadraticAPNSearch (params: n, seed, max_solutions)'
	@echo '  lemma4              Lemma 4: fixed-point filter demo'
	@echo '  lemma5              Lemma 5: cycle-count filter demo'
	@echo '  catalog_validation  Cross-check dim-8 dataset against VBFCatalog corpus'
	@echo '  report              Fast summary report (no heavy searches)'
	@echo '  test                Run all tests'
	@echo '  clean_results       Remove generated files under results/'
	@echo ''
	@echo 'Parameters (override with make target param=value):'
	@echo '  limit=$(limit)'
	@echo '  sample_size=$(sample_size)    (0 = exhaustive where supported)'
	@echo '  save_results=$(save_results)  (true writes to results/)'
	@echo '  seed=$(seed)'
	@echo '  full_search=$(full_search)    (true for exhaustive dim-8 runs)'
	@echo '  max_dim=$(max_dim)            (table1_invariants upper dimension bound)'
