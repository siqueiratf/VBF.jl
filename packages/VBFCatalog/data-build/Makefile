# BFA catalog build rules.
#
# External sources are declared in sources.toml.  Set the corresponding
# env var to use a local checkout (faster; no network required):
#
#   BFA_SBOXU_PATH   – sboxU git repo root  (apn_reps, quadratic_apn_8bit, sboxu_reconcile)
#   BFA_THESIS_PATH  – Simon-Berg@thesis root (simonberg)
#   BFA_XANADU_PATH  – apn-ccz-graph-framework root (xanadu)
#   BFA_APN_REPO_PATH – APN-Repository root (apn_repo)
#
# Without a local checkout, sources that declare an `upstream` URL in
# sources.toml are shallow-cloned into a temp directory automatically.

JULIA   ?= julia
JFLAGS  ?= --startup-file=no --project=$(CURDIR)
CATALOG := $(CURDIR)/../BFA_catalog.sqlite

.PHONY: all catalog check check-structure \
        apn_reps quadratic_apn_8bit sboxu_reconcile \
        simonberg xanadu apn_repo \
        known_families known_sporadic \
        clean reset

# Full build: BFA base data + all external sources in sources.toml order.
all: catalog

catalog:
	$(JULIA) $(JFLAGS) $(CURDIR)/build_catalog.jl

# ── verification ────────────────────────────────────────────────────────────
# Run this after ANY catalog change, before committing.  `check` verifies that
# data-raw and the committed BFA_catalog.sqlite agree and then runs the catalog
# test items; `check-structure` is the first half only (no Julia required).
# The same script backs the pre-commit hook — enable it once with
# `git config core.hooksPath .githooks`.
CHECK := $(CURDIR)/../../../.githooks/catalog-check

check:
	$(CHECK)

check-structure:
	$(CHECK) --structure-only

# ── individual external-source targets ─────────────────────────────────────
# Each runs its importer against the *existing* catalog (no rebuild from
# scratch).  Useful for re-importing a single source after an upstream update.

apn_reps:
	$(JULIA) $(JFLAGS) $(CURDIR)/import_apn_reps.jl

quadratic_apn_8bit:
	$(JULIA) $(JFLAGS) $(CURDIR)/import_quadratic_apn_8bit.jl

sboxu_reconcile:
	$(JULIA) $(JFLAGS) $(CURDIR)/import_sboxu_apn.jl

simonberg:
	$(JULIA) $(JFLAGS) $(CURDIR)/import_simonberg.jl

xanadu:
	$(JULIA) $(JFLAGS) $(CURDIR)/import_xanadu_apn.jl

apn_repo:
	$(JULIA) $(JFLAGS) $(CURDIR)/import_apn_repository.jl

# Named representatives of KNOWN APN classes: the standard families swept over
# every valid dimension (known_families) plus a handful of sporadics
# (known_sporadic).  These fill the n=9 catalog hole that let a paper's already
# known function read as `:new`.  Both re-verify du==2 and skip exact-LUT dups
# before inserting, so re-running against a populated catalog is a no-op.
known_families:
	$(JULIA) $(JFLAGS) $(CURDIR)/import_known_families.jl

known_sporadic:
	$(JULIA) $(JFLAGS) $(CURDIR)/import_sporadic_known.jl

# ── catalog reset ───────────────────────────────────────────────────────────

clean:
	rm -f $(CATALOG)

reset: clean
