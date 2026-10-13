JULIA ?= julia
MAKEFILE_DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
ROOT := $(abspath $(MAKEFILE_DIR)/../../..)
JULIA_PROJECT := --project=$(ROOT)
# Python of the virtual environment with sboxU v1.3.1 (see README.md).
VENV ?= $(HOME)/.venvs/sboxu
PY ?= $(VENV)/bin/python
DATA := $(MAKEFILE_DIR)data
X57 := catalog_43_n8_Kasami_x57 catalog_581_eightBitAPN_23 catalog_634_n8_Kasami_i5 \
       x57_mod11b x57_mod11d x228_mod11b x228_mod11d
CONTROLS := vbf_dillon_apn_permutation vbf_kim_apn catalog_41_n8_Gold_x3 \
            catalog_40_n8_Calderini2021_thm62

.PHONY: help check luts x57 controls sigma vbf_count

help:
	@echo "Targets (one thread each, about 5 min in total):"
	@echo "  make check      luts + x57 + controls + sigma; fails if a verdict differs"
	@echo "  make luts       export catalog/VBF LUTs (Julia) and build x^57, x^228, x^3 (Python)"
	@echo "  make x57        EA classes in the CCZ class of x^57 (7 LUTs)  -> data/x57.log"
	@echo "  make controls   same method on Dillon, Kim, Gold x^3, Calderini; n = 8 non-quadratic starts"
	@echo "  make sigma      σ check of the degree-2 representatives (controls; x^57 has none)"
	@echo "  make vbf_count  independent subspace count with VBF (slow for n = 8; optional)"
	@echo "Variables: PY=$(PY)  ROOT=$(ROOT)"

check: luts x57 controls sigma
	@echo "kasami_x57 check: PASS"

luts:
	cd $(MAKEFILE_DIR) && $(JULIA) $(JULIA_PROJECT) export_luts.jl
	cd $(MAKEFILE_DIR) && $(PY) power_luts.py

x57:
	cd $(MAKEFILE_DIR) && $(PY) ccz_ea_classes.py data/luts.tsv,data/power_luts.tsv $(X57) \
	  --out data/x57_quadratic_reps.tsv | tee data/x57.log
	@test $$(grep -c "quadratic representative: NO" $(DATA)/x57.log) -eq 7 \
	  || (echo "FAIL: a x^57 row has a quadratic representative or did not run"; exit 1)
	@test $$(grep -c "n-dim subspaces in Z_F: 1 " $(DATA)/x57.log) -eq 7 \
	  || (echo "FAIL: subspace count of x^57 is not 1"; exit 1)

controls:
	cd $(MAKEFILE_DIR) && $(PY) ccz_ea_classes.py data/luts.tsv $(CONTROLS) \
	  --out data/controls_quadratic_reps.tsv | tee data/controls.log
	@test $$(grep -c "quadratic representative: YES" $(DATA)/controls.log) -eq 4 \
	  || (echo "FAIL: a positive control has no quadratic representative"; exit 1)
	cd $(MAKEFILE_DIR) && $(PY) control_n8.py | tee data/control_n8.log

sigma:
	cd $(MAKEFILE_DIR) && $(JULIA) $(JULIA_PROJECT) sigma_check.jl data/x57_quadratic_reps.tsv
	cd $(MAKEFILE_DIR) && $(JULIA) $(JULIA_PROJECT) sigma_check.jl data/controls_quadratic_reps.tsv \
	  | tee data/controls_sigma.log

vbf_count:
	cd $(MAKEFILE_DIR) && $(JULIA) $(JULIA_PROJECT) vbf_subspace_count.jl dillon kim 41 43 \
	  | tee data/vbf_subspace_count.log
