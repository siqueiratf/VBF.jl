JULIA ?= julia
ROOT := $(abspath $(CURDIR)/../../..)
JFLAGS ?= --startup-file=no --project=$(ROOT)
OUTDIR ?= $(ROOT)/packages/VBFSearch/data/research/rebuilds/original-source
threads ?= 16

.PHONY: classes classify stored raw compare fetch test
classes:
	$(JULIA) $(JFLAGS) -t $(threads) $(CURDIR)/classes.jl
classify:
	$(JULIA) $(JFLAGS) -t $(threads) $(CURDIR)/classify_corpus.jl $(CLASSIFY_ARGS)
stored raw compare:
	$(JULIA) $(JFLAGS) -t $(threads) $(CURDIR)/reference/rebuild.jl $@ --outdir $(OUTDIR)
fetch:
	$(JULIA) $(JFLAGS) $(CURDIR)/reference/fetch.jl $(OUTDIR)
test:
	$(JULIA) $(JFLAGS) -t 4 $(ROOT)/packages/VBFSearch/test/reference/rebuild.jl
