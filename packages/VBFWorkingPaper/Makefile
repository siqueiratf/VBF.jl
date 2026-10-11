JULIA ?= julia
HERE := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
ROOT := $(abspath $(HERE)../..)
RUN := $(JULIA) --startup-file=no --project=$(HERE)
output ?= $(ROOT)/packages/VBFWorkingPaper/doc/generated/reproductions
figure_output ?= $(ROOT)/packages/VBFWorkingPaper/doc/generated/figures
performance_output ?= $(ROOT)/packages/VBF/perf/data/analysis
paper_output ?= $(ROOT)/packages/VBFWorkingPaper/doc/generated/paper
input ?= $(ROOT)/packages/VBF/perf/data
profiles ?= $(ROOT)/packages/VBF/perf/data
sample ?= 128
seed ?= 20260901
budget ?= 15
manuscript_config ?= $(HERE)doc/performance/manuscript.toml
METRICS := VBF_WORKING_PAPER_OUTPUT="$(output)" $(RUN) $(HERE)src/analysis/reproductions/metrics.jl
PERF := $(RUN) $(ROOT)/packages/VBF/perf/analysis/run.jl
PERFARGS := --database="$(input)" --output="$(performance_output)" --profiles="$(profiles)"
.DEFAULT_GOAL := help
.NOTPARALLEL:
.PHONY: search-figures help instantiate grades papers catalog corpus fast invariants all figures consolidate inspect export plots test proposals paper stage manuscript crossings
instantiate:
	$(RUN) -e 'using Pkg; Pkg.instantiate()'
grades:
	VBF_WORKING_PAPER_OUTPUT="$(output)" $(RUN) $(HERE)src/analysis/reproductions/grades.jl
papers catalog corpus:
	$(METRICS) --only=$@
fast: papers catalog corpus
invariants:
	$(METRICS) --only=invariants --sample=$(sample) --seed=$(seed) --budget-seconds=$(budget)
all: fast invariants
figures:
	$(RUN) $(HERE)src/analysis/reproductions/figures.jl "$(figure_output)" "$(output)"
consolidate inspect:
	$(PERF) $@ $(PERFARGS)
plots export:
	$(PERF) $@ $(PERFARGS) --dataset=all
test:
	$(RUN) $(HERE)test/runtests.jl
	$(RUN) $(ROOT)/packages/VBF/perf/analysis/test.jl
proposals:
	$(JULIA) --startup-file=no --project=$(ROOT) $(ROOT)/packages/VBFRepro/tools/catalog_proposals.jl
paper:
	$(RUN) $(HERE)doc/build.jl "$(paper_output)"
stage:
	$(RUN) $(HERE)doc/build.jl "$(paper_output)" --stage-only
manuscript:
	$(RUN) $(HERE)src/analysis/performance/manuscript.jl "$(figure_output)" "$(manuscript_config)" "$(input)"
crossings:
	$(RUN) $(HERE)src/analysis/performance/crossings.jl --csv="$(ROOT)/packages/VBF/perf/data/archive/generated/benchmarks.csv" --meta="$(ROOT)/packages/VBF/perf/data/archive/generated/benchmarks_meta.tex" --out="$(ROOT)/packages/VBFWorkingPaper/doc/generated/performance/crossings"
help:
	@echo 'Working paper: instantiate; grades; fast; invariants; figures; stage; paper; test'
	@echo 'Parameters: output=DIR figure_output=DIR paper_output=FRESH_DIR sample=128 seed=20260901 budget=15'
	@echo 'Saved performance evidence: consolidate; inspect; export; plots; manuscript; crossings'

search-figures:
	$(RUN) $(HERE)src/search_figures.jl "$(run)" "$(figure_output)"
