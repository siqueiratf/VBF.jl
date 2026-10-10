include $(dir $(abspath $(lastword $(MAKEFILE_LIST))))../../paper.mk


.PHONY: help test algorithm1 corollary1_n6n7n8

save_results ?= true
max_solutions ?= 1
timeout_seconds ?= 300
class_indices ?= all
full_search ?= false
save_evidence ?= false
commutant_pruning ?= true
pruning_depth ?= 3
extendability_seeding ?= true
output ?= $(MAKEFILE_DIR)/results/AllTuplesMatrices$(n_value).toml
n_value = $(if $(n),$(n),6)

default: help

test:
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/test/runtests.jl

corollary1_n6n7n8:
	$(JULIA) $(JULIA_PROJECT) -e 'include(joinpath("$(MAKEFILE_DIR)", "corollary1_n6n7n8.jl")); r=generate_tuple_matrix_constants_file($(n_value); output="$(output)", full_search=$(full_search)); println("generated count=",r.count," output=",r.output); println("same extended-power-similarity classes as committed=",verify_generated_tuple_classes($(n_value),r.blocks))'

algorithm1:
	@echo "ROOT=$(ROOT)"
	@echo "Running Algorithm 1 with n=$(n_value), save_results=$(save_results), max_solutions=$(max_solutions), timeout_seconds=$(timeout_seconds), class_indices=$(class_indices)"
	$(JULIA) $(JULIA_PROJECT) -e 'filename = joinpath("$(MAKEFILE_DIR)", "tuples", "AllTuplesMatrices$(n_value).toml"); if !isfile(filename) println(stderr, "please generate the precomputed matrices using `make corollary1_n6n7n8 n=$(n_value)`"); exit(1); end'
	$(JULIA) $(JULIA_PROJECT) -e 'include(joinpath("$(MAKEFILE_DIR)", "algorithm1.jl")); r = APNSearchClasses($(n_value), "$(class_indices)"; save_results=$(save_results), max_solutions=$(max_solutions), timeout_seconds=$(timeout_seconds), commutant_pruning=$(commutant_pruning), pruning_depth=$(pruning_depth), extendability_seeding=$(extendability_seeding), save_evidence=$(save_evidence), tuples_dir = joinpath("$(MAKEFILE_DIR)", "tuples")); println(); println("--- Algorithm 1 outcome summary (n=$(n_value), timeout_seconds=$(timeout_seconds)) ---"); print_apn_search_summary(r); println("A class listed under BUDGET HIT is UNEXAMINED, not empty. Only PROVED empty"); println("classes may be reported as Table 1'"'"'s \"no (Alg. 1)\".")'

#proposition4:
#...

#proposition5:
#...

#report:
#...

help:
	@echo 'Available commands:'
	@echo '  test            Run tests'
	@echo '  algorithm1      Run Algorithm 1 (search for Beierle et al. 2021)'
	@echo '  corollary1_n6n7n8'
	@echo '                  Generate tuple and matrix constants for Corollary 1'
	@echo '  report          Verify stored controls; incomplete classifications remain explicit'
	@echo '  params: commutant_pruning pruning_depth extendability_seeding save_evidence'
	@echo '  help            Show this help message'

report:
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/report.jl
