JULIA ?= julia
MAKEFILE_DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
ROOT := $(abspath $(MAKEFILE_DIR)/../..)
JULIA_PROJECT := --project=$(ROOT)

.PHONY: help test report theorem1 theorem3 theorem4 theorem5 clean_results

default: help

test:
	$(JULIA) $(JULIA_PROJECT) -e 'using Pkg; Pkg.instantiate()'
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/test/runtests.jl

report:
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/report.jl

theorem1:
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/theorem1.jl

theorem3:
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/theorem3.jl

theorem4:
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/theorem4.jl

theorem5:
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/theorem5.jl

clean_results:
	rm -rf "$(MAKEFILE_DIR)/results"

help:
	@echo 'Paper: Bracken, Byrne, Markin, McGuire (2008)'
	@echo '       New Families of Quadratic APN Trinomials and Multinomials'
	@echo 'Targets: test  report  theorem1  theorem3  theorem4  theorem5  clean_results'
	@echo 'Notes:'
	@echo '  theorem1 : Family 1 APN for n=6 (k=3,s=1/5) and n=10 (k=5,s=1)'
	@echo '  theorem3 : Family 2 APN for n=6 (k=2,s=1) and n=12 (k=4,s=5)'
	@echo '  theorem4 : Bent property of Tr(F) for Family 1 at n=6'
	@echo '  theorem5 : Walsh spectrum + CCZ checks at n=6'
