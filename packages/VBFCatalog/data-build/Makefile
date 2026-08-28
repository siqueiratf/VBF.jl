# BFA catalog build rules.
#
# External sources are declared in sources.toml.  Set the corresponding
# env var to use a local checkout (faster; no network required):
#
#   BFA_SBOXU_PATH   – sboxU git repo root  (apn_reps, quadratic_apn_8bit, sboxu_reconcile)
#   BFA_BEIERLE2025_PATH – directory holding new_apns.txt (beierle2025)
#   BFA_THESIS_PATH  – Simon-Berg@thesis root (simonberg)   ** REQUIRED **
#   BFA_XANADU_PATH  – apn-ccz-graph-framework root (xanadu)
#   BFA_APN_REPO_PATH – APN-Repository root (apn_repo)
#
# Without a local checkout, sources that declare an `upstream` URL in
# sources.toml are shallow-cloned into a temp directory automatically.
#
# A source marked `required` in sources.toml owns rows the committed catalog
# contains.  `make catalog` REFUSES to start when one is unavailable, before it
# touches anything — a rebuild used to skip it with a warning and emit a catalog
# ~100 rows short that still reported success.  Today `simonberg` is the only
# required source without an upstream URL, so a complete rebuild needs
# BFA_THESIS_PATH.  `apn_reps` is required too but auto-clones.
#
# The rebuild assembles into BFA_catalog.sqlite.building and installs it only
# after verifying that no family lost rows, so a failed rebuild never damages
# the committed catalog.  BFA_ALLOW_PARTIAL=1 lets a partial build finish for
# inspection; it is never installed.
#
# To correct only the declarative APN family, which data-raw fully owns, use
# sync_apn_family.jl — it needs no external source.  See `make sync-apn`.

JULIA   ?= julia
JFLAGS  ?= --startup-file=no --project=$(CURDIR)
CATALOG := $(CURDIR)/../BFA_catalog.sqlite

.PHONY: all catalog check check-structure sync-apn \
        apn_reps quadratic_apn_8bit beierle2025 sboxu_reconcile \
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

# Narrow, in-place sync of the declarative APN family (data-raw/apn_catalog/)
# into the existing catalog. Needs no external source, so it works on a clone
# that cannot run a full rebuild. Not a substitute for `catalog`: it touches
# family = 'APN' only. Run `check` afterwards.
sync-apn:
	$(JULIA) $(JFLAGS) $(CURDIR)/sync_apn_family.jl

# ── individual external-source targets ─────────────────────────────────────
# Each runs its importer against the *existing* catalog (no rebuild from
# scratch).  Useful for re-importing a single source after an upstream update.

apn_reps:
	$(JULIA) $(JFLAGS) $(CURDIR)/import_apn_reps.jl

quadratic_apn_8bit:
	$(JULIA) $(JFLAGS) $(CURDIR)/import_quadratic_apn_8bit.jl

# The Beierle et al. 2025 dataset: 3,775,599 quadratic APN over GF(2^8) from
# Zenodo 16752428 (new_apns.txt, 3.4 GB). Point BFA_BEIERLE2025_PATH at the
# directory that holds the file; the rebuild never downloads it. The 175 MiB
# side store this writes is regenerable and is NOT committed, so run this target
# on a fresh clone to make the corpus usable. Give Julia every thread you have:
# the run re-encodes and σ-signs 3.8 million functions.
beierle2025:
	$(JULIA) $(JFLAGS) -t auto $(CURDIR)/import_beierle2025.jl

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
