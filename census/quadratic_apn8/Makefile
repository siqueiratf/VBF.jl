JULIA ?= julia

MAKEFILE_DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
ROOT := $(abspath $(MAKEFILE_DIR)/../..)
JULIA_PROJECT := --project=$(ROOT)
RESULTS := $(MAKEFILE_DIR)results
# Legacy run (read-only): s1.tsv + chunks c101..c140 = 4,012,000 samples.
LEGACY := $(ROOT)/papers/2025/Beierle_202508/results/class_count
LEGACY_DATA := $(LEGACY)/s1.tsv $(LEGACY)/chunks

.PHONY: help test validate exact_masses sample reproduce estimate analyze report \
        spot_check properties clean_results

# Threads. The RNG scheme depends on it: byte-identical chunks need the same value.
threads ?= 12
# sample: chunks c<first_seed> .. c<first_seed+chunks-1>, `samples` lines each.
first_seed ?= 101
chunks ?= 1
samples ?= 100000
n ?= 8
m ?= 8
outdir ?= $(RESULTS)/chunks
# reproduce: regenerate one chunk and compare byte for byte with `ref`.
seed ?= 1
ref_samples ?= 12000
ref ?= $(LEGACY)/s1.tsv
# analyze / report / estimate: files and/or directories of sample TSVs.
data ?= $(LEGACY_DATA)
# validate / report: bounded sample counts for the small-n checks.
val_seed ?= 7
samples66 ?= 200000
samples77 ?= 200000
data77 ?=
# exact_masses: catalog dimensions (n = 7 takes minutes); report: 0 skips recomputation.
nmin ?= 4
nmax ?= 6
exact_nmax ?= 0
save_results ?= true
# diagnostics
per_corpus ?= 20
coeffs ?=
aut ?= false

default: help

test:
	$(JULIA) $(JULIA_PROJECT) -e 'using Pkg; Pkg.instantiate()'
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)test/runtests.jl

validate:
	@echo "Validation (6,6) plain Knuth samples66=$(samples66); (7,7) pipeline samples77=$(samples77) threads=$(threads) seed=$(val_seed) data77=$(data77)"
	$(JULIA) $(JULIA_PROJECT) -t $(threads) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "validate.jl")); print_header(); \
	   r = validate_report(; samples66=$(samples66), samples77=$(samples77), seed=$(val_seed), data77=ARGS[1]); \
	   r["pass"] || exit(1)' "$(data77)"

exact_masses:
	@echo "Exact masses from the catalog, n=$(nmin)..$(nmax)"
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "exact_masses.jl")); print_header(); \
	   exact_masses($(nmin), $(nmax))'

sample:
	@echo "Sampling (n,m)=($(n),$(m)) seeds $(first_seed)..+$(chunks) samples=$(samples) threads=$(threads) -> $(outdir)"
	$(JULIA) $(JULIA_PROJECT) -t $(threads) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "sampler.jl")); \
	   run_sampling(; outdir=ARGS[1], first_seed=$(first_seed), nchunks=$(chunks), samples=$(samples), threads=$(threads), n=$(n), m=$(m))' "$(outdir)"

reproduce:
	@echo "Reproducing seed=$(seed) samples=$(ref_samples) threads=$(threads) against $(ref)"
	$(JULIA) $(JULIA_PROJECT) -t $(threads) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "sampler.jl")); \
	   ok = reproduce_check(; ref=ARGS[1], seed=$(seed), samples=$(ref_samples), threads=$(threads), n=$(n), m=$(m), outdir=ARGS[2]); \
	   ok || exit(1)' "$(ref)" "$(RESULTS)/repro"

estimate:
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "analyze.jl")); \
	   estimate_report(expand_paths(ARGS[1]), $(n), $(m))' "$(data)"

analyze:
	@echo "Analyzing $(data)"
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "analyze.jl")); print_header(); \
	   analyze_census(expand_paths(ARGS[1]); new_path=joinpath(ARGS[2], "new_sigma.tsv"))' \
	  "$(data)" "$(RESULTS)"

