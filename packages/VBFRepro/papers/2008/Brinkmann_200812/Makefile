include $(dir $(abspath $(lastword $(MAKEFILE_LIST))))../../paper.mk

.PHONY: help test report lemma1 algorithm1 table1 table3 theorem3 theorem5 theorem6 \
        section6 section6_n3 section7 section8

default: help

test:
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/test/runtests.jl

report:
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/report.jl

lemma1:
	$(JULIA) $(JULIA_PROJECT) -e 'include("$(MAKEFILE_DIR)lemma1.jl"); lemma1_report()'

algorithm1:
	$(JULIA) $(JULIA_PROJECT) -e 'include("$(MAKEFILE_DIR)algorithm1.jl"); algorithm1_report()'

table1:
	$(JULIA) $(JULIA_PROJECT) -e 'include("$(MAKEFILE_DIR)table1.jl"); table1_report()'

table3:
	$(JULIA) $(JULIA_PROJECT) -e 'include("$(MAKEFILE_DIR)table3.jl"); table3_report()'

theorem3:
	$(JULIA) $(JULIA_PROJECT) -e 'include("$(MAKEFILE_DIR)theorem3.jl"); theorem3_report()'

theorem5:
	$(JULIA) $(JULIA_PROJECT) -e 'include("$(MAKEFILE_DIR)theorem5.jl"); theorem5_report()'

theorem6:
	$(JULIA) $(JULIA_PROJECT) -e 'include("$(MAKEFILE_DIR)theorem6.jl"); theorem6_report()'

section6:
	$(JULIA) $(JULIA_PROJECT) -e 'include("$(MAKEFILE_DIR)section6.jl"); section6_report()'

section6_n3:
	$(JULIA) $(JULIA_PROJECT) -e 'include("$(MAKEFILE_DIR)section6.jl"); println("n=3 #APN = ", count_apn_n3())'

section7:
	$(JULIA) $(JULIA_PROJECT) -e 'include("$(MAKEFILE_DIR)section7.jl"); section7_report()'

section8:
	$(JULIA) $(JULIA_PROJECT) -e 'include("$(MAKEFILE_DIR)section8.jl"); section8_report()'

help:
	@echo 'Paper: Brinkmann & Leander (2008) — Classification of APN functions up to dim 5'
	@echo 'Targets: test  report  lemma1  algorithm1  table1  table3  theorem3  theorem5'
	@echo '         theorem6  section6  section6_n3  section7  section8'
