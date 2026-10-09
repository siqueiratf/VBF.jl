JULIA ?= julia

MAKEFILE_DIR := $(patsubst %/,%,$(dir $(abspath $(lastword $(MAKEFILE_LIST)))))
ROOT := $(abspath $(MAKEFILE_DIR)/../../..)
JULIA_PROJECT := --project=$(ROOT)

# Data (outside the repository) and the already verified Zenodo new_apns.txt.
DATA ?= $(HOME)/.cache/bfa-data/langevin
BEIERLE ?= $(HOME)/.cache/bfa-data/beierle2025/new_apns.txt

# All n = 8 data files of https://langevin.univ-tln.fr/data/apns/ except
# new_apns.txt.gz (byte-identical to the verified Zenodo new_apns.txt; see `download`).
FILES := apn-11888039-may-2025-8.out sage-29-03.tar sage.tar sage-18-09.tar \
         sage-25-08.tar sage-10-10.tar sage-02-11.tar sage-30-11.tar sage-10-01.tar \
         sage-31-01.tar apn-11888039-may-2025-8.txt.gz

threads ?= 5
# limit = 0: all records; limit = N: first N records of each file (outputs go to
# $(DATA)/limit<N>, so a test run never overwrites the results of the full run).
limit ?= 0
ckpt ?= 1000000
spot ?= 997
files ?= $(FILES)
ifeq ($(limit),0)
outdir ?= $(MAKEFILE_DIR)
statedir ?= $(DATA)/crosscheck_state
else
outdir ?= $(DATA)/limit$(limit)
statedir ?= $(outdir)/state
endif

.PHONY: help download check union selftest

default: help

help:
	@echo "Cross-check of the Langevin n = 8 APN files against the sigma index."
	@echo ""
	@echo "  make download             listing.tsv, files.tsv, files to DATA=$(DATA)"
	@echo "  make check                all records of all files (resumable)"
	@echo "  make check limit=50000    first 50,000 records of each file (timing test)"
	@echo "  make check files=sage.tar one file (name in DATA)"
	@echo "  make union                union of the per-file sigma sets"
	@echo "  make selftest             fast sigma = VBFCatalog.sigma_hash on 2,000 records"
	@echo ""
	@echo "Parameters: threads=$(threads) limit=$(limit) ckpt=$(ckpt) spot=$(spot)"
	@echo "            outdir=$(outdir) statedir=$(statedir)"
	@echo "Full run: about 82 min with threads=5 (31.4M records)."
	@echo "Long runs: nohup make check > $(DATA)/check.log 2>&1 &"

download:
	bash $(MAKEFILE_DIR)/download.sh $(DATA) $(MAKEFILE_DIR) $(BEIERLE)

check:
	$(JULIA) $(JULIA_PROJECT) -t $(threads) $(MAKEFILE_DIR)/crosscheck.jl \
	  --outdir $(outdir) --statedir $(statedir) --limit $(limit) --ckpt $(ckpt) --spot $(spot) \
	  $(addprefix $(DATA)/,$(files))

union:
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/crosscheck.jl --union \
	  --outdir $(outdir) --statedir $(statedir)

selftest:
	$(JULIA) $(JULIA_PROJECT) $(MAKEFILE_DIR)/selftest.jl $(DATA)/apn-11888039-may-2025-8.out
