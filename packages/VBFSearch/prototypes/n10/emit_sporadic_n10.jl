# Emit sporadic.toml blocks for the 13 published n = 10 quadratic APN classes
# that the catalog lacked (verified by published_n10.jl: delta = 2, distinct sigma,
# shared sigma confirmed by are_ea_equivalent).
include(joinpath(@__DIR__, "published_n10.jl"))
const MOD = "mod x^10+x^6+x^5+x^3+x^2+x+1 (Conway polynomial, the Magma default), p = x primitive"
const UIB = "UiB Boolean function wiki, 'CCZ-inequivalent representatives from the known APN families for dimensions up to 11'"
const BL = "Beierle-Leander 2022, Zenodo 10.5281/zenodo.4738942 v2.1 apn_10bit.txt (CC-BY-4.0, sha256 f3a8d91b...66c03)"
entries = [
    ("UiB10.5 x6+x33+p31x192", "n10_BC2008_hexanomial_x6_x33_x192", "Budaghyan_200805", "x^6+x^33+p^31 x^192 over GF(2^10), $MOD. $UIB, row 10.5 (Budaghyan-Carlet hexanomial family)."),
    ("UiB10.6 x33+x72+p31x258", "n10_BC2008_hexanomial_x33_x72_x258", "Budaghyan_200805", "x^33+x^72+p^31 x^258 over GF(2^10), $MOD. $UIB, row 10.6 (Budaghyan-Carlet hexanomial family)."),
    ("UiB10.7 x3+Tr(x9)", "n10_BCL2009_x3_Tr_x9", "Budaghyan_200904", "x^3+Tr_1^10(x^9) over GF(2^10), $MOD. $UIB, row 10.7. EA-equivalent to Yu et al. 2025 short form x^513+x^192+x^96+x^48+x^33+x^18+x^12."),
    ("UiB10.8 x3+a^-1Tr(a3x9)", "n10_BCL2009_x3_ainvTr_a3x9", "Budaghyan_200910", "x^3+a^-1 Tr_1^10(a^3 x^9), a = p, over GF(2^10), $MOD. $UIB, row 10.8. Budaghyan-Carlet-Leander, IEEE ITW 2009, Eq. (6) (Corollary 3; APN by Corollary 4); Finite Fields Appl. 15 (2009) has only the case a = 1. The n = 10 exchange prototype (packages/VBFSearch/prototypes/n10) rediscovered this class from x^3."),
    ("UiB10.9 BHK", "n10_BHK2020_x3_x9_x96_x288", "Budaghyan_202011", "x^3+p^341 x^9+p^682 x^96+x^288 over GF(2^10), $MOD. $UIB, row 10.9. EA-equivalent to the BHK2020_C3 reproduction (build_ci_sbox(10,3,2))."),
    ("UiB10.10 BHK", "n10_BHK2020_x3_x129_x96_x36", "Budaghyan_202011", "x^3+p^341 x^129+p^682 x^96+x^36 over GF(2^10), $MOD. $UIB, row 10.10. EA-equivalent to the BHK2020_C7 reproduction (build_ci_sbox(10,7,0))."),
    ("UiB10.17 x3+p341x36", "n10_EKP2006_x3_x36", "Edel_200602", "x^3+p^341 x^36 over GF(2^10), $MOD. $UIB, row 10.17; the Edel-Kyureghyan-Pott function."),
    ("BeierleLeander2022_1", "n10_BeierleLeander2022_1", "Beierle_202201", "$BL, line 1."),
    ("BeierleLeander2022_2", "n10_BeierleLeander2022_2", "Beierle_202201", "$BL, line 2. EA-equivalent to Gologlu 2022 F2 (i = 2) and Zheng et al. 2022 Remark 3.6."),
    ("BeierleLeander2022_3", "n10_BeierleLeander2022_3", "Beierle_202201", "$BL, line 3. EA-equivalent to Gologlu 2022 F3 and Zheng et al. 2022 Example 1."),
    ("BeierleLeander2022_4", "n10_BeierleLeander2022_4", "Beierle_202201", "$BL, line 4. EA-equivalent to Gologlu 2022 F2 (i = 1) and Zheng et al. 2022 Theorem 3.3 (F15)."),
    ("BeierleLeander2022_5", "n10_BeierleLeander2022_5", "Beierle_202201", "$BL, line 5."),
    ("LiZhouLiQu2022_m5", "n10_LiZhouLiQu2022_bivariate", "Li_202207", "(x^3+xy^2+y^3+xy, x^5+x^4y+y^5+xy+x^2y^2) on GF(2^5)^2, GF(2^5) mod x^5+x^2+1; input x + 2^5 y, output u + 2^5 v."),
]
open(ARGS[1], "w") do io
    for (row, name, bib, notes) in entries
        F = byname[row]
        VBF.differential_uniformity(F) == 2 || error("$row is not APN")
        println(io, "[[functions]]")
        println(io, "bib_key = \"$bib\"")
        println(io, "canonical_name = \"$name\"")
        println(io, "contributor = \"VBF.jl data-build\"")
        println(io, "lut = [", join(Int.(collect(F.lut)), ", "), "]")
        println(io, "m = 10\nn = 10")
        println(io, "notes = \"", notes, "\"")
        println(io, "source_repo = \"VBF.jl n = 10 literature import (2026-10-17)\"")
    end
end
println("wrote ", length(entries), " entries")
