JULIA ?= julia
ROOT := $(abspath $(dir $(lastword $(MAKEFILE_LIST)))/../../..)
HERE := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
JFLAGS ?= --startup-file=no --project=$(ROOT)
threads ?= 30
outdir ?= $(HERE)/results/run
method ?= switching
limit ?= 1000
wall_seconds ?= 28800
resume ?= false

.PHONY: search stop resume test history audit report help
search:
	$(JULIA) $(JFLAGS) --threads=$(threads) $(HERE)/run.jl --outdir $(outdir) --workers $(threads) --method $(method) --limit $(limit) --wall-seconds $(wall_seconds) --resume $(resume)
stop:
	touch $(outdir)/STOP
resume:
	rm -f $(outdir)/STOP
	$(MAKE) search resume=true
test:
	$(JULIA) $(JFLAGS) $(HERE)/test/runtests.jl
history:
	$(JULIA) $(JFLAGS) $(HERE)/review_history.jl
audit:
	$(JULIA) $(JFLAGS) $(HERE)/audit.jl $(outdir)
report:
	python3 $(HERE)/report.py $(outdir)
help:
	@echo "search/resume: explicit finite plan, eight-hour default; set outdir, method, limit, threads, wall_seconds"
	@echo "stop: request cooperative stop; test/history/audit/report: evidence and publication exports"
