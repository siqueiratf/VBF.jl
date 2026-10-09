JULIA ?= julia
ROOT := $(abspath $(dir $(lastword $(MAKEFILE_LIST)))/../../..)
HERE := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
OUTDIR ?= $(ROOT)/census/quadratic_apn8/results/signature_rebuild
threads ?= 16
CANDIDATES ?= $(ROOT)/census/quadratic_apn8/search_b52/results/desk1/found.tsv \
  $(ROOT)/census/quadratic_apn8/new_classes_553.tsv \
  $(ROOT)/census/quadratic_apn8/new_classes_extra.tsv \
  $(ROOT)/census/quadratic_apn8/search_b52/new_classes_trial_773.tsv
JFLAGS ?= --startup-file=no --project=$(ROOT)

.PHONY: all fetch stored raw compare candidates test

# Deliberately sequential: comparison requires both exhaustive rebuilds.
all:
	$(MAKE) fetch
	$(MAKE) stored
	$(MAKE) raw
	$(MAKE) compare
	$(MAKE) candidates

fetch:
	$(JULIA) $(JFLAGS) $(HERE)/fetch.jl $(OUTDIR)

stored:
	$(JULIA) $(JFLAGS) -t $(threads) $(HERE)/rebuild.jl stored --outdir $(OUTDIR)

raw:
	$(JULIA) $(JFLAGS) -t $(threads) $(HERE)/rebuild.jl raw --outdir $(OUTDIR)

compare:
	$(JULIA) $(JFLAGS) $(HERE)/rebuild.jl compare --outdir $(OUTDIR)

candidates:
	$(JULIA) $(JFLAGS) -t $(threads) $(HERE)/check_candidates.jl $(OUTDIR) $(CANDIDATES)

test:
	$(JULIA) $(JFLAGS) -t 4 $(HERE)/test/runtests.jl
