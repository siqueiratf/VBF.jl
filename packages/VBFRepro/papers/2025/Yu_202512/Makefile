include $(dir $(abspath $(lastword $(MAKEFILE_LIST))))../../paper.mk


.PHONY: help test report theorem1 proposition1 theorem2 example1 corollary1 \
        example2 algorithm2 table1 table2 table2_n7 algorithm3 table3 clean_results

limit           ?= 2147483647
max_evaluations ?= 1048576
save_results    ?= false

default: help

test:
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/tests/runtests.jl

report:
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/report.jl

theorem1:
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/theorem1.jl

proposition1:
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/proposition1.jl

theorem2:
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/theorem2.jl

example1:
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/example1.jl

corollary1:
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/corollary1.jl

example2:
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/example2.jl

algorithm2:
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/algorithm2.jl

table1:
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/table1.jl

table2:
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "table2.jl")); \
	   table2_report(; max_n=7, max_evaluations=$(max_evaluations))'

table2_n7:
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "table2.jl")); \
	   table2_report(; max_n=7, max_evaluations=1<<24)'

algorithm3:
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/algorithm3.jl

table3:
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/table3.jl

clean_results:
	rm -rf "$(MAKEFILE_DIR)/results"

help:
	@echo 'Paper: Yu, Li, Ichanska, Kaleyski (2025) — Classification of quadratic APN with F2 coefficients, n=10'
	@echo ''
	@echo 'Targets:'
	@echo '  test          Run fast test suite'
	@echo '  report        Full paper report (all sections)'
	@echo '  theorem1      Verify diagonal-squaring property (Theorem 1)'
	@echo '  proposition1  Elementwise squaring gives EA-equivalent QAM (Proposition 1)'
	@echo '  theorem2      Cyclic rank preservation (Theorem 2)'
	@echo '  example1      Concrete rank examples for n=5 (Example 1)'
	@echo '  corollary1    |CR| ≈ 2^n/n for n=5..10 (Corollary 1)'
	@echo '  example2      CR and ID array for n=5 (Example 2)'
	@echo '  algorithm2    Algorithm 2 demo n=5,6'
	@echo '  table1        Verify 3 CCZ-reps for n=10 (Table 1)'
	@echo '  table2        Table 2 counts, n=6 exact + n=7 budget (max_evaluations=$(max_evaluations))'
	@echo '  table2_n7     Table 2 exhaustive n=7 (2^24 budget, ~minutes)'
	@echo '  algorithm3    Algorithm 3 partial search demo n=6,7'
	@echo '  table3        Verify 6 CCZ-reps for n=11 (Table 3, conjectured)'
	@echo '  clean_results Remove results/'
	@echo ''
	@echo 'Parameters (override with make target param=value):'
	@echo '  max_evaluations=$(max_evaluations)'
	@echo '  save_results=$(save_results)'
