# Emit sporadic.toml blocks for Triplicate Table 2 rows 3-6 (rows 1 and 2 are
# EA-equivalent to Li-Zhou-Li-Qu and Edel-Kyureghyan-Pott, already catalogued).
include(joinpath(@__DIR__, "triplicate_hik_n10.jl"))
const T = "Budaghyan-Ivkovic-Kaleyski 2023 (Triplicate functions), Table 2"
const BETA = "over GF(2^10), beta primitive in GF(4) (beta = p^341, mod x^10+x^6+x^5+x^3+x^2+x+1; the class does not depend on the modulus)"
entries = [
    ("Triplicate_3", "n10_Triplicate2023_3", "x^3+x^6+beta^2 x^24+beta x^48+beta x^72+x^132+x^288 $BETA. $T row 3. EA-equivalent to Helleseth-Ichanska-Kaleyski 2026 (ePrint 2026/2401) F3 at m = 5."),
    ("Triplicate_4", "n10_Triplicate2023_4", "x^3+x^9+beta^2 x^12+x^36+x^48+beta x^264+beta x^516 $BETA. $T row 4. EA-equivalent to Helleseth-Ichanska-Kaleyski 2026 (ePrint 2026/2401) F2 at m = 5."),
    ("Triplicate_5", "n10_Triplicate2023_5", "x^3+x^18+beta^2 x^24+beta^2 x^36+x^48+x^72+beta^2 x^288 $BETA. $T row 5."),
    ("Triplicate_6", "n10_Triplicate2023_6", "x^3+x^9+beta x^24+x^33+x^66+beta x^72+beta x^258 $BETA. $T row 6. EA-equivalent to Helleseth-Ichanska-Kaleyski 2026 (ePrint 2026/2401) F1 at m = 5."),
]
open(ARGS[1], "w") do io
    for (row, name, notes) in entries
        F = byname[row]
        VBF.differential_uniformity(F) == 2 || error("$row is not APN")
        println(io, "[[functions]]\nbib_key = \"Budaghyan_202300\"\ncanonical_name = \"$name\"\ncontributor = \"VBF.jl data-build\"")
        println(io, "lut = [", join(Int.(collect(F.lut)), ", "), "]")
        println(io, "m = 10\nn = 10\nnotes = \"$notes\"\nsource_repo = \"VBF.jl n = 10 literature import (2026-10-17)\"")
    end
end
println("wrote ", length(entries), " entries")
