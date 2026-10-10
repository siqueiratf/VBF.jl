include $(dir $(abspath $(lastword $(MAKEFILE_LIST))))../paper.mk

.PHONY: help test report clean_results \
        proposition1 proposition2 proposition3 proposition4 \
        proposition5 proposition6 proposition7 proposition8 \
        corollary1 corollary2 corollary3 corollary4

# Overridable parameters
limit          ?= 2147483647
sample_size    ?= 25
save_results   ?= false
seed           ?= 42
full_search    ?= false

default: help

test:
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/test/runtests.jl

report:
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "report.jl")); \
	   paper_report(; full_search=$(full_search), save_results=$(save_results))'

clean_results:
	rm -rf "$(MAKEFILE_DIR)/results"

define CLAIM_target
$(1):
	$$(JULIA) $$(JULIA_PROJECT) -e \
	  'include(joinpath("$$(MAKEFILE_DIR)", "$(1).jl")); \
	   print_header(); $(1)_report(; save_results=$$(save_results))'
endef

# Claims whose report takes full_search
proposition1 corollary1 corollary3 corollary4:
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "$@.jl")); \
	   print_header(); $@_report(; full_search=$(full_search), save_results=$(save_results))'

# Claims with a plain report
proposition2 proposition3 proposition4 proposition5 proposition6 proposition7 proposition8 corollary2:
	$(JULIA) $(JULIA_PROJECT) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "$@.jl")); \
	   print_header(); $@_report(; save_results=$(save_results))'

help:
	@echo 'Paper: Budaghyan-Carlet-Leander (2009) - On a construction of quadratic APN functions'
	@echo 'Targets: test  report  clean_results'
	@echo '         proposition1..8  corollary1..4'
	@echo 'Params:  limit  sample_size  save_results  seed  full_search'
