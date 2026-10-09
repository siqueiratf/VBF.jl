JULIA ?= julia

MAKEFILE_DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
ROOT := $(abspath $(MAKEFILE_DIR)/../../..)
JULIA_PROJECT := --project=$(ROOT)
RESULTS := $(MAKEFILE_DIR)results

.PHONY: help table seeds test validate search status novelty report index

# Julia threads (the search spawns one worker per thread).
threads ?= 2
# search
outdir ?= $(RESULTS)/run
mode ?= v5
max_seeds ?= 10
max_u_per_seed ?= 0
timeout_seconds ?= 1200
v5_bent ?= max
enqueue_b6 ?= 52
dedupe ?= true
progress_seconds ?= 60
seeds ?= $(RESULTS)/seeds_b52.tsv
# validate / novelty
nseeds ?= 10
outdirs ?= $(outdir)
profiles ?= 10
write_table ?= true

default: help

seeds:
	$(JULIA) $(JULIA_PROJECT) -e 'include(joinpath("$(MAKEFILE_DIR)", "search.jl")); write_seeds(ARGS[1])' "$(seeds)"

index:
	$(JULIA) $(JULIA_PROJECT) -e 'include(joinpath("$(MAKEFILE_DIR)", "common.jl")); index_set(; rebuild = true)'

table:
	$(JULIA) $(JULIA_PROJECT) -t $(threads) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "table.jl")); build_table(; write_table = $(write_table)) || exit(1)'

test:
	$(JULIA) $(JULIA_PROJECT) -t $(threads) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "validate.jl")); validate_all(; quick = true) || exit(1)'

validate:
	$(JULIA) $(JULIA_PROJECT) -t $(threads) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "validate.jl")); validate_all(; quick = false, nseeds = $(nseeds)) || exit(1)'

search:
	@test -f "$(seeds)" || $(MAKE) -f $(MAKEFILE_DIR)Makefile seeds seeds="$(seeds)"
	$(JULIA) $(JULIA_PROJECT) -t $(threads) -e 'include(joinpath("$(MAKEFILE_DIR)", "search.jl")); cli_search(ARGS)' \
	  outdir="$(outdir)" seeds="$(seeds)" mode=$(mode) max_seeds=$(max_seeds) max_u_per_seed=$(max_u_per_seed) \
	  timeout_seconds=$(timeout_seconds) v5_bent=$(v5_bent) enqueue_b6=$(enqueue_b6) dedupe=$(dedupe) \
	  progress_seconds=$(progress_seconds)

status:
	$(JULIA) $(JULIA_PROJECT) -e 'include(joinpath("$(MAKEFILE_DIR)", "report.jl")); search_status(ARGS[1])' "$(outdir)"

novelty:
	$(JULIA) $(JULIA_PROJECT) -e 'include(joinpath("$(MAKEFILE_DIR)", "report.jl")); novelty_report(String.(split(ARGS[1])); profiles = $(profiles)) || exit(1)' "$(outdirs)"

report: novelty

help:
	@echo 'B6 = 52 extension search: (8,6) -> (8,8) Fourier extension of quadratic APN seeds'
	@echo 'Targets:'
	@echo '  seeds      Write results/seeds_b52.tsv (B6 = 52 census hits: 355 new first, then 6 known)'
	@echo '  index      Rebuild the binary sigma cache results/index/sigma_n8.bin from ccz_sigma_index.sqlite'
	@echo '  table      2^28 Walsh table of the flat indicator (results/tables/fhat8.bin, 512 MB) and checks'
	@echo '  test       Fast validation (about 1 min): n = 6 analog on a subset, n = 8 on 2 seeds'
	@echo '  validate   Full validation (about 3 min with 2 threads)'
	@echo '  search     Run or resume the search in outdir (stops at max_seeds, timeout_seconds or empty queue)'
	@echo '  status     Progress of the run in outdir'
	@echo '  novelty    Re-verify every search-new function of outdirs and summarize (alias: report)'
	@echo ''
	@echo 'Parameters (make target param=value):'
	@echo '  threads=$(threads)             Julia threads = search workers (Framework desktop: 30)'
	@echo '  outdir=$(outdir)'
	@echo '  mode=$(mode)                 v5 (U = V5 + <x>, default) or comp (U inside Comp(F), the literal method)'
	@echo '  max_seeds=$(max_seeds)            seeds to complete in this invocation (0 = no limit)'
	@echo '  max_u_per_seed=$(max_u_per_seed)        U (= x) per seed (0 = no limit)'
	@echo '  timeout_seconds=$(timeout_seconds)    wall-clock limit (0 = none); running seeds are redone on resume'
	@echo '  v5_bent=$(v5_bent)             bent counts of the V5 used: max, or a list such as 30,28'
	@echo '  enqueue_b6=$(enqueue_b6)           B6 of search-new functions that become seeds (-1 = all)'
	@echo '  dedupe=$(dedupe)            skip V5/U whose class key was processed'
	@echo '  seeds=$(seeds)'
	@echo '  nseeds=$(nseeds) (validate)  outdirs="$(outdirs)" profiles=$(profiles) (novelty)'
	@echo ''
	@echo 'Examples:'
	@echo '  make test'
	@echo '  make search threads=30 max_seeds=0 timeout_seconds=86400 outdir=$(RESULTS)/desk1'
	@echo '  make status outdir=$(RESULTS)/desk1'
	@echo '  make novelty outdirs="$(RESULTS)/desk1 $(RESULTS)/trial"'
