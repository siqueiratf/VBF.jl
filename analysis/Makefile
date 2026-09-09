# The metric tables that the paper analyses.
#
# `analysis/METRICS.md` defines every table and says why it is in the paper.
# `analysis/taxonomy.toml` holds the classification. Edit that file, then run
# `make -C analysis fast` again.
#
#   make -C analysis fast        papers, catalog and corpus   about 1 minute
#   make -C analysis invariants  the invariant comparison     minutes
#   make -C analysis all         every section
#   make -C analysis grades      rebuild the BFA-4R input first
#   make -C analysis list        print the sections
#
# Every target reads the repository and writes only into analysis/generated/.
# No target changes a database, a package or a paper directory.
#
# CAUTION: `invariants` computes. Every other section reads files. Its worst
# case is (invariants x populations x budget) seconds, which is about 30 minutes
# at the default. Raise `sample` and `budget` for a final run, and record both
# values, because they change the numbers. `PROVENANCE.md` records them.

JULIA  ?= julia
MAKEFILE_DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
ROOT   := $(abspath $(MAKEFILE_DIR)..)
JFLAGS ?= --startup-file=no --project=$(ROOT)
RUN    := $(MAKEFILE_DIR)metrics.jl
BFA4R  := $(ROOT)/manuscript/generate_bfa4r_table.jl

# Overridable parameters of the `invariants` section.
sample ?= 128
seed   ?= 20260901
budget ?= 15

INVFLAGS := --sample=$(sample) --seed=$(seed) --budget-seconds=$(budget)

# The figure script plots and tabulates; it never recomputes a metric. It reuses
# the resolved plotting environment in bench/analysis instead of adding a second
# Manifest to keep in step.
FIGURES  := $(MAKEFILE_DIR)figures.jl
FIGFLAGS ?= --startup-file=no --project=$(ROOT)/bench/analysis
figures_output ?= $(ROOT)/manuscript/6a0607721e3ebcf2a6fc6422/analysis/generated

.PHONY: help all fast papers catalog corpus invariants grades figures list clean

default: help

all: fast invariants

fast: papers catalog corpus

# The 42 reproductions, their defects and their evidence grades.
# It needs manuscript/generated/bfa4r_grades.csv; run `make grades` when that
# file is absent or older than the paper sources.
papers:
	$(JULIA) $(JFLAGS) $(RUN) --only=papers

# Where the APN functions are, by construction method and by dimension.
catalog:
	$(JULIA) $(JFLAGS) $(RUN) --only=catalog

# What each published corpus carries, counted in sigma classes.
corpus:
	$(JULIA) $(JFLAGS) $(RUN) --only=corpus

# The cost of each invariant against what it separates. This one computes.
invariants:
	$(JULIA) $(JFLAGS) $(RUN) --only=invariants $(INVFLAGS)

# The BFA-4R grades come from the paper sources. The generator writes both the
# LaTeX of the manuscript and the CSV that the `papers` section joins.
grades:
	$(JULIA) $(JFLAGS) $(BFA4R)

# The manuscript figures and LaTeX tables, from the CSVs the sections above wrote.
figures:
	$(JULIA) $(FIGFLAGS) $(FIGURES) "$(figures_output)"

list:
	$(JULIA) $(JFLAGS) $(RUN) --list

clean:
	rm -f $(MAKEFILE_DIR)generated/*.csv $(MAKEFILE_DIR)generated/PROVENANCE.md

help:
	@echo 'The metric tables of the paper. See analysis/METRICS.md.'
	@echo 'Targets: fast (papers catalog corpus)  invariants  all  grades  figures  list  clean'
	@echo 'Params:  sample=128  seed=20260901  budget=15   (the invariants section only)'
	@echo 'Output:  analysis/generated/*.csv plus PROVENANCE.md'
