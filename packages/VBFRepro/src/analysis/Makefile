JULIA ?= julia
.DEFAULT_GOAL := help
HERE := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
ROOT := $(abspath $(HERE)../../../..)
JFLAGS ?= --startup-file=no --project=$(HERE)
RUN := $(JULIA) $(JFLAGS)
output ?= $(ROOT)/data/repro/analysis/reproductions
performance_output ?= $(ROOT)/data/repro/analysis/performance
input ?= $(ROOT)/data/perf
profiles ?= $(ROOT)/data/perf
sample ?= 128
seed ?= 20260901
budget ?= 15
# Figures are presentation artifacts; callers choose the destination explicitly.
figure_output ?= $(ROOT)/data/repro/analysis/figures
crossings_csv ?= $(ROOT)/data/perf/archive/generated/benchmarks.csv
crossings_meta ?= $(ROOT)/data/perf/archive/generated/benchmarks_meta.tex
manuscript_config ?= $(ROOT)/manuscript/performance/manuscript.toml
proposal_output ?= $(ROOT)/data/repro/analysis/catalog_proposals.toml
equivalence_timeout ?= 2
max_equivalence_nodes ?= 100000
METRICS = VBF_REPRO_ANALYSIS_OUTPUT="$(output)" $(RUN) $(HERE)reproductions/metrics.jl
PERF = $(RUN) $(HERE)performance/run.jl
PERFARGS = --database="$(input)" --output="$(performance_output)" --profiles="$(profiles)"
.PHONY: help instantiate grades papers catalog corpus fast invariants all figures list consolidate inspect export plots test manuscript crossings
.PHONY: review_catalog_proposals test_catalog_proposals verify_proposal_witnesses
instantiate:
	$(RUN) -e 'using Pkg; Pkg.instantiate()'
grades:
	VBF_REPRO_ANALYSIS_OUTPUT="$(output)" $(RUN) $(HERE)reproductions/grades.jl
papers:
	$(METRICS) --only=papers
catalog:
	$(METRICS) --only=catalog
corpus:
	$(METRICS) --only=corpus
fast: papers catalog corpus
invariants:
	$(METRICS) --only=invariants --sample=$(sample) --seed=$(seed) --budget-seconds=$(budget)
all: fast invariants
figures:
	$(RUN) $(HERE)reproductions/figures.jl "$(figure_output)" "$(output)"
list:
	$(METRICS) --list
consolidate:
	$(PERF) consolidate $(PERFARGS)
inspect:
	$(PERF) inspect $(PERFARGS)
export:
	$(PERF) export $(PERFARGS) --dataset=all
plots:
	$(PERF) plots $(PERFARGS) --dataset=all
test:
	$(RUN) $(HERE)performance/test.jl
review_catalog_proposals:
	$(JULIA) --startup-file=no --project=$(ROOT) $(HERE)validation/review_catalog_proposals.jl "$(proposal_output)" $(equivalence_timeout) $(max_equivalence_nodes)
test_catalog_proposals:
	$(JULIA) --startup-file=no --project=$(ROOT) $(HERE)validation/test/test_catalog_proposals.jl
verify_proposal_witnesses:
	$(JULIA) --startup-file=no $(HERE)validation/test/verify_proposal_witnesses.jl "$(proposal_output)"
manuscript:
	$(RUN) $(HERE)performance/manuscript.jl "$(figure_output)" "$(manuscript_config)" "$(input)"
crossings:
	$(RUN) $(HERE)performance/crossings.jl --csv="$(crossings_csv)" --meta="$(crossings_meta)" --out="$(performance_output)/crossings"
help:
	@echo 'VBFRepro analysis: instantiate; grades; fast; invariants; figures; list'
	@echo 'Performance: consolidate; inspect; export; plots; test'
	@echo 'Read-only audit: review_catalog_proposals; test_catalog_proposals (root environment)'
	@echo 'Parameters: input=measurement-directory-or-legacy-SQLite output=DIR performance_output=DIR'
	@echo 'Presentation: figure_output=DIR manuscript_config=PATH; legacy manuscript/crossings targets'
	@echo 'No analysis target runs a performance suite or changes the catalog.'
