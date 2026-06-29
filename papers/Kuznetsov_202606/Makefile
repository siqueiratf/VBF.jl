JULIA ?= julia
MAKEFILE_DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
ROOT := $(abspath $(MAKEFILE_DIR)/../..)
JULIA_PROJECT := --project=$(ROOT)

.PHONY: help test report section4 algorithm1 theorem4 table2 table3 phase2 clean_results \
        survey basis searchers clean_build

# Overridable parameters
sample_size ?= 100
seed        ?= 42

# GPGPU extension parameters / toolchain
n        ?= 8
class    ?= 22
HIPCC    ?= /opt/rocm/bin/hipcc
GPU_ARCH ?= native
HIPFLAGS ?= -O3 -munsafe-fp-atomics --offload-arch=$(GPU_ARCH)
CXX      ?= g++
CXXFLAGS ?= -O3 -fopenmp

default: help

test:
	$(JULIA) $(JULIA_PROJECT) -e 'using Pkg; Pkg.instantiate()'
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/test/runtests.jl

report:
	SAMPLE_SIZE=$(sample_size) SEED=$(seed) \
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/report.jl

section4:
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "section4.jl")); section4_report()'

algorithm1:
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "algorithm1.jl")); \
	   algorithm1_report(stdout; sample_size=$(sample_size), seed=$(seed))'

theorem4:
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "theorem4.jl")); theorem4_report()'

table2:
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "table2.jl")); table2_report()'

table3:
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "table3.jl")); table3_report()'

phase2:
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "report.jl")); phase2_report()'

clean_results:
	rm -rf "$(MAKEFILE_DIR)/results"

# ── GPGPU extension (BBL2021 class census) ────────────────────────────────────
# dim(V_A) feasibility map across all classes
survey:
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/survey.jl

# generate bilinear-row basis for (n, class): basis_n<n>_c<class>_rows.bin
basis:
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/generate_rows.jl $(n) $(class)

# build the GPU searcher (one source, -DDIM_N per dimension) + CPU classifier
searchers: apn_search_n8 apn_search_n7 fast_checker

apn_search_n8: apn_search.cpp
	$(HIPCC) $(HIPFLAGS) -DDIM_N=8 -o $@ $<

apn_search_n7: apn_search.cpp
	$(HIPCC) $(HIPFLAGS) -DDIM_N=7 -o $@ $<

fast_checker: fast_checker.cpp
	$(CXX) $(CXXFLAGS) -o $@ $<

clean_build:
	rm -f apn_search_n8 apn_search_n7 fast_checker

# ── Phase 2: novelty oracle ───────────────────────────────────────────────────
# fetch known dim-8 quadratic-APN catalogs (BLP22; add full=1 for the 2025 3.78M set)
catalog:
	./fetch_catalog.sh $(if $(filter 1,$(full)),--full,)

# representation sanity + paper-novelty validation + build/cache the σ-index oracle
novelty:
	$(JULIA) $(JULIA_PROJECT) -t auto $(MAKEFILE_DIR)/novelty_report.jl

help:
	@echo 'Paper: Kuznetsov (2026) — Quadratic APN Functions via Gröbner Basis Search'
	@echo 'Paper targets:  test  report  section4  algorithm1  theorem4  table2  table3  phase2  clean_results'
	@echo 'GPGPU targets:  survey  basis  searchers  clean_build'
	@echo 'Phase-2 targets: catalog [full=1]  novelty'
	@echo 'Params:         sample_size=$(sample_size)  seed=$(seed)  n=$(n)  class=$(class)  GPU_ARCH=$(GPU_ARCH)'
