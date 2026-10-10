include $(dir $(abspath $(lastword $(MAKEFILE_LIST))))../paper.mk

.PHONY: help test report section2 section3 section4 section5 section6 section7 \
        table2 table4 rijndael_2040 misty_889 clean_results

full_search ?= false

default: help

test:
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/test/runtests.jl

report:
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include("$(MAKEFILE_DIR)report.jl"); paper_report(; full_search = $(full_search))'

section2:
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include("$(MAKEFILE_DIR)section2.jl"); section2_report()'

section3:
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include("$(MAKEFILE_DIR)section3.jl"); section3_report()'

section4:
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include("$(MAKEFILE_DIR)section4.jl"); section4_report(; full_search = $(full_search))'

section5:
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include("$(MAKEFILE_DIR)section5.jl"); section5_report()'

section6:
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include("$(MAKEFILE_DIR)section6.jl"); section6_report()'

section7:
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include("$(MAKEFILE_DIR)section7.jl"); section7_report(; full_search = $(full_search))'

table2:
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include("$(MAKEFILE_DIR)table2.jl"); table2_report()'

table4:
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include("$(MAKEFILE_DIR)table4.jl"); table4_report(; full_search = $(full_search))'

rijndael_2040:
	@echo "Running Rijndael 2040 self-equivalence count (expensive, O(2^16) LE searches)..."
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include("$(MAKEFILE_DIR)section4.jl"); section4_report(; full_search = true)'

misty_889:
	@echo "Running the GF(2^7) power-map self-equivalence count (expensive, O(2^14) LE searches)..."
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include("$(MAKEFILE_DIR)table4.jl"); table4_report(; full_search = true)'

clean_results:
	rm -rf "$(MAKEFILE_DIR)results"

help:
	@echo 'Paper: Biryukov et al. (2003) — A Toolbox for Cryptanalysis: Linear and Affine Equivalence Algorithms'
	@echo 'Targets: test  report  section2  section3  section4  section5  section6  section7'
	@echo '         table2  table4  rijndael_2040  misty_889  clean_results'
	@echo 'Params:  full_search=false   (set true for the exhaustive self-equivalence counts)'
