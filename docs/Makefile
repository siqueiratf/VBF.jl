JULIA ?= julia
DOCS := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
INSPECTOR := $(DOCS)inspector/
ROOT := $(abspath $(DOCS)..)
# make -C docs runs in docs/; resolve a relative path from the repository root.
resolve = $(if $(filter /%,$(1)),$(1),$(ROOT)/$(1))
port ?= 8088
host ?= 127.0.0.1
run ?=
campaign ?=
IMPORT := $(ROOT)/packages/VBFCatalog/src/import
# The same cache as VBFCatalog.catalog_data_dir(): BFA_DATA_DIR overrides it.
DATA := $(abspath $(or $(BFA_DATA_DIR),$(ROOT)/.cache/vbfcatalog))
threads ?= $(shell nproc 2>/dev/null || echo 4)

.PHONY: check-julia data data-build import-instantiate instantiate inspector-instantiate build serve serve-built serve-inspector serve-search test test-search

check-julia:
	@command -v $(JULIA) >/dev/null || { echo "julia not found: install Julia >= 1.12 (https://julialang.org/install/)" >&2; exit 1; }
	@$(JULIA) --startup-file=no -e 'VERSION >= v"1.12" || (println(stderr, "VBF.jl needs Julia >= 1.12, found ", VERSION); exit(1))'

# The inspector data: catalog.sqlite, members.sqlite and ccz_sigma_index.sqlite.
# First, prebuilt.jl installs the Zenodo version of this checkout (about 1 GB).
# It skips locally built data and does nothing when the installed data is current.
# Without a Zenodo version, or with prebuilt=0, data-build makes each absent file
# from the originals; this downloads the Beierle et al. 2025 corpus (3.16 GB) once.
# A failed or stopped step deletes its partial file, so the next run builds it again.
prebuilt ?= 1
.DELETE_ON_ERROR:
data: check-julia
	@if [ "$(prebuilt)" != 0 ] && { [ ! -f "$(DATA)/catalog.sqlite" ] || [ -f "$(DATA)/prebuilt.toml" ]; }; then \
		$(MAKE) --no-print-directory import-instantiate && \
		$(JULIA) --startup-file=no --project="$(IMPORT)" "$(IMPORT)/prebuilt.jl" fetch || \
		echo "make: no prebuilt data for this checkout; building it from the originals"; \
	fi
	@$(MAKE) --no-print-directory data-build

data-build: $(DATA)/ccz_sigma_index.sqlite

import-instantiate: check-julia
	$(JULIA) --startup-file=no --project="$(IMPORT)" -e 'using Pkg; Pkg.instantiate(); Pkg.activate("$(ROOT)/packages/VBFCatalog"); Pkg.instantiate()'

$(DATA)/catalog.sqlite: | import-instantiate
	$(MAKE) -C "$(IMPORT)" catalog threads=$(threads)

$(DATA)/members.sqlite: | $(DATA)/catalog.sqlite
	$(MAKE) -C "$(IMPORT)" fetch SOURCE=beierle2025
	$(MAKE) -C "$(IMPORT)" convert SOURCE=beierle2025 threads=$(threads)

$(DATA)/ccz_sigma_index.sqlite: $(DATA)/catalog.sqlite $(DATA)/members.sqlite
	$(MAKE) -C "$(IMPORT)" index threads=$(threads)

instantiate: check-julia
	$(JULIA) --project="$(DOCS)" -e 'using Pkg; Pkg.instantiate()'

inspector-instantiate: check-julia
	JULIA_NUM_PRECOMPILE_TASKS=2 $(JULIA) --project="$(INSPECTOR)" -e 'using Pkg; Pkg.instantiate()'

build: instantiate $(DATA)/catalog.sqlite
	$(JULIA) --project="$(DOCS)" "$(DOCS)make.jl"

serve: data build
	$(MAKE) -C "$(DOCS)" serve-built port="$(port)" host="$(host)" run="$(run)"

serve-built: data inspector-instantiate
	$(JULIA) --threads=1,1 --project="$(INSPECTOR)" "$(INSPECTOR)server.jl" --docs "$(DOCS)build" --port $(port) --host $(host) $(if $(run),--run "$(call resolve,$(run))",)

serve-inspector: data inspector-instantiate
	$(JULIA) --threads=1,1 --project="$(INSPECTOR)" "$(INSPECTOR)server.jl" --port $(port) --host $(host) $(if $(run),--run "$(call resolve,$(run))",)

serve-search: inspector-instantiate
	$(JULIA) --threads=1,1 --project="$(INSPECTOR)" "$(INSPECTOR)closure_monitor.jl" --campaign "$(call resolve,$(campaign))" --port $(port) --host $(host) $(if $(run),--run "$(call resolve,$(run))",)

test: inspector-instantiate
	$(JULIA) --threads=1,1 --project="$(INSPECTOR)" "$(INSPECTOR)test/runtests.jl"

test-search: inspector-instantiate
	$(JULIA) --threads=1,1 --project="$(INSPECTOR)" "$(INSPECTOR)test/closure_monitor.jl"
	$(JULIA) --threads=1,1 --project="$(INSPECTOR)" "$(INSPECTOR)test/closure_graph.jl"
