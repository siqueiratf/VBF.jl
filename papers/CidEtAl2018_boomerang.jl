# Reproduction: Boomerang Connectivity Table
# Cid, Huang, Peyrin, Sasaki, Song — EUROCRYPT 2018  [CidEtAl2018BCT]
#
# The BCT measures resistance to boomerang attacks; its maximum off-origin
# entry is the *boomerang uniformity*. This script recomputes it for
# standard cipher S-boxes with BFA's `boomerang_uniformity` and checks it
# against the published values.
#
# Run standalone:  julia --project=. papers/CidEtAl2018_boomerang.jl

using VBF

"Published boomerang uniformities (Cid et al. 2018, Table 1 / follow-ups)."
const EXPECTED = (AES = 6, PRESENT = 16, GIFT = 16)

reproduce() = NamedTuple{keys(EXPECTED)}(
    map(name -> boomerang_uniformity(load_literature_sbox(String(name))), keys(EXPECTED)))

function report(io::IO = stdout)
    println(io, "# Boomerang uniformity — Cid et al., EUROCRYPT 2018")
    r = reproduce()
    for name in keys(EXPECTED)
        ok = r[name] == EXPECTED[name] ? "ok" : "MISMATCH"
        println(io, "- ", rpad(String(name), 8), " BU = ", r[name],
                "  (published ", EXPECTED[name], ") ", ok)
    end
end

if abspath(PROGRAM_FILE) == @__FILE__
    report()
end
