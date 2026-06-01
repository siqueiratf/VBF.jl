using ReTestItems, VBF

const NWORKERS = parse(Int, get(ENV, "RETESTITEMS_NWORKERS",
                                string(min(Sys.CPU_THREADS, 8))))

const TESTITEM_TIMEOUT = parse(Int, get(ENV, "RETESTITEMS_TESTITEM_TIMEOUT", "900"))

runtests(VBF; nworkers = NWORKERS, testitem_timeout = TESTITEM_TIMEOUT)
