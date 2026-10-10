include $(dir $(abspath $(lastword $(MAKEFILE_LIST))))../../paper.mk

.PHONY: help test report theorem1 theorem2 example1 proposition1 algorithm1 table1 table2 table3 table3_full table4

max_evaluations ?= 16777216
n_demo ?= 7
timeout_seconds ?= 60
confirm ?= false
equivalence_timeout_seconds ?= 60
max_equivalence_nodes ?= 1000000
save_results ?= false

default: help

test:
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/test/runtests.jl

report:
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/report.jl

theorem1:
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include("$(MAKEFILE_DIR)/theorem1.jl"); theorem1_report()'

theorem2:
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include("$(MAKEFILE_DIR)/theorem2.jl"); theorem2_report()'

example1:
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include("$(MAKEFILE_DIR)/example1.jl"); example1_report()'

proposition1:
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include("$(MAKEFILE_DIR)/proposition1.jl"); proposition1_report()'

algorithm1:
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include("$(MAKEFILE_DIR)/algorithm1.jl"); algorithm1_report(; n_demo=$(n_demo), max_evaluations=$(max_evaluations), timeout_seconds=$(timeout_seconds), confirm=$(confirm), save_results=$(save_results), equivalence_timeout_seconds=$(equivalence_timeout_seconds), max_equivalence_nodes=$(max_equivalence_nodes))'

table1:
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include("$(MAKEFILE_DIR)/table1.jl"); table1_report()'

table2:
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include("$(MAKEFILE_DIR)/table2.jl"); table2_report()'

table3:
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include("$(MAKEFILE_DIR)/table3.jl"); table3_report()'

# Table 3 with the COMPLETE EA decision on the two claimed n=8 CCZ-equivalences.
# ~9 min: ea_mappings_from_ortho_derivative costs ~265 s per positive pair at n=8.
table3_full:
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include("$(MAKEFILE_DIR)/table3.jl"); table3_report(; full_ea=true)'

table4:
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include("$(MAKEFILE_DIR)/table4.jl"); table4_report(; save_results=$(save_results))'

help:
	@echo 'Paper: Yu, Kaleyski, Budaghyan, Li (2020)'
	@echo '  Classification of quadratic APN functions with F₂ coefficients, n≤9'
	@echo 'Targets: test  report  theorem1  theorem2  example1  proposition1  algorithm1'
	@echo '         table1  table2  table3  table3_full  table4'
	@echo 'Params:  max_evaluations (default: 2^24)'
	@echo 'Note:    table3_full runs the complete EA decision (~9 min)'
