JULIA ?= julia
ROOT := $(abspath $(CURDIR)/../../../..)
JFLAGS ?= --startup-file=no --project=$(CURDIR)
CATALOG_ARGS ?=
OUTDIR ?= $(ROOT)/packages/VBFCatalog/data/research/rebuilds/original-source
threads ?= 16

.PHONY: catalog check reproducible fetch convert stored raw compare index classes classify test
catalog:
	$(JULIA) $(JFLAGS) -t $(threads) $(CURDIR)/build_catalog.jl $(CATALOG_ARGS)
reproducible:
	$(JULIA) $(JFLAGS) -t $(threads) $(CURDIR)/check_reproducibility.jl
check:
	$(ROOT)/.githooks/catalog-check
fetch:
	$(JULIA) $(JFLAGS) $(CURDIR)/fetch.jl $(SOURCE)
convert:
	$(JULIA) $(JFLAGS) $(CURDIR)/convert.jl $(SOURCE) $(CONVERT_ARGS)
stored raw compare:
	$(JULIA) $(JFLAGS) -t $(threads) $(CURDIR)/reference/rebuild.jl $@ --outdir $(OUTDIR)
index:
	$(JULIA) $(JFLAGS) -t $(threads) $(CURDIR)/build_sigma_index.jl
classes:
	$(JULIA) $(JFLAGS) -t $(threads) $(CURDIR)/build_sigma_index.jl --classes-only
classify:
	$(JULIA) $(JFLAGS) -t $(threads) $(CURDIR)/classify_corpus.jl $(CLASSIFY_ARGS)
test:
	$(JULIA) $(JFLAGS) -t 4 $(ROOT)/packages/VBFCatalog/test/import/reference/runtests.jl
