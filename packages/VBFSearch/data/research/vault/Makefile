# Restore the archived APN search data. See README.md.
#
#   make verify            check the SHA-256 of every archive part
#   make restore-hits      put the class-orbit .hits files back in archive/class-orbit/state/
#   make restore-census    unpack the B6 = 52 and hyperplane-scan outputs into restored/
#   make restore-beierle   unpack the Beierle 2025 class-count study into restored/
#   make restore-datasets  unpack the frozen APN class datasets of 2026-10-17 into restored/
#                          and rebuild their SQLite databases (needs Julia)
#   make restore           all four
#
# Each restore target checks the SHA-256 of every unpacked file against the manifest.
# restore-datasets also checks the logical SHA-256 of every rebuilt table.

VAULT := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
ROOT  := $(abspath $(VAULT)/../../../../..)
OUT   ?= $(VAULT)restored
JULIA ?= julia
DATASETS := $(OUT)/apn-datasets-20261017

.PHONY: verify restore restore-hits restore-census restore-beierle restore-datasets

verify:
	cd "$(VAULT)" && sha256sum -c PARTS.sha256

restore: restore-hits restore-census restore-beierle restore-datasets

restore-hits: verify
	cat "$(VAULT)"class-orbit-hits.tar.zst.part* | zstd -d --long=27 | tar -x -C "$(ROOT)"
	cd "$(ROOT)" && sha256sum -c "$(VAULT)class-orbit-hits.files.sha256"

restore-census: verify
	mkdir -p "$(OUT)"
	cat "$(VAULT)"census-b52-hyperplane.tar.zst.part* | zstd -d --long=27 | tar -x -C "$(OUT)"
	cd "$(OUT)" && sha256sum -c "$(VAULT)census-b52-hyperplane.files.sha256"

restore-beierle: verify
	mkdir -p "$(OUT)"
	cat "$(VAULT)"beierle2025-class-count.tar.zst.part* | zstd -d --long=27 | tar -x -C "$(OUT)"
	cd "$(OUT)" && sha256sum -c "$(VAULT)beierle2025-class-count.files.sha256"

restore-datasets: verify
	mkdir -p "$(OUT)"
	cat "$(VAULT)"apn-datasets-20261017.tar.zst.part* | zstd -d --long=27 | tar -x -C "$(OUT)"
	cd "$(OUT)" && sha256sum -c "$(VAULT)apn-datasets-20261017.files.sha256"
	for d in published-roots-b52-20261017 apn-20261014-190454; do \
	  $(JULIA) --startup-file=no --project="$(ROOT)" --threads=auto \
	    "$(ROOT)/packages/VBFSearch/tools/datasets/compact.jl" restore \
	    "$(DATASETS)/$$d/compact" "$(DATASETS)/$$d/classes.sqlite" || exit 1; \
	done
