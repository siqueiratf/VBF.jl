#!/usr/bin/env bash
# JULIA for the recipe of the `test` target only (see test_with_evidence): run the last
# argument, the paper's runtests.jl, through evidence_runner.jl. Make still runs the
# prerequisites of `test` with the normal JULIA, so the run equals `make test`.
set -euo pipefail
n=$#
last="${!n}"
exec "${VBF_EVIDENCE_JULIA:-julia}" "${@:1:$((n-1))}" "$(dirname "$0")/evidence_runner.jl" "$last" "$VBF_EVIDENCE_OUT"
