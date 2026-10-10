include $(dir $(abspath $(lastword $(MAKEFILE_LIST))))../paper.mk

limit ?= 1
dimension ?= 4
max_evaluations ?= 65536
max_nodes ?= 1000000
sample_size ?= 1
save_results ?= false
seed ?= 940
full_search ?= false
timeout_seconds ?= 30.0
max_subspaces ?= 4096
max_memory_bytes ?= 536870912
max_comparisons ?= 1000
max_frontier ?= 4096
max_neighbors ?= 4096
resume ?= true
per_root_timeout_seconds ?= 60.0
threads ?= 1
workers ?= $(threads)

ARGS = dimension=$(dimension), limit=$(limit), max_evaluations=$(max_evaluations), max_nodes=$(max_nodes), sample_size=$(sample_size), save_results=$(save_results), seed=$(seed), full_search=$(full_search), timeout_seconds=$(timeout_seconds), max_subspaces=$(max_subspaces), max_memory_bytes=$(max_memory_bytes)
SWITCH_ARGS = $(ARGS), max_comparisons=$(max_comparisons), max_frontier=$(max_frontier), max_neighbors=$(max_neighbors)

.PHONY: help test report section31 section32 switching conjecture1 census6 census7 closure6 clean_results
default: help

test:
	$(JULIA) $(JULIA_PROJECT) "$(MAKEFILE_DIR)/test/runtests.jl"

report:
	$(JULIA) $(JULIA_PROJECT) -e 'include(joinpath("$(MAKEFILE_DIR)", "report.jl")); paper_report(seed=$(seed))'

section31:
	$(JULIA) $(JULIA_PROJECT) -e 'include(joinpath("$(MAKEFILE_DIR)", "section31.jl")); section31_report(; $(ARGS))'

section32:
	$(JULIA) $(JULIA_PROJECT) -e 'include(joinpath("$(MAKEFILE_DIR)", "section32.jl")); section32_report(; $(ARGS))'

switching conjecture1:
	$(JULIA) $(JULIA_PROJECT) -e 'include(joinpath("$(MAKEFILE_DIR)", "conjecture1.jl")); conjecture1_report(; $(SWITCH_ARGS))'

# Explicit opt-in: complete six-bit known-class census, including legacy cross-checks.
census6: limit=14
census6: dimension=6
census6: sample_size=14
census6: full_search=true
census6: max_nodes=typemax(Int)
census6: timeout_seconds=1200.0
census6: max_subspaces=1000000
census6: section32

# Independently certified per-root closures; input-root classification is loaded.
census7: limit=488
census7: timeout_seconds=7200.0
census7: max_nodes=typemax(Int)
census7: max_subspaces=1000000
census7:
	$(JULIA) --threads=$(threads) $(JULIA_PROJECT) -e 'include(joinpath("$(MAKEFILE_DIR)", "section32_sevenbit.jl")); section32_sevenbit(limit=$(limit), workers=$(workers), timeout_seconds=$(timeout_seconds), per_root_timeout_seconds=$(per_root_timeout_seconds), max_nodes=$(max_nodes), max_subspaces=$(max_subspaces), max_memory_bytes=$(max_memory_bytes), save_results=$(save_results), resume=$(resume), seed=$(seed))'

closure6: limit=716
closure6: timeout_seconds=7200.0
closure6:
	$(JULIA) --threads=$(threads) $(JULIA_PROJECT) -e 'include(joinpath("$(MAKEFILE_DIR)", "section32_switching.jl")); section32_switching(limit=$(limit), workers=$(workers), timeout_seconds=$(timeout_seconds), max_evaluations=$(max_evaluations), max_nodes=$(max_nodes), max_memory_bytes=$(max_memory_bytes), save_results=$(save_results), resume=$(resume), seed=$(seed))'

clean_results:
	find "$(MAKEFILE_DIR)/results" -type f ! -name .gitkeep -delete

help:
	@echo 'Baudrin, Galissant and Perrin (2025) — Exploring the Set of APN Functions'
	@echo 'Targets: section31 section32 switching conjecture1 census6 census7 closure6 test report clean_results'
	@echo 'section31/section32/switching: bounded demonstrations; report: fast, bounded scope'
	@echo 'census6: expensive explicit full six-bit known-class census and legacy cross-check'
	@echo 'census7: complete seven-bit per-root closures with optimized native groups/subspaces'
	@echo 'closure6: exhaust switching over a saved complete six-bit census; Conjecture 1 remains unproved'
	@echo 'Use save_results=true for per-root/parent checkpoints; resume=true reuses completed rows'
	@echo 'Parameters: dimension limit max_evaluations max_nodes sample_size save_results seed full_search'
	@echo '            timeout_seconds max_subspaces max_memory_bytes'
	@echo 'Switching:  max_comparisons max_frontier max_neighbors'
	@echo 'Census: resume per_root_timeout_seconds; explicit limits also apply to named full targets'
	@echo 'Parallel: threads=16 workers=16 (defaults: one thread/worker)'
