# VBFSearch/gpu — GPU-accelerated quadratic-APN search toolkit.
#
# Codebase-agnostic: the C/C++ kernels depend on nothing but a compiler and
# (for the GPU paths) ROCm/HIP. They consume a *level plan* (a binary file, see
# README) and emit APN look-up tables; nothing here needs VBF.jl or any paper.
#
# The one coupled piece is the reference plan generator `qam_plan.jl`, which
# reads the paper reductions to emit plans — see the `qam_plans` target and the
# note in README. Any generator that writes the documented plan format works.
#
# Override on the command line, e.g.:  make searchers GPU_ARCH=gfx90a

HIPCC    ?= /opt/rocm/bin/hipcc
GPU_ARCH ?= gfx1031
HIPFLAGS ?= -O3 -munsafe-fp-atomics --offload-arch=$(GPU_ARCH)
CXX      ?= g++
CXXFLAGS ?= -O3 -fopenmp
CC       ?= gcc
CFLAGS   ?= -O3
JULIA    ?= julia

MAKEFILE_DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
ROOT := $(abspath $(MAKEFILE_DIR)/../../..)

.PHONY: all searchers tools validate_dfs qam_plans clean help survey basis census-test catalog pack
default: help

# ── search kernels ──────────────────────────────────────────────────────────
# flat V_A subspace searcher: byte path (n<=8) + uint16-lane path (n in 9..12).
# GPU-only (unconditional HIP include); build one binary per dimension.
apn_search_n%: apn_search.cpp
	$(HIPCC) $(HIPFLAGS) -DDIM_N=$* -o $@ $<

# QAM depth-first enumerator with the leading-principal / forward-check prune.
# CPU reference (portable) and GPU build from the same source.
qam_dfs_cpu: qam_dfs.cpp
	$(CXX) $(CXXFLAGS) -o $@ $<
qam_dfs_gpu: qam_dfs.cpp
	$(HIPCC) $(HIPFLAGS) -DUSE_GPU -o $@ $<

# ── invariants / helpers (portable C, any n via -DDIM_N) ─────────────────────
ortho_sigma_n%: ortho_sigma.c
	$(CC) $(CFLAGS) -DDIM_N=$* -o $@ $<
ortho_sigma: ortho_sigma.c            # n=8 default
	$(CC) $(CFLAGS) -o $@ $<
fast_checker: fast_checker.cpp
	$(CXX) $(CXXFLAGS) -o $@ $<
# ccz_confirm: split a σ-bucket into true CCZ classes by the complete
# ortho-derivative linear-equivalence decision (OpenMP; portable C, any n).
# ~120-190x faster than the single-threaded Julia ea_mappings it replaces.
ccz_confirm: ccz_confirm.c
	$(CC) $(CFLAGS) -fopenmp -o $@ $<

searchers: apn_search_n8 apn_search_n9 apn_search_n10 apn_search_n11 apn_search_n12 \
           qam_dfs_cpu qam_dfs_gpu
tools: ortho_sigma fast_checker ccz_confirm
all: searchers tools

# ── plan generation (the one codebase-coupled step; needs VBF + the paper reductions) ──
qam_plans:
	cd $(MAKEFILE_DIR) && $(JULIA) --project=$(ROOT) $(MAKEFILE_DIR)/qam_plan.jl all

# ── validation: prove the DFS reproduces the reference oracle ────────────────
# n=5,6,7 diagonal model must give 72 / 32 / 4410; the Yu-Perrin H_8 per-level
# survivors must include the EA-reduced x_7=3 / x_6 domain=96; and the fast
# forward-check prune must be byte-identical to the reference (--verify).
validate_dfs: qam_dfs_cpu qam_plans
	@echo '-- diagonal model vs oracle (expect 72 / 32 / 4410) --'
	@for n in 5 6 7; do ./qam_dfs_cpu plan_diag_n$$n.bin | grep 'QAM leaves'; done
	@echo '-- H_8 per-level survivors (EA-reduced x_7=3, x_6 domain=96) --'
	./qam_dfs_cpu plan_h8.bin --trace
	@echo '-- fast prune byte-identity (expect 0 mismatches) --'
	./qam_dfs_cpu plan_h8_bench.bin --verify

# ── Kuznetsov (2026) self-equivalence census (census/) ───────────────────────
# Reuses the BBL2021 tuples from VBFRepro; apn_search consumes the basis files.
n     ?= 8
class ?= 22

survey:                                # dim(V_A) feasibility map over all classes
	$(JULIA) --project=$(ROOT) $(MAKEFILE_DIR)census/survey.jl

basis:                                 # writes basis_n<n>_c<class>_rows.bin here
	cd $(MAKEFILE_DIR) && $(JULIA) --project=$(ROOT) $(MAKEFILE_DIR)census/generate_rows.jl $(n) $(class)

census-test:
	$(JULIA) --project=$(ROOT) $(MAKEFILE_DIR)census/test/runtests.jl

catalog:                               # known dim-8 catalogs into catalogs/; full=1 adds the 2025 set
	cd $(MAKEFILE_DIR) && ./census/fetch_catalog.sh $(if $(filter 1,$(full)),--full,)

pack:                                  # usage: make pack in=catalogs/apn8_blp2025.txt [out=...anf]
	cd $(MAKEFILE_DIR) && $(JULIA) --project=$(ROOT) $(MAKEFILE_DIR)census/pack_catalog.jl $(in) $(out)

clean:
	rm -f apn_search_n* qam_dfs_cpu qam_dfs_gpu qam_frontier ortho_sigma ortho_sigma_n* fast_checker ccz_confirm *.bin

help:
	@echo 'VBFSearch/gpu — GPU quadratic-APN search toolkit (codebase-agnostic)'
	@echo 'Targets: all  searchers  tools  qam_plans  validate_dfs  clean'
	@echo 'Census : survey  basis n=$(n) class=$(class)  census-test  catalog [full=1]  pack in=<txt>'
	@echo 'Params : GPU_ARCH=$(GPU_ARCH)  HIPCC=$(HIPCC)  CXX=$(CXX)  JULIA=$(JULIA)'
	@echo 'Per-dim: apn_search_n{8..12}  ortho_sigma_n{5..12}'
	@echo 'See README.md for the level-plan format and the calibration/validated results.'
