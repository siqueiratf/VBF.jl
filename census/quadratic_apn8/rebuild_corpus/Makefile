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

.PHONY: all fetch stored raw compare candidates equivalence verify-witnesses test

# Deliberately sequential: comparison requires both exhaustive rebuilds.
all:
	$(MAKE) fetch
	$(MAKE) stored
	$(MAKE) raw
	$(MAKE) compare
	$(MAKE) candidates
	$(MAKE) equivalence

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

EA_TIMEOUT ?= 60
EA_MAX_NODES ?= 1000000

equivalence:
	$(JULIA) $(JFLAGS) $(HERE)/check_equivalence.jl $(OUTDIR) $(EA_TIMEOUT) $(EA_MAX_NODES)

# Standard library only: independently check every saved positive map.
verify-witnesses:
	$(JULIA) --startup-file=no $(HERE)/ea_witness.jl $(OUTDIR)/equivalence_checks.toml

test:
	$(JULIA) $(JFLAGS) -t 4 $(HERE)/test/runtests.jl
