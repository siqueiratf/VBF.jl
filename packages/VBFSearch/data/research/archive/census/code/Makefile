JULIA ?= julia

MAKEFILE_DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
ROOT := $(abspath $(MAKEFILE_DIR)/../..)
JULIA_PROJECT := --project=$(ROOT)
RESULTS := $(MAKEFILE_DIR)results
# Committed compact form of the legacy run (s1.tsv + chunks c101..c140 = 4,012,000
# samples): manifest legacy_chunks.tsv + hit rows legacy_hits.tsv. See README.md.
DATA := $(MAKEFILE_DIR)data
# Full legacy TSV files (about 90 MB, untracked; present only on the original machine).
LEGACY := $(ROOT)/papers/2025/Beierle_202508/results/class_count
LEGACY_DATA := $(LEGACY)/s1.tsv $(LEGACY)/chunks

.PHONY: help test validate exact_masses sample reproduce verify_data compact_data estimate \
        analyze report spot_check properties clean_results \
        kasami_x57 permutation theory_uniqueness crosscheck_raw web_serve search_b52 \
        search_b52_status

# Julia threads (-t). The RNG scheme depends on `streams` (default: threads):
# byte-identical chunks need the same streams value; threads only sets the speed.
threads ?= 12
streams ?= $(threads)
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
# analyze / report / estimate: files and/or directories of sample TSVs, or manifests.
data ?= $(DATA)/legacy_chunks.tsv
# verify_data: regenerate the chunk of `seed` and compare it with its manifest row.
manifest ?= $(DATA)/legacy_chunks.tsv
verify_streams ?= 12
verify_samples = $(shell awk -F'\t' 'NR > 1 && $$2 == $(seed) {print $$3}' "$(manifest)")
# compact_data: full legacy files -> data/ (read-only on legacy)
legacy ?= $(LEGACY)
# Subproject targets: extra arguments for the sub-make.
args ?=
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
	@echo "Sampling (n,m)=($(n),$(m)) seeds $(first_seed)..+$(chunks) samples=$(samples) threads=$(threads) streams=$(streams) -> $(outdir)"
	$(JULIA) $(JULIA_PROJECT) -t $(threads) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "sampler.jl")); \
	   run_sampling(; outdir=ARGS[1], first_seed=$(first_seed), nchunks=$(chunks), samples=$(samples), threads=$(threads), streams=$(streams), n=$(n), m=$(m))' "$(outdir)"

reproduce:
	@echo "Reproducing seed=$(seed) samples=$(ref_samples) threads=$(threads) streams=$(streams) against $(ref)"
	$(JULIA) $(JULIA_PROJECT) -t $(threads) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "sampler.jl")); \
	   ok = reproduce_check(; ref=ARGS[1], seed=$(seed), samples=$(ref_samples), threads=$(threads), streams=$(streams), n=$(n), m=$(m), outdir=ARGS[2]); \
	   ok || exit(1)' "$(ref)" "$(RESULTS)/repro"

# Regenerate one chunk with `make sample` and compare it with the manifest: counts,
# hit rows and SHA-256. The legacy (8,8) chunks need verify_streams=12 (any threads).
verify_data:
	@test -n "$(verify_samples)" || (echo "no row with seed=$(seed) in $(manifest)"; exit 1)
	rm -f "$(RESULTS)/verify/c$(seed).tsv"
	$(MAKE) --no-print-directory sample first_seed=$(seed) chunks=1 samples=$(verify_samples) \
	  streams=$(verify_streams) outdir="$(RESULTS)/verify"
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "helpers.jl")); \
	   verify_sample_file(ARGS[1], ARGS[2]; seed=$(seed)) || exit(1)' \
	  "$(RESULTS)/verify/c$(seed).tsv" "$(manifest)"

# Rewrite data/ from the full legacy files (only on a machine that has them).
compact_data:
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "helpers.jl")); compact_legacy(ARGS[1], ARGS[2])' \
	  "$(legacy)" "$(DATA)"

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

# --- subprojects (each has its own Makefile; skipped when absent) ---------------------
# Command-line parameters (make target threads=4 ...) reach the sub-make through
# MAKEFLAGS; `args` adds more.
define subproject
	@if [ -f "$(MAKEFILE_DIR)$(1)/Makefile" ]; then \
	  $(MAKE) -C "$(MAKEFILE_DIR)$(1)" $(2) $(args); \
	else \
	  echo "skip: $(1)/Makefile not found (target $(2))"; \
	fi
endef

kasami_x57:
	$(call subproject,kasami_x57,check)

permutation:
	$(call subproject,permutation,check)

theory_uniqueness:
	$(call subproject,theory,check_uniqueness)

crosscheck_raw:
	$(call subproject,crosscheck_raw,check)

web_serve:
	$(call subproject,web,serve)

search_b52:
	$(call subproject,search_b52,search)

