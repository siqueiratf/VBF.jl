using VBF
using VBFCatalog

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
