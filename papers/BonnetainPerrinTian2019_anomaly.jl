using VBF
using VBFCatalog

"AES DDT positive anomaly, in bits."
reproduce() = Float64(table_anomaly(load_literature_sbox("AES"), :DDT))

function report(io::IO = stdout)
    a = reproduce()
    println(io, "# DDT anomaly of AES — Bonnetain–Perrin–Tian, ASIACRYPT 2019")
    println(io, "positive DDT anomaly ≈ ", round(a; digits = 1), " bits (≫ 1000 expected)")
end

if abspath(PROGRAM_FILE) == @__FILE__
    report()
end
