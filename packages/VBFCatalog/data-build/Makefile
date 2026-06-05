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

.PHONY: all catalog \
        apn_reps quadratic_apn_8bit sboxu_reconcile \
        simonberg xanadu apn_repo \
        clean reset

# Full build: BFA base data + all external sources in sources.toml order.
all: catalog

catalog:
	$(JULIA) $(JFLAGS) $(CURDIR)/build_catalog.jl

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

# ── catalog reset ───────────────────────────────────────────────────────────

clean:
	rm -f $(CATALOG)

reset: clean
