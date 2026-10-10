using ReTestItems, VBFCatalog

const NWORKERS = parse(Int, get(ENV, "RETESTITEMS_NWORKERS",
                                string(min(Sys.CPU_THREADS, 8))))
const TESTITEM_TIMEOUT = parse(Int, get(ENV, "RETESTITEMS_TESTITEM_TIMEOUT", "900"))
# Catalog gate and local development can select test items by name.
const NAME_FILTER = get(ENV, "VBFCATALOG_TEST_NAME", "")

if isempty(NAME_FILTER)
    runtests(VBFCatalog; nworkers = NWORKERS, testitem_timeout = TESTITEM_TIMEOUT)
else
    runtests(VBFCatalog; nworkers = NWORKERS, testitem_timeout = TESTITEM_TIMEOUT,
             name = Regex("^(?:" * NAME_FILTER * ")\$"))
end
