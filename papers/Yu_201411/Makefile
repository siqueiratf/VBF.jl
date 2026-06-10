JULIA ?= julia

MAKEFILE_DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
ROOT := $(abspath $(MAKEFILE_DIR)/../..)
JULIA_PROJECT := --project=$(ROOT)

.PHONY: help test theorem1 algorithm1 search run exhaustive_search compare_results report clean_results

save_results    ?= false
n               ?= 5
limit           ?= 1
max_nodes       ?= 9223372036854775807
max_evaluations ?= 16777216
run_full_n5     ?= true
run_full_n6     ?= false
threads         ?= auto
expected_classes ?= nothing
modulus         ?= nothing
generator       ?= 2
generator_symbol ?= g
variable_symbol ?= x
validate_field  ?= true
result_file     ?= $(MAKEFILE_DIR)/results/qam_full_n$(n).toml
reference_file  ?= $(MAKEFILE_DIR)/results/published_n$(n).toml
dedup           ?= ea
resume          ?= true
threaded        ?= true
max_chunks      ?= 9223372036854775807
limit_classes   ?= 9223372036854775807
max_evaluations_per_chunk ?= 9223372036854775807
checkpoint_every_chunks ?= 1
GPU             ?= false
gpu_device      ?= 5
gpu_batch_size  ?= 1048576
gpu_pipeline_depth ?= 3
gpu_suffix_entries ?= nothing
gpu_result_capacity ?= 1048576

GPU_RUN_ENV :=
ifeq ($(GPU),true)
GPU_RUN_ENV := LD_LIBRARY_PATH=
endif

default: help

test:
	$(JULIA) $(JULIA_PROJECT) -e 'using Pkg; Pkg.instantiate()'
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/test/runtests.jl

theorem1:
	@echo "ROOT=$(ROOT)"
	@echo "Theorem 1: QAM/APN correspondence"
	$(JULIA) $(JULIA_PROJECT) -e 'include(joinpath("$(MAKEFILE_DIR)", "theorem1.jl")); print_header(); theorem1_report(; save_results=$(save_results))'

algorithm1:
	@echo "ROOT=$(ROOT)"
	@echo "Algorithm 1: GenerateQAM n=$(n), limit=$(limit)"
	$(JULIA) $(JULIA_PROJECT) -e 'include(joinpath("$(MAKEFILE_DIR)", "algorithm1.jl")); print_header(); algorithm1_report(; n=$(n), limit=$(limit), max_nodes=$(max_nodes), run_full_n5=false, run_full_n6=false, max_evaluations=$(max_evaluations), save_results=$(save_results))'

search:
	@echo "ROOT=$(ROOT)"
	@echo "QAM searches: n=$(n), run_full_n5=$(run_full_n5), run_full_n6=$(run_full_n6)"
	$(JULIA) $(JULIA_PROJECT) -e 'include(joinpath("$(MAKEFILE_DIR)", "algorithm1.jl")); print_header(); algorithm1_report(; n=$(n), limit=$(limit), max_nodes=$(max_nodes), run_full_n5=$(run_full_n5), run_full_n6=$(run_full_n6), max_evaluations=$(max_evaluations), save_results=$(save_results))'

run: exhaustive_search

exhaustive_search:
	@echo "ROOT=$(ROOT)"
	@echo "Long-running full QAM search: n=$(n), threads=$(threads), GPU=$(GPU), gpu_device=$(gpu_device), gpu_batch_size=$(gpu_batch_size), gpu_pipeline_depth=$(gpu_pipeline_depth), gpu_suffix_entries=$(gpu_suffix_entries), gpu_result_capacity=$(gpu_result_capacity), result_file=$(result_file)"
	$(GPU_RUN_ENV) QAM_GPU=$(GPU) QAM_GPU_DEVICE=$(gpu_device) QAM_GPU_BATCH_SIZE=$(gpu_batch_size) QAM_GPU_PIPELINE_DEPTH=$(gpu_pipeline_depth) QAM_GPU_SUFFIX_ENTRIES=$(gpu_suffix_entries) QAM_GPU_RESULT_CAPACITY=$(gpu_result_capacity) $(JULIA) --threads=$(threads) $(JULIA_PROJECT) -e 'include(joinpath("$(MAKEFILE_DIR)", "exhaustive_search.jl")); print_header(); exhaustive_search_report(; n=$(n), expected_classes=$(expected_classes), modulus=$(modulus), generator=$(generator), generator_symbol="$(generator_symbol)", variable_symbol="$(variable_symbol)", validate_field=$(validate_field), result_file="$(result_file)", resume=$(resume), threaded=$(threaded), dedup=Symbol("$(dedup)"), limit_classes=$(limit_classes), max_chunks=$(max_chunks), max_evaluations_per_chunk=$(max_evaluations_per_chunk), checkpoint_every_chunks=$(checkpoint_every_chunks), use_gpu=$(GPU), gpu_device=$(gpu_device), gpu_batch_size=$(gpu_batch_size), gpu_pipeline_depth=$(gpu_pipeline_depth), gpu_suffix_entries=$(gpu_suffix_entries), gpu_result_capacity=$(gpu_result_capacity))'

