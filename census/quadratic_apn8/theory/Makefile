JULIA ?= julia

MAKEFILE_DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
ROOT := $(abspath $(MAKEFILE_DIR)/../../..)
JULIA_PROJECT := --project=$(ROOT)

# check_uniqueness: n = 8 uses about `samples` (F, H) pairs with `hpf` hyperplanes per
# function; n = 6 and n = 7 use every catalog class and every hyperplane.
n ?= 8
samples ?= 5000
hpf ?= 5
seed ?= 1
threads ?= 2

.PHONY: help check_uniqueness check_uniqueness_all

default: help

check_uniqueness:
	@echo "Hyperplane restrictions: n=$(n) samples=$(samples) hpf=$(hpf) seed=$(seed) threads=$(threads)"
	$(JULIA) $(JULIA_PROJECT) -t $(threads) -e \
	  'include(joinpath("$(MAKEFILE_DIR)", "check_uniqueness.jl")); \
	   check_uniqueness(; n=$(n), samples=$(samples), hpf=$(hpf), seed=$(seed))'

check_uniqueness_all:
	$(MAKE) -f $(MAKEFILE_DIR)Makefile check_uniqueness n=6
	$(MAKE) -f $(MAKEFILE_DIR)Makefile check_uniqueness n=7
	$(MAKE) -f $(MAKEFILE_DIR)Makefile check_uniqueness n=8

help:
	@echo 'Theory checks for the quadratic APN census (see METHOD.md, UNIQUENESS.md)'
	@echo '  check_uniqueness      e(F|_H) for known quadratic APN F and hyperplanes H'
	@echo '                        -> results/uniq_n<n>.tsv and a summary on stdout'
	@echo '  check_uniqueness_all  n = 6, 7 (exhaustive over classes and hyperplanes) and n = 8'
	@echo 'Parameters: n=$(n) samples=$(samples) hpf=$(hpf) seed=$(seed) threads=$(threads)'
	@echo 'Example: make check_uniqueness samples=5000 threads=2'
