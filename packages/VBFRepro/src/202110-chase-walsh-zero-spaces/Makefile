include $(dir $(abspath $(lastword $(MAKEFILE_LIST))))../paper.mk

.PHONY: help test report clean_results \
        proposition2_2 proposition3_1 definition3_2 \
        proposition4_1 proposition4_2 proposition4_3 section4_coverage \
        proposition5_1 proposition5_2 proposition5_3 \
        section6_1 section6_2

# Overridable parameters
seed        ?= 42
sample_size ?= 12
full_search ?= false

default: help

test:
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/test/runtests.jl

report:
	CHASE_SEED=$(seed) CHASE_SAMPLES=$(sample_size) CHASE_FULL=$(full_search) \
	  $(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/report.jl

proposition2_2 proposition3_1 definition3_2 proposition4_1 proposition4_2 \
proposition4_3 section4_coverage proposition5_1 proposition5_2 \
proposition5_3 section6_1 section6_2:
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/$@.jl

clean_results:
	rm -rf "$(MAKEFILE_DIR)/results"

help:
	@echo 'Paper: Chase, Lisoněk (2021) — Construction of APN permutations via Walsh zero spaces'
	@echo 'Targets: test  report  proposition2_2  proposition3_1  definition3_2'
	@echo '         proposition4_1  proposition4_2  proposition4_3  section4_coverage'
	@echo '         proposition5_1  proposition5_2  proposition5_3  section6_1  section6_2'
	@echo '         clean_results'
	@echo 'Params:  seed=42  sample_size=12  full_search=false'
