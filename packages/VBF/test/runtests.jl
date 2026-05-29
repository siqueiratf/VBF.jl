using ReTestItems, VBF

# Parallel test runner. Each test file is a single `@testitem` (see
# test/unit and test/property); ReTestItems runs them across worker
# processes for isolation + speed. Override the worker count with the
# RETESTITEMS_NWORKERS environment variable.
const NWORKERS = parse(Int, get(ENV, "RETESTITEMS_NWORKERS",
                                string(min(Sys.CPU_THREADS, 8))))

runtests(VBF; nworkers = NWORKERS)
