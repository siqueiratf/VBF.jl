JULIA ?= julia
ROOT := $(abspath $(CURDIR)/../../../..)
JFLAGS ?= --startup-file=no --project=$(CURDIR)
CATALOG_ARGS ?= --max-n 11
OUTDIR ?= $(ROOT)/data/apn/rebuilds/original-source
threads ?= 16

.PHONY: catalog check fetch convert stored raw compare index test
catalog:
	$(JULIA) $(JFLAGS) $(CURDIR)/build_catalog.jl $(CATALOG_ARGS)
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
test:
	$(JULIA) $(JFLAGS) -t 4 $(ROOT)/packages/VBFCatalog/test/import/reference/runtests.jl
