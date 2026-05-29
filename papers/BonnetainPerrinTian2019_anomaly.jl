# Reproduction: Anomalies and Vector Space Search
# Bonnetain, Perrin, Tian — ASIACRYPT 2019  [BonnetainPerrinTian2019Anomaly]
#
# The "positive anomaly" of a table scores how implausibly small its
# maximum is under the random-permutation null. The AES DDT is extremely
# anomalous (its differential uniformity 4 is far smaller than a random
# 8-bit permutation's), scoring well over 1000 bits.
#
# Run standalone:  julia --project=. papers/BonnetainPerrinTian2019_anomaly.jl

using VBF

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
