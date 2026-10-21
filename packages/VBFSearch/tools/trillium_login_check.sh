#!/bin/bash
# A bounded, single-CPU smoke check; run this manually on a login node.
set -euo pipefail

: "${VBF_WORKSPACE:?Set the staged VBF.jl checkout on SCRATCH}"
: "${VBF_DEPOT:?Set the prepared Julia depot on SCRATCH}"
runtime="${VBF_JULIA:-julia}"
export JULIA_DEPOT_PATH="$VBF_DEPOT"
export JULIA_NUM_THREADS=1 JULIA_NUM_PRECOMPILE_TASKS=1 JULIA_PKG_PRECOMPILE_AUTO=0
export JULIA_PKG_OFFLINE=true OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 MKL_NUM_THREADS=1

allowed=$(awk '/^Cpus_allowed_list:/ {print $2}' /proc/self/status)
cpu="${allowed%%[-,]*}"
taskset -pc "$cpu" "$$" >/dev/null
printf 'Login smoke check: one CPU (%s), one Julia compute thread, 60s wall limit.\n' "$cpu"
(
    ulimit -t 30
    exec timeout --signal=TERM --kill-after=5s 60s \
        "$runtime" --startup-file=no --compiled-modules=existing \
        --threads=1,0 --gcthreads=1,0 --heap-size-hint=512M \
        --project="$VBF_WORKSPACE" -e '
            using TOML, SHA
            VERSION >= v"1.12" || error("Julia >= 1.12 is required")
            Threads.nthreads(:default) == 1 || error("expected one compute thread")
            println("Julia ", VERSION, "; executable SHA256=",
                bytes2hex(open(SHA.sha256, joinpath(Sys.BINDIR, "julia"))))
            if !isempty(get(ENV, "VBF_CHECKPOINT", ""))
                manifest = TOML.parsefile(joinpath(ENV["VBF_CHECKPOINT"], "checkpoint-manifest.toml"))
                expected = manifest["runtime_build"]
                string(VERSION) == manifest["julia"] || error("checkpoint Julia version differs")
                string(Base.GIT_VERSION_INFO.commit) == expected["commit"] || error("checkpoint Julia build differs")
                bytes2hex(open(SHA.sha256, joinpath(Sys.BINDIR, "julia"))) == expected["executable_sha256"] ||
                    error("checkpoint Julia executable differs; use its matching runtime/container")
            end
            using VBF, VBFSearch
            F = gold_apn(4)
            differential_uniformity(F) == 2 || error("four-bit Gold APN smoke check failed")
            include(joinpath(ENV["VBF_WORKSPACE"], "packages", "VBFSearch", "tools", "vbfsearch.jl"))
            VBFSearchCommand.main(["--recursive-closure", "-j1", "--dry-run"])
            println("PASS: VBFSearch dependencies, four-bit Gold APN and command dry run. No search or checkpoint scan performed.")
        '
)

# These queries read scheduler metadata; a default account needs no --account.
if command -v sacctmgr >/dev/null; then
    timeout 10s sacctmgr -nP show user "$USER" format=User,DefaultAccount || true
fi
if command -v sinfo >/dev/null; then
    timeout 10s sinfo -h -o '%P|%l|%c|%m' | sort -u || true
fi
