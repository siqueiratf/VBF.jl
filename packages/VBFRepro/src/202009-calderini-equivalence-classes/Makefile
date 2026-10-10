include $(dir $(abspath $(lastword $(MAKEFILE_LIST))))../paper.mk

.PHONY: help test report section3 section4 section5 section6 clean_results

full_search ?= false
limit ?= 1
max_nodes ?= 100000
max_subspaces ?= 10000
timeout_seconds ?= 10

default: help

test:
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/tests/runtests.jl

report:
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "report.jl")); paper_report(; full_search=$(full_search), max_nodes=$(max_nodes), timeout_seconds=$(timeout_seconds))'

section3:
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "section3.jl")); section3_report()'

section4:
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "section4.jl")); section4_report()'

section5:
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "section5.jl")); section5_report()'

section6:
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "section6.jl")); section6_report(; full_search=$(full_search), max_nodes=$(max_nodes), timeout_seconds=$(timeout_seconds))'

table_bounds:
	$(JULIA) $(JULIA_PROJECT) -e 'include(joinpath("$(MAKEFILE_DIR)", "table_bounds.jl")); table_bounds_report(; limit=$(limit), max_nodes=$(max_nodes), max_subspaces=$(max_subspaces), timeout_seconds=$(timeout_seconds))'

clean_results:
	rm -rf "$(MAKEFILE_DIR)/results"

help:
	@echo 'Calderini (2020) — On the EA-classes of known APN functions in small dimensions'
	@echo 'Cryptography and Communications 12:821-840'
	@echo ''
	@echo 'Targets:'
	@echo '  section3   Observation 1, Procedure 2 (all k), Propositions 1/2/3, Corollary 1'
	@echo '  section4   C1..C4 codes (paper-exact dims), Theorem 5/6 via weight enumerators'
	@echo '  section5   Table 1 EA-class counts (exact, rows 1-13) + row 14, Section 5.1'
	@echo '  section6   Theorem 7 (n=5..9), Theorem 8 census (n=5..9), Remarks 5-7'
	@echo '  report     Bounded aggregate report; n=9 inverse is opt-in full_search=true'
	@echo '  test       Run test suite'
	@echo ''
	@echo 'Scope: EXACT: Obs1, Procedure 2 (all k) + Prop 1/2/3 (the paper pipeline:'
	@echo '       Proc2 -> code filter -> EA-classes), Cor1, C1..C4, Table 1 rows 1-13'
	@echo '       + row 14 vs catalog, Sec 5.1 (13 EA / 2 perm EA / 4 perm affine),'
	@echo '       Thm 7 n=5..9, Thm 8 census n=5..9, Remarks 5-7.'
	@echo '       table_bounds: budgeted native simplex counts for power rows of Tables 2/3/4.'
	@echo '       UNREPRODUCED: full Tables 2/3/4 and general direct code equivalence,'
	@echo '       AB-monomial simplex counts n>=7 (measured >30 min each).'