search_b52_status:
	$(call subproject,search_b52,status)

help:
	@echo 'Census: number of CCZ classes of quadratic APN functions on F_2^8'
	@echo 'Targets:'
	@echo '  test           Fast unit tests (< 2 min): T(n,m), counters FL/FL2/FL3 vs QK2,'
	@echo '                 (5,5) mass, coefficient strings, APN leaves, RNG reproducibility'
	@echo '  validate       (6,6) plain Knuth and (7,7) pipeline vs exact masses (|z| < 4)'
	@echo '  exact_masses   Recompute exact masses sum 2^n/|Aut| from the catalog (nmin..nmax)'
	@echo '  sample         Write chunks results/chunks/c<seed>.tsv (resumes; keeps existing chunks)'
	@echo '  reproduce      Regenerate one chunk and compare byte for byte with ref (full TSV)'
	@echo '  verify_data    Regenerate the chunk of seed (make sample) and check it against the'
	@echo '                 manifest: counts, hit rows, SHA-256 (default: s1, 12000 samples)'
	@echo '  compact_data   Rewrite data/ from the full legacy TSV files (legacy=...)'
	@echo '  estimate       Mass estimate of (n,m) sample files in data'
	@echo '  analyze        Mass, sigma coverage, N estimates, new sigma list (results/new_sigma.tsv)'
	@echo '  report         Exact counts + validate + analyze -> results/report.toml'
	@echo '  spot_check     Recompute sigma hashes of random corpus members against the index'
	@echo '  properties     Invariants of coefficient strings (coeffs=...; aut=true is slow)'
	@echo '  clean_results  Remove generated files under results/'
	@echo ''
	@echo 'Subprojects (skipped when the directory has no Makefile; args="..." adds arguments):'
	@echo '  kasami_x57         make -C kasami_x57 check       (x^57 Kasami class gap)'
	@echo '  permutation        make -C permutation check'
	@echo '  theory_uniqueness  make -C theory check_uniqueness'
	@echo '  crosscheck_raw     make -C crosscheck_raw check   (raw Langevin files)'
	@echo '  web_serve          make -C web serve'
	@echo '  search_b52         make -C search_b52 search'
	@echo '  search_b52_status  make -C search_b52 status'
	@echo ''
	@echo 'Parameters (override with make target param=value):'
	@echo '  threads=$(threads)          Julia threads (speed only)'
	@echo '  streams=$(streams)          RNG streams (default: threads); byte-identical chunks need the same value'
	@echo '  first_seed=$(first_seed) chunks=$(chunks) samples=$(samples)   sample: seeds and chunk size'
	@echo '  n=$(n) m=$(m)                sample/reproduce/estimate dimensions'
	@echo '  outdir=$(outdir)'
	@echo '  seed=$(seed) ref_samples=$(ref_samples)   reproduce: seed and size of the reference chunk'
	@echo '  ref=$(ref)'
	@echo '  data=$(data)'
	@echo '                      analyze/report/estimate input: files and/or directories of *.tsv,'
	@echo '                      or compact manifests *_chunks.tsv (default: data/legacy_chunks.tsv,'
	@echo '                      the legacy 4,012,000-sample run; own runs: data=$(RESULTS)/chunks)'
	@echo '  manifest=$(manifest)'
	@echo '  verify_streams=$(verify_streams)    verify_data: RNG streams of the reference chunk'
	@echo '  legacy=$(legacy)'
	@echo '  samples66=$(samples66) samples77=$(samples77) val_seed=$(val_seed)   validate sample counts'
	@echo '  data77=$(data77)                 validate: existing (7,7) files instead of sampling'
	@echo '  nmin=$(nmin) nmax=$(nmax)            exact_masses dimensions (nmax=7 takes minutes)'
	@echo '  exact_nmax=$(exact_nmax)            report: recompute exact masses up to n (0 = skip)'
	@echo '  save_results=$(save_results)       report: write results/report.toml'
	@echo '  per_corpus=$(per_corpus) coeffs=$(coeffs) aut=$(aut)   diagnostics'
	@echo ''
	@echo 'Examples:'
	@echo '  make analyze                                    # legacy run from data/ (fresh clone)'
	@echo '  make verify_data threads=4                      # s1: seed 1, 12000 samples, 12 streams'
	@echo '  make verify_data seed=101 threads=16            # chunk c101, 100000 samples'
	@echo '  make verify_data seed=7 n=7 m=7 verify_streams=4 manifest=$(DATA)/legacy_s77_chunks.tsv'
	@echo '  make reproduce ref=$(LEGACY)/s1.tsv streams=12 # needs the full legacy files'
	@echo '  make sample first_seed=141 chunks=10            # 1,000,000 new samples'
	@echo '  make analyze data="$(DATA)/legacy_chunks.tsv $(RESULTS)/chunks"'
