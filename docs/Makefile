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
# First, prebuilt.jl installs the Zenodo version of this checkout (about 490 MB).
# It skips locally built data and does nothing when the installed data is current.
# Without a Zenodo version, or with prebuilt=0, data-build makes each absent file
# from the originals; this downloads the Beierle et al. 2025 corpus (3.16 GB) once.
# The index is current when it was built for the inputs_sha256 of the catalog
# (data_status.jl), so a catalog rebuild from the same inputs does not rebuild it.
# A failed or stopped step deletes its partial file, so the next run builds it again.
prebuilt ?= 1
STATUS = $(JULIA) --startup-file=no --project="$(IMPORT)" "$(DOCS)data_status.jl"
.DELETE_ON_ERROR:
data: check-julia import-instantiate
	@if [ "$(prebuilt)" != 0 ] && { [ ! -f "$(DATA)/catalog.sqlite" ] || [ -f "$(DATA)/prebuilt.toml" ]; }; then \
		echo "make: getting the prebuilt data of this checkout from Zenodo (about 490 MB the first time)"; \
		if $(JULIA) --startup-file=no --project="$(IMPORT)" "$(IMPORT)/prebuilt.jl" fetch; then \
			rm -f "$(DATA)/ccz_sigma_index.inputs"; \
		else \
			echo "make: no prebuilt data for this checkout; building it from the originals (about 45 minutes)"; \
		fi; \
	fi
	@$(MAKE) --no-print-directory data-build INSTANTIATED=1

data-build: $(DATA)/catalog.sqlite $(DATA)/members.sqlite
	@if ! $(STATUS) check "$(DATA)"; then \
		echo "make: the signature index is absent or was built for other catalog inputs;"; \
		echo "make: building it now (about 30 minutes with $(threads) threads)"; \
		rm -f "$(DATA)/ccz_sigma_index.inputs"; \
		$(MAKE) -C "$(IMPORT)" index threads=$(threads) && $(STATUS) stamp "$(DATA)"; \
	fi

# INSTANTIATED=1 tells a sub-make that this already ran.
import-instantiate: check-julia
ifndef INSTANTIATED
	@echo "make: installing the Julia packages of the catalog tools (only slow the first time)"
	@$(JULIA) --startup-file=no --project="$(IMPORT)" -e 'using Pkg; Pkg.instantiate(); Pkg.activate("$(ROOT)/packages/VBFCatalog"; io=devnull); Pkg.instantiate()'
endif

$(DATA)/catalog.sqlite: | import-instantiate
	@echo "make: building catalog.sqlite from the pinned sources"
	$(MAKE) -C "$(IMPORT)" catalog threads=$(threads)

$(DATA)/members.sqlite: | $(DATA)/catalog.sqlite
	@echo "make: downloading (3.16 GB) and checking the Beierle et al. 2025 corpus"
	$(MAKE) -C "$(IMPORT)" fetch SOURCE=beierle2025
	$(MAKE) -C "$(IMPORT)" convert SOURCE=beierle2025 threads=$(threads)

instantiate: check-julia
	$(JULIA) --project="$(DOCS)" -e 'using Pkg; Pkg.instantiate()'

inspector-instantiate: check-julia
	@echo "make: installing the Julia packages of the inspector (only slow the first time)"
	@JULIA_NUM_PRECOMPILE_TASKS=2 $(JULIA) --project="$(INSPECTOR)" -e 'using Pkg; Pkg.instantiate()'

build: instantiate $(DATA)/catalog.sqlite
	$(JULIA) --project="$(DOCS)" "$(DOCS)make.jl"

serve: data build
	$(MAKE) -C "$(DOCS)" serve-built port="$(port)" host="$(host)" run="$(run)"

serve-built: data inspector-instantiate
	@echo "make: starting the docs and the inspector; open http://$(host):$(port)/docs/ after the line 'APN8 evidence inspector ready'"
	$(JULIA) --threads=1,1 --project="$(INSPECTOR)" "$(INSPECTOR)server.jl" --docs "$(DOCS)build" --port $(port) --host $(host) $(if $(run),--run "$(call resolve,$(run))",)

serve-inspector: data inspector-instantiate
	@echo "make: starting the inspector; open http://$(host):$(port)/ after the line 'APN8 evidence inspector ready'"
	$(JULIA) --threads=1,1 --project="$(INSPECTOR)" "$(INSPECTOR)server.jl" --port $(port) --host $(host) $(if $(run),--run "$(call resolve,$(run))",)

serve-search: inspector-instantiate
	$(JULIA) --threads=1,1 --project="$(INSPECTOR)" "$(INSPECTOR)closure_monitor.jl" --campaign "$(call resolve,$(campaign))" --port $(port) --host $(host) $(if $(run),--run "$(call resolve,$(run))",)

test: inspector-instantiate
	$(JULIA) --threads=1,1 --project="$(INSPECTOR)" "$(INSPECTOR)test/runtests.jl"

test-search: inspector-instantiate
	$(JULIA) --threads=1,1 --project="$(INSPECTOR)" "$(INSPECTOR)test/closure_monitor.jl"
	$(JULIA) --threads=1,1 --project="$(INSPECTOR)" "$(INSPECTOR)test/closure_graph.jl"
