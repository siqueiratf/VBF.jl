JULIA ?= julia
MAKEFILE_DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
ROOT := $(abspath $(MAKEFILE_DIR)/../../../..)
J := $(JULIA) --project=$(ROOT)
threads ?= 2

.PHONY: help all admissible estimates gold graph6 graph7 aut7 isolated8

default: help

admissible:   ## admissible vs realizable selections, n = 4..8 (about 2.5 min)
	$(J) -t $(threads) -e 'include("$(MAKEFILE_DIR)admissible.jl"); admissible_report(ns=4:8, n7_per_class=1, cap=200_000)'

estimates:    ## Knuth estimates of the admissible counts (needs results/admissible.tsv)
	$(J) -e 'include("$(MAKEFILE_DIR)admissible.jl"); admissible_estimates()'

gold:         ## classes reached from x^3|_H, n = 4..8, and TPPA Example 4.2
	$(J) -e 'include("$(MAKEFILE_DIR)neighbours.jl"); for n in 4:7; gold_reach(n); end; example42_check()'

graph6:       ## exact neighbour graph, n = 6
	$(J) -t $(threads) -e 'include("$(MAKEFILE_DIR)neighbours.jl"); graph_small(6)'

graph7:       ## exact neighbour graph, n = 7 (about 15 min on 1 thread)
	$(J) -t $(threads) -e 'include("$(MAKEFILE_DIR)neighbours.jl"); graph_small(7)'

aut7:         ## |Aut| of the 488 classes at n = 7 (about 30 min)
	$(J) -e 'include("$(MAKEFILE_DIR)neighbours.jl"); aut_small(7)'

isolated8:    ## all 255 hyperplanes of 20 random beierle2025_n8 members (about 3 min)
	$(J) -t $(threads) -e 'include("$(MAKEFILE_DIR)neighbours.jl"); isolated8()'

all: admissible estimates gold graph6 graph7 aut7 isolated8

help:
	@grep -E '^[a-z0-9]+:.*##' $(MAKEFILE_LIST) | sed 's/:.*##/ :/'
	@echo "threads=$(threads)"