report:
	@echo "Report: data=$(data) samples66=$(samples66) samples77=$(samples77) threads=$(threads) exact_nmax=$(exact_nmax)"
	$(JULIA) $(JULIA_PROJECT) -t $(threads) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "report.jl")); \
	   census_report(; data=ARGS[1], samples66=$(samples66), samples77=$(samples77), seed=$(val_seed), data77=ARGS[2], exact_nmax=$(exact_nmax), save_results=$(save_results))' "$(data)" "$(data77)"

spot_check:
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "diagnostics.jl")); spot_check(; per_corpus=$(per_corpus))'

properties:
	@test -n "$(coeffs)" || (echo "set coeffs=<56 hex digits>"; exit 1)
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "diagnostics.jl")); \
	   for c in split(ARGS[1]); properties(c; aut=$(aut)); end' "$(coeffs)"

clean_results:
	rm -rf "$(RESULTS)"

help:
	@echo 'Census: number of CCZ classes of quadratic APN functions on F_2^8'
	@echo 'Targets:'
	@echo '  test           Fast unit tests (< 2 min): T(n,m), counters FL/FL2/FL3 vs QK2,'
	@echo '                 (5,5) mass, coefficient strings, APN leaves, RNG reproducibility'
	@echo '  validate       (6,6) plain Knuth and (7,7) pipeline vs exact masses (|z| < 4)'
	@echo '  exact_masses   Recompute exact masses sum 2^n/|Aut| from the catalog (nmin..nmax)'
	@echo '  sample         Write chunks results/chunks/c<seed>.tsv (resumes; keeps existing chunks)'
	@echo '  reproduce      Regenerate one chunk and compare byte for byte with ref'
	@echo '  estimate       Mass estimate of (n,m) sample files in data'
	@echo '  analyze        Mass, sigma coverage, N estimates, new sigma list (results/new_sigma.tsv)'
	@echo '  report         Exact counts + validate + analyze -> results/report.toml'
	@echo '  spot_check     Recompute sigma hashes of random corpus members against the index'
	@echo '  properties     Invariants of coefficient strings (coeffs=...; aut=true is slow)'
	@echo '  clean_results  Remove generated files under results/'
	@echo ''
	@echo 'Parameters (override with make target param=value):'
	@echo '  threads=$(threads)          Julia threads; byte-identical chunks need the same value'
	@echo '  first_seed=$(first_seed) chunks=$(chunks) samples=$(samples)   sample: seeds and chunk size'
	@echo '  n=$(n) m=$(m)                sample/reproduce/estimate dimensions'
	@echo '  outdir=$(outdir)'
	@echo '  seed=$(seed) ref_samples=$(ref_samples)   reproduce: seed and size of the reference chunk'
	@echo '  ref=$(ref)'
	@echo '  data=$(data)'
	@echo '                      analyze/report/estimate input: files and/or directories of *.tsv'
	@echo '                      (default: the legacy 4,012,000-sample run; own runs: data=$(RESULTS)/chunks)'
	@echo '  samples66=$(samples66) samples77=$(samples77) val_seed=$(val_seed)   validate sample counts'
	@echo '  data77=$(data77)                 validate: existing (7,7) files instead of sampling'
	@echo '  nmin=$(nmin) nmax=$(nmax)            exact_masses dimensions (nmax=7 takes minutes)'
	@echo '  exact_nmax=$(exact_nmax)            report: recompute exact masses up to n (0 = skip)'
	@echo '  save_results=$(save_results)       report: write results/report.toml'
	@echo '  per_corpus=$(per_corpus) coeffs=$(coeffs) aut=$(aut)   diagnostics'
	@echo ''
	@echo 'Examples:'
	@echo '  make reproduce                                  # s1.tsv: seed 1, 12000 samples, 12 threads'
	@echo '  make reproduce seed=101 ref_samples=100000 ref=$(LEGACY)/chunks/c101.tsv'
	@echo '  make sample first_seed=141 chunks=10            # 1,000,000 new samples'
	@echo '  make analyze data="$(LEGACY_DATA) $(RESULTS)/chunks"'