compare_results:
	@echo "ROOT=$(ROOT)"
	@echo "Comparing $(result_file) with $(reference_file)"
	$(JULIA) $(JULIA_PROJECT) -e 'include(joinpath("$(MAKEFILE_DIR)", "exhaustive_search.jl")); r = compare_result_sets("$(result_file)", "$(reference_file)"; equivalence = Symbol("$(dedup)")); println(r)'

report:
	@echo "ROOT=$(ROOT)"
	@echo "Running Yu-Wang-Li (2014) report"
	$(JULIA) $(JULIA_PROJECT) -e 'include(joinpath("$(MAKEFILE_DIR)", "report.jl")); paper_report(; save_results=$(save_results), algorithm1_n=$(n), algorithm1_limit=$(limit), max_nodes=$(max_nodes), run_full_n5=$(run_full_n5), run_full_n6=$(run_full_n6), max_evaluations=$(max_evaluations))'

clean_results:
	rm -rf "$(MAKEFILE_DIR)/results"

help:
	@echo 'Yu, Wang, Li (2014) - Matrix Approach for Quadratic APN Functions'
	@echo ''
	@echo 'Targets:'
	@echo '  theorem1       Theorem 1: restricted quadratic APN <-> QAM'
	@echo '  algorithm1     Algorithm 1 GenerateQAM only (bounded by limit/max_nodes)'
	@echo '  search         Algorithm 1 plus optional full n=5/n=6 QAM searches'
	@echo '  run            Alias for exhaustive_search'
	@echo '  exhaustive_search  Long-running resumable full QAM search'
	@echo '  compare_results    Compare persisted search results with imported published reps'
	@echo '  report         Default aggregate report'
	@echo '  test           Run paper tests'
	@echo '  clean_results  Remove generated files under results/'
	@echo ''
	@echo 'Parameters (override with make target param=value):'
	@echo '  n=$(n)'
	@echo '  limit=$(limit)'
	@echo '  max_nodes=$(max_nodes)'
	@echo '  max_evaluations=$(max_evaluations)'
	@echo '  run_full_n5=$(run_full_n5)'
	@echo '  run_full_n6=$(run_full_n6)  (true runs the 13-class n=6 check)'
	@echo '  threads=$(threads)'
	@echo '  expected_classes=$(expected_classes)'
	@echo '  modulus=$(modulus)          (nothing = conway_polynomial(n))'
	@echo '  generator=$(generator)'
	@echo '  generator_symbol=$(generator_symbol)'
	@echo '  variable_symbol=$(variable_symbol)'
	@echo '  validate_field=$(validate_field)'
	@echo '  result_file=$(result_file)'
	@echo '  reference_file=$(reference_file)'
	@echo '  dedup=$(dedup)              (ea or mugshot)'
	@echo '  resume=$(resume)'
	@echo '  threaded=$(threaded)'
	@echo '  max_chunks=$(max_chunks)'
	@echo '  limit_classes=$(limit_classes)'
	@echo '  max_evaluations_per_chunk=$(max_evaluations_per_chunk)'
	@echo '  checkpoint_every_chunks=$(checkpoint_every_chunks)'
	@echo '  GPU=$(GPU)                    (true enables CUDA backend)'
	@echo '  gpu_device=$(gpu_device)      (CUDA.device! index for GPU=true)'
	@echo '  gpu_batch_size=$(gpu_batch_size)'
	@echo '  gpu_pipeline_depth=$(gpu_pipeline_depth)'
	@echo '  gpu_suffix_entries=$(gpu_suffix_entries)  (nothing = maximum UInt64 suffix width)'
	@echo '  gpu_result_capacity=$(gpu_result_capacity)'
	@echo '  save_results=$(save_results)'
