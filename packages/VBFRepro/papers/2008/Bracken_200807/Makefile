include $(dir $(abspath $(lastword $(MAKEFILE_LIST))))../../paper.mk

.PHONY: help test report report_full theorem1 theorem1_full theorem3 theorem4 theorem6 clean_results

default: help

test:
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/test/runtests.jl

report:
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/report.jl

report_full:
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/report.jl --full

theorem1:
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/theorem1.jl

theorem1_full:
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/theorem1.jl --full

theorem3:
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/theorem3.jl

theorem4:
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/theorem4.jl

theorem6:
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/theorem6.jl

clean_results:
	rm -rf "$(MAKEFILE_DIR)/results"

help:
	@echo 'Paper: Bracken, Byrne, Markin, McGuire (2008)'
	@echo '       New Families of Quadratic APN Trinomials and Multinomials'
	@echo 'Targets: test  report  report_full  theorem1  theorem1_full  theorem3'
	@echo '         theorem4  theorem6  clean_results'
	@echo 'Notes:'
	@echo '  theorem1      : Family 1 APN for n=6 (k=3,s=1/5) and n=10 (k=5,s=1);'
	@echo '                  n=6 (k,s)=(3,1) sweep uses a seeded 400-tuple sample'
	@echo '  theorem1_full : same, but sweeps all 150528 valid (b,c,r1,r2) tuples (~8s)'
	@echo '  theorem3      : Family 2 APN for n=6 (k=2,s=1, all 144 (u,v)) and n=12'
	@echo '  theorem4      : Bent property of Tr(v.F) for Family 1 at n=6, including'
	@echo '                  cube b (where Theorem 1 fails but Theorem 4 still holds)'
	@echo '  theorem6      : Walsh spectrum + CCZ checks and the code criterion at n=6'
