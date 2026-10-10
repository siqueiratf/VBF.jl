include $(dir $(abspath $(lastword $(MAKEFILE_LIST))))../../paper.mk

.PHONY: help test report theorem1 section3 clean_results

default: help

test:
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/test/runtests.jl

report:
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/report.jl

theorem1:
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/theorem1.jl

section3:
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/section3.jl

clean_results:
	rm -rf "$(MAKEFILE_DIR)/results"

help:
	@echo 'Paper: Bracken, Byrne, Markin, McGuire (2011) — A Few More Quadratic APN Functions'
	@echo 'Targets: test  report  theorem1  section3  clean_results'
	@echo 'Notes:'
	@echo '  - theorem1 : APN verification for n=6 and n=12, all four subfamilies'
	@echo '  - section3 : delta-ranks for n=6 (computed) + n=12 Table 3 (loaded)'
	@echo '  - Δ-rank for n=12 is out-of-scope (needs Magma; VBF guards n≤7)'
