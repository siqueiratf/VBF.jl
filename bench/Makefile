# VBF benchmark suite.
#
# The suite measures the public API of packages/VBF and the read queries of
# packages/VBFCatalog. It writes four files into bench/generated/ that the
# thesis reads directly. It changes nothing under packages/ and it runs no git
# command.
#
#   make -C bench quick     level 1, the fast cases     about 1 minute
#   make -C bench bench     level 2, the default        about 4 minutes
#   make -C bench full      level 3, every case         about 30 minutes
#   make -C bench list      print the cases, measure none
#
# CAUTION: `make full` runs the exhaustive equivalence searches. Do not start it
# on a machine that you need for other work, and do not start it while another
# job runs. A loaded machine moves every figure by up to a factor of two.
#
# CAUTION: give `make full` at least 4 GB of free memory. The case
# equivalence/partition_automorphisms at n = 6 holds about 1.7 GB for each call.

JULIA  ?= julia
MAKEFILE_DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
ROOT   := $(abspath $(MAKEFILE_DIR)..)
JFLAGS ?= --startup-file=no --project=$(ROOT)
RUN    := $(MAKEFILE_DIR)run.jl

# Overridable parameters
target_seconds ?= 1.0
group          ?=
n              ?=

GROUP_ARG := $(if $(group),--group=$(group),)
N_ARG     := $(if $(n),--n=$(n),)

.PHONY: help quick bench full list group clean

default: help

quick:
	$(JULIA) $(JFLAGS) $(RUN) --level=1 --target-seconds=$(target_seconds) $(GROUP_ARG) $(N_ARG)

bench:
	$(JULIA) $(JFLAGS) $(RUN) --level=2 --target-seconds=$(target_seconds) $(GROUP_ARG) $(N_ARG)

full:
	$(JULIA) $(JFLAGS) $(RUN) --level=3 --target-seconds=$(target_seconds) $(GROUP_ARG) $(N_ARG)

list:
	$(JULIA) $(JFLAGS) $(RUN) --list

clean:
	rm -f $(MAKEFILE_DIR)generated/benchmarks.csv \
	      $(MAKEFILE_DIR)generated/benchmarks_table.tex \
	      $(MAKEFILE_DIR)generated/benchmarks_facts.tex \
	      $(MAKEFILE_DIR)generated/benchmarks_meta.tex

help:
	@echo 'VBF benchmark suite'
	@echo 'Targets: quick (level 1)  bench (level 2)  full (level 3)  list  clean'
	@echo 'Params:  group=spectra  n=8  target_seconds=1.0'
	@echo 'Output:  bench/generated/{benchmarks.csv,benchmarks_table.tex,'
	@echo '                          benchmarks_facts.tex,benchmarks_meta.tex}'
