JULIA ?= julia
ROOT := $(abspath $(CURDIR)/../../../..)
JFLAGS ?= --startup-file=no --project=$(CURDIR)
CATALOG_ARGS ?=
threads ?= 16

.PHONY: catalog check reproducible fetch convert index
catalog:
	$(JULIA) $(JFLAGS) -t $(threads) $(CURDIR)/build_catalog.jl $(CATALOG_ARGS)
reproducible:
	$(JULIA) $(JFLAGS) -t $(threads) $(CURDIR)/check_reproducibility.jl
check:
	$(ROOT)/.githooks/catalog-check
fetch:
	$(JULIA) $(JFLAGS) $(CURDIR)/fetch.jl $(SOURCE)
convert:
	$(JULIA) $(JFLAGS) -t $(threads) $(CURDIR)/convert.jl $(SOURCE) $(CONVERT_ARGS)
index:
	$(JULIA) $(JFLAGS) -t $(threads) $(CURDIR)/build_sigma_index.jl
