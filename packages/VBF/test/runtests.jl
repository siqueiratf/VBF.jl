using ReTestItems, VBF

# Parallel test runner. Each test file is a single `@testitem` (see
# test/unit and test/property); ReTestItems runs them across worker
# processes for isolation + speed. Override the worker count with the
# RETESTITEMS_NWORKERS environment variable.
const NWORKERS = parse(Int, get(ENV, "RETESTITEMS_NWORKERS",
                                string(min(Sys.CPU_THREADS, 8))))

# Per-item timeout (seconds) so a single slow or stuck item fails fast with a
# stacktrace instead of consuming the whole CI budget. The heaviest item runs in
# well under a minute locally; this leaves ample headroom on slower CI machines
# while still catching a genuine hang. Override with RETESTITEMS_TESTITEM_TIMEOUT.
const TESTITEM_TIMEOUT = parse(Int, get(ENV, "RETESTITEMS_TESTITEM_TIMEOUT", "900"))

runtests(VBF; nworkers = NWORKERS, testitem_timeout = TESTITEM_TIMEOUT)
