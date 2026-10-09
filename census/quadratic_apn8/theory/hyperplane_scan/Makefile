JULIA ?= julia

MAKEFILE_DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
ROOT := $(abspath $(MAKEFILE_DIR)/../../../..)
JULIA_PROJECT := --project=$(ROOT)
RESULTS := $(MAKEFILE_DIR)results

# scan: source = all or a comma list (catalog, edelpott2009_n8, ..., beierle2025_sample);
# limit = members per source (0 = all; corpora are taken in a fixed random order);
# timeout_seconds = stop taking new functions after this wall time (empty = no limit).
source ?= all
limit ?= 0
threads ?= 10
timeout_seconds ?=
sample ?= 20000
seed ?= 1
p6 ?= true

.PHONY: help scan scan_bg analyze status

default: help

help:
	@echo 'Hyperplane scan: e(F|_H) for all 255 hyperplanes H of known quadratic APN (8,8)-functions'
	@echo '  scan      run the scan in the foreground (resumes from results/functions.tsv)'
	@echo '  scan_bg   run the scan in the background with nohup (log: results/scan.log)'
	@echo '  analyze   tables -> results/analysis.md; verified NEW classes -> new_classes_hyperplane.tsv'
	@echo '  status    progress per source and the last log lines'
	@echo 'Parameters: source=$(source) limit=$(limit) threads=$(threads) timeout_seconds=$(timeout_seconds)'
	@echo '            sample=$(sample) seed=$(seed) p6=$(p6)'
	@echo 'Example: make scan source=edelpott2009_n8,taniguchi2019_n8 threads=4'

scan:
	$(JULIA) $(JULIA_PROJECT) -t $(threads) $(MAKEFILE_DIR)scan.jl source=$(source) limit=$(limit) \
	  threads=$(threads) sample=$(sample) seed=$(seed) $(if $(timeout_seconds),timeout_seconds=$(timeout_seconds))

scan_bg:
	mkdir -p $(RESULTS)
	nohup $(JULIA) $(JULIA_PROJECT) -t $(threads) $(MAKEFILE_DIR)scan.jl source=$(source) limit=$(limit) \
	  threads=$(threads) sample=$(sample) seed=$(seed) $(if $(timeout_seconds),timeout_seconds=$(timeout_seconds)) \
	  >> $(RESULTS)/scan.log 2>&1 &
	@echo 'started; follow with: make status  (or tail -f $(RESULTS)/scan.log)'

analyze:
	$(JULIA) $(JULIA_PROJECT) -t $(threads) $(MAKEFILE_DIR)analyze.jl $(if $(filter false,$(p6)),p6=false)

status:
	@test -f $(RESULTS)/functions.tsv || { echo 'no results yet'; exit 0; }
	@awk -F'\t' 'NR > 1 { n[$$1]++; k[$$1] += $$6; if ($$6 > 0) f[$$1]++; s[$$1] += $$8 } \
	  END { printf "%-28s %8s %10s %12s %10s\n", "source", "functions", "pairs k>1", "fns n_gt1>0", "thread-h"; \
	        for (x in n) printf "%-28s %8d %10d %12d %10.2f\n", x, n[x], k[x], f[x], s[x] / 3600 }' \
	  $(RESULTS)/functions.tsv
	@test -f $(RESULTS)/pairs.tsv && awk -F'\t' 'NR > 1 && $$8 == "NEW" { s[$$7] = 1 } END { print "distinct NEW sigma (unverified):", length(s) }' $(RESULTS)/pairs.tsv || true
	@test -f $(RESULTS)/scan.log && tail -n 3 $(RESULTS)/scan.log || true
	@pgrep -f 'hyperplane_scan/scan.jl' > /dev/null && echo 'scan process: running' || echo 'scan process: not running'
