using ReTestItems, VBF

const NWORKERS = parse(Int, get(ENV, "RETESTITEMS_NWORKERS",
                                string(min(Sys.CPU_THREADS, 8))))

const TESTITEM_TIMEOUT = parse(Int, get(ENV, "RETESTITEMS_TESTITEM_TIMEOUT", "900"))

# Run a subset by test-item name, e.g. VBF_TEST_NAME='catalog_queries|apn_catalog'.
# Used by .githooks/catalog-check to run just the catalog items pre-commit; unset
# (the default, and what CI uses) runs everything.
const NAME_FILTER = get(ENV, "VBF_TEST_NAME", "")

if isempty(NAME_FILTER)
    runtests(VBF; nworkers = NWORKERS, testitem_timeout = TESTITEM_TIMEOUT)
else
    runtests(VBF; nworkers = NWORKERS, testitem_timeout = TESTITEM_TIMEOUT,
             name = Regex("^(?:" * NAME_FILTER * ")\$"))
end
