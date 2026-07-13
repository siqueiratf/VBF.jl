JULIA ?= julia

MAKEFILE_DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
ROOT := $(abspath $(MAKEFILE_DIR)/../..)
JULIA_PROJECT := --project=$(ROOT)

.PHONY: help test report clean_results \
        lemma2_1 lemma3_2 theorem3_3 theoremC_3 lemma4_5 lemma4_7 \
        lemmaA_1 theorem4_8 theorem5_1 theorem6_1 lemmaB_2 theoremB_3

# Overridable parameters
limit           ?= 2147483647
max_evaluations ?= 1048576
sample_size     ?= 3
save_results    ?= false
seed            ?= 42
full_search     ?= false
m               ?= 6

default: help

test:
	$(JULIA) $(JULIA_PROJECT) -e 'using Pkg; Pkg.instantiate()'
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/test/runtests.jl

report:
	@echo "ROOT=$(ROOT)"
	@echo "Full paper report (full_search=$(full_search), save_results=$(save_results))"
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "report.jl")); \
	   paper_report(; full_search=$(full_search), save_results=$(save_results))'

lemma2_1:
	@echo "Lemma 2.1: biprojective APN criterion vs differential_uniformity"
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "lemma2_1.jl")); \
	   print_header(); lemma2_1_report(; limit=$(limit))'

lemma3_2:
	@echo "Lemma 3.2: gcd identities for q = 2^k, r = qQ"
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "lemma3_2.jl")); \
	   print_header(); lemma3_2_report()'

theorem3_3:
	@echo "Theorem 3.3: the new APN family F4 (m=$(m), full_search=$(full_search))"
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "theorem3_3.jl")); \
	   print_header(); theorem3_3_report(; m=$(m), full_search=$(full_search), save_results=$(save_results))'

theoremC_3:
	@echo "Theorem C.3: F4 is 3-to-1 with classical Walsh spectrum (m=$(m))"
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "theoremC_3.jl")); \
	   print_header(); theoremC_3_report(; m=$(m), sample_size=$(sample_size))'

lemma4_5:
	@echo "Lemma 4.5: Z^{(q,r)} <= Aut_EL(F)"
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "lemma4_5.jl")); \
	   print_header(); lemma4_5_report()'

lemma4_7:
	@echo "Lemma 4.7: normalizer / centralizer of M and M_P in GL(F)"
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "lemma4_7.jl")); \
	   print_header(); lemma4_7_report()'

lemmaA_1:
	@echo "Lemma A.1: centralizer C_F and condition (C)"
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "lemmaA_1.jl")); \
	   print_header(); lemmaA_1_report()'

theorem4_8:
	@echo "Theorem 4.8: shape of EL-equivalences between biprojective pairs"
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "theorem4_8.jl")); \
	   print_header(); theorem4_8_report()'

theorem5_1:
	@echo "Theorem 5.1 / Corollary 5.2: inequivalences within families"
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "theorem5_1.jl")); \
	   print_header(); theorem5_1_report()'

theorem6_1:
	@echo "Theorem 6.1: inequivalences between families (full_search adds F4 at m=6)"
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "theorem6_1.jl")); \
	   print_header(); theorem6_1_report(; include_f4=$(full_search))'

lemmaB_2:
	@echo "Lemma B.1 / B.2: root-free count and the transitive G-action"
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "lemmaB_2.jl")); \
	   print_header(); lemmaB_2_report(; full_search=$(full_search))'

theoremB_3:
	@echo "Theorem B.3: Carlet (m even) is EA-equivalent to Zhou-Pott"
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "theoremB_3.jl")); \
	   print_header(); theoremB_3_report()'

clean_results:
	rm -rf "$(MAKEFILE_DIR)/results"

help:
	@echo 'Paper: Gologlu & Kolsch (2025) — Equivalences of biprojective APN functions'
	@echo '       Electronic Journal of Combinatorics (accepted Mar 2025)'
	@echo ''
	@echo 'Targets:'
	@echo '  lemma2_1     Biprojective APN criterion, cross-validated vs differential_uniformity'
	@echo '  lemma3_2     The six gcd identities behind family F4'
	@echo '  theorem3_3   NEW FAMILY F4 is APN (m=6 exhaustive; m=10,14 with full_search=true)'
	@echo '  theoremC_3   F4 is 3-to-1 and has the classical Walsh spectrum'
	@echo '  lemma4_5     Z^{(q,r)} <= Aut_EL(F) for every biprojective pair'
	@echo '  lemma4_7     Normalizer/centralizer of M, M_P in GL(F) (exhaustive at m=2)'
	@echo '  lemmaA_1     Centralizer C_F, its index, and condition (C)'
	@echo '  theorem4_8   Shape theorem for EL-equivalences'
	@echo '  theorem5_1   Inequivalences within families + Corollary 5.2 counts'
	@echo '  theorem6_1   Inequivalences between families'
	@echo '  lemmaB_2     Lemma B.1 count + Lemma B.2 transitivity/stabilizer'
	@echo '  theoremB_3   Carlet (m even) is EA-equivalent to Zhou-Pott'
	@echo '  report       Full report (all of the above)'
	@echo '  test         Run the test suite'
	@echo '  clean_results  Remove generated files under results/'
	@echo ''
	@echo 'Parameters (override with make target param=value):'
	@echo '  m=$(m)                      field dimension of M = F_2^m'
	@echo '  limit=$(limit)'
	@echo '  sample_size=$(sample_size)'
	@echo '  save_results=$(save_results)          (true writes to results/)'
	@echo '  seed=$(seed)'
	@echo '  full_search=$(full_search)      (F4 at n=20/28; Lemma B.2 at m=5; F4 in Thm 6.1)'
