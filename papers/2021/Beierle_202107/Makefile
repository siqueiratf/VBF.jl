JULIA ?= julia

MAKEFILE_DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
ROOT := $(abspath $(MAKEFILE_DIR)/../../..)
JULIA_PROJECT := --project=$(ROOT)

.PHONY: help test algorithm1 corollary1_n6n7n8

save_results ?= true
max_solutions ?= 1
timeout_seconds ?= 300
class_indices ?= all
n_value = $(if $(n),$(n),6)

default: help

test:
	$(JULIA) $(JULIA_PROJECT) -e 'using Pkg; Pkg.instantiate()'
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/test/runtests.jl

corollary1_n6n7n8:
	@echo "ROOT=$(ROOT)"
	@if [ -z "$(n)" ]; then \
		$(MAKE) -f "$(MAKEFILE_DIR)/Makefile" corollary1_n6n7n8 n=6 && \
		$(MAKE) -f "$(MAKEFILE_DIR)/Makefile" corollary1_n6n7n8 n=7 && \
		$(MAKE) -f "$(MAKEFILE_DIR)/Makefile" corollary1_n6n7n8 n=8; \
	else \
		echo "Running Corollary 1 with n=$(n)"; \
		$(JULIA) $(JULIA_PROJECT) -e 'include(joinpath("$(MAKEFILE_DIR)", "corollary1_n6n7n8.jl")); tuples_dir = joinpath("$(MAKEFILE_DIR)", "tuples"); mkpath(tuples_dir); tuple_filename = joinpath(tuples_dir, "AllTuples$(n).toml"); matrix_filename = joinpath(tuples_dir, "AllTuplesMatrices$(n).toml"); println(tuple_filename); println(matrix_filename)'; \
	fi

algorithm1:
	@echo "ROOT=$(ROOT)"
	@echo "Running Algorithm 1 with n=$(n_value), save_results=$(save_results), max_solutions=$(max_solutions), timeout_seconds=$(timeout_seconds), class_indices=$(class_indices)"
	$(JULIA) $(JULIA_PROJECT) -e 'filename = joinpath("$(MAKEFILE_DIR)", "tuples", "AllTuplesMatrices$(n_value).toml"); if !isfile(filename) println(stderr, "please generate the precomputed matrices using `make corollary1_n6n7n8 n=$(n_value)`"); exit(1); end'
	$(JULIA) $(JULIA_PROJECT) -e 'include(joinpath("$(MAKEFILE_DIR)", "algorithm1.jl")); r = APNSearchClasses($(n_value), "$(class_indices)"; save_results=$(save_results), max_solutions=$(max_solutions), timeout_seconds=$(timeout_seconds), tuples_dir = joinpath("$(MAKEFILE_DIR)", "tuples")); println(); println("--- Algorithm 1 outcome summary (n=$(n_value), timeout_seconds=$(timeout_seconds)) ---"); print_apn_search_summary(r); println("A class listed under BUDGET HIT is UNEXAMINED, not empty. Only PROVED empty"); println("classes may be reported as Table 1'"'"'s \"no (Alg. 1)\".")'

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
	@echo '  help            Show this help message'
