JULIA ?= julia
MAKEFILE_DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
ROOT := $(abspath $(MAKEFILE_DIR)/../../..)
JULIA_PROJECT := --project=$(ROOT)
# Python of the virtual environment with sboxU v1.3.1 (see ../kasami_x57/README.md).
VENV ?= $(HOME)/.venvs/sboxu
PY ?= $(VENV)/bin/python
# limit=N tests a random sample of N of the 553 functions (seed=S); empty = all 553.
limit ?=
seed ?= 1
# Number of processes (one thread each). Keep it at 3 or less on the shared machine.
procs ?= 3
OUT ?= $(MAKEFILE_DIR)$(if $(limit),results/sample_limit$(limit)_seed$(seed).tsv,results.tsv)
LIMIT_ARG := $(if $(limit),--limit $(limit) --seed $(seed),)

.PHONY: help check controls run

help:
	@echo "Targets:"
	@echo "  make check [limit=N] [seed=S] [procs=P]  controls + run (all 553: about 4 min with 3 processes)"
	@echo "  make controls                            Kim and Dillon (n = 6) true, Gold x^3 (n = 8) false, decoder"
	@echo "  make run [limit=N]                       test the 553 functions -> $(OUT)"
	@echo "Variables: PY=$(PY)  ROOT=$(ROOT)"

check: controls run
	@test $$(awk -F'\t' 'NR > 1 && $$2 == "true"' $(OUT) | wc -l) -eq 0 \
	  || (echo "FAIL: a function is CCZ-equivalent to a permutation"; exit 1)
	@echo "permutation check: PASS"

controls:
	cd $(MAKEFILE_DIR) && $(JULIA) $(JULIA_PROJECT) export_controls.jl
	cd $(MAKEFILE_DIR) && $(PY) perm_test.py controls

run:
	mkdir -p $(MAKEFILE_DIR)results
	cd $(MAKEFILE_DIR) && for k in $$(seq 0 $$(($(procs) - 1))); do \
	  $(PY) perm_test.py run $(LIMIT_ARG) --shard $$k/$(procs) --out results/shard$$k.tsv & \
	done; wait
	cd $(MAKEFILE_DIR) && $(PY) perm_test.py merge $(OUT) \
	  $$(for k in $$(seq 0 $$(($(procs) - 1))); do echo results/shard$$k.tsv; done)
