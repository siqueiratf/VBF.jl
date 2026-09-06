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
#   make -C bench crossings cross the axes of the last run, measure nothing
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
CROSS  := $(MAKEFILE_DIR)crossings.jl

# Overridable parameters
target_seconds ?= 1.0
group          ?=
n              ?=

GROUP_ARG := $(if $(group),--group=$(group),)
N_ARG     := $(if $(n),--n=$(n),)

.PHONY: help quick bench full list group crossings clean

default: help

quick:
	$(JULIA) $(JFLAGS) $(RUN) --level=1 --target-seconds=$(target_seconds) $(GROUP_ARG) $(N_ARG)

bench:
	$(JULIA) $(JFLAGS) $(RUN) --level=2 --target-seconds=$(target_seconds) $(GROUP_ARG) $(N_ARG)

full:
	$(JULIA) $(JFLAGS) $(RUN) --level=3 --target-seconds=$(target_seconds) $(GROUP_ARG) $(N_ARG)

list:
	$(JULIA) $(JFLAGS) $(RUN) --list

# The crossings read bench/generated/benchmarks.csv. They measure nothing, so
# they cost about one second. Run a suite target first.
crossings:
	$(JULIA) $(JFLAGS) $(CROSS)

clean:
	rm -f $(MAKEFILE_DIR)generated/benchmarks.csv \
	      $(MAKEFILE_DIR)generated/benchmarks_table.tex \
	      $(MAKEFILE_DIR)generated/benchmarks_facts.tex \
	      $(MAKEFILE_DIR)generated/benchmarks_meta.tex \
	      $(MAKEFILE_DIR)generated/crossing_growth.csv \
	      $(MAKEFILE_DIR)generated/crossing_growth_table.tex \
	      $(MAKEFILE_DIR)generated/crossing_growth.dat \
	      $(MAKEFILE_DIR)generated/crossing_reach_table.tex \
	      $(MAKEFILE_DIR)generated/crossing_polarity.csv \
	      $(MAKEFILE_DIR)generated/crossing_polarity_table.tex \
	      $(MAKEFILE_DIR)generated/crossing_memory.csv \
	      $(MAKEFILE_DIR)generated/crossing_memory_table.tex \
	      $(MAKEFILE_DIR)generated/crossing_memory.dat \
	      $(MAKEFILE_DIR)generated/crossings_facts.tex

help:
	@echo 'VBF benchmark suite'
	@echo 'Targets: quick (level 1)  bench (level 2)  full (level 3)  list  crossings  clean'
	@echo 'Params:  group=spectra  n=8  target_seconds=1.0'
	@echo 'Output:  bench/generated/{benchmarks.csv,benchmarks_table.tex,'
	@echo '                          benchmarks_facts.tex,benchmarks_meta.tex}'
	@echo 'Crossings: bench/generated/crossing_*.{csv,tex,dat}, crossings_facts.tex'
	@echo '           Paste bench/crossings.tex into the paper.'
