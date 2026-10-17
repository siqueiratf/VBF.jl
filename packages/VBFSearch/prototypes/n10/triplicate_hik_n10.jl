# Triplicate (Budaghyan-Ivkovic-Kaleyski 2023, Table 2) and Helleseth-Ichanska-
# Kaleyski 2026 (ePrint 2026/2401, Section IV) instances over F_2^10, compared with
# the published set of published_n10.jl. Coefficients lie in F_4: beta = p^341.
include(joinpath(@__DIR__, "published_n10.jl"))
b, b2 = p(341), p(682)
new = [
    "Triplicate_1" => poly([(1,3),(1,33),(b2,36),(b,66),(b,96),(1,129)]),
    "Triplicate_2" => poly([(1,3),(b,9),(b,36),(1,96),(b2,129),(1,768)]),
    "Triplicate_3" => poly([(1,3),(1,6),(b2,24),(b,48),(b,72),(1,132),(1,288)]),
    "Triplicate_4" => poly([(1,3),(1,9),(b2,12),(1,36),(1,48),(b,264),(b,516)]),
    "Triplicate_5" => poly([(1,3),(1,18),(b2,24),(b2,36),(1,48),(1,72),(b2,288)]),
    "Triplicate_6" => poly([(1,3),(1,9),(b,24),(1,33),(1,66),(b,72),(b,258)]),
    "HIK2026_Fl" => poly([(1,3),(b,9),(b2,96),(1,288),(b,33),(b2,264),(b2,528)]),
    "HIK2026_F1" => poly([(1,3),(b,9),(b2,96),(1,288),(b,66),(b,132),(1,264),(1,528)]),
    "HIK2026_F2" => poly([(1,3),(b,129),(b2,96),(1,36),(b,66),(1,132),(1,264),(1,528)]),
    "HIK2026_F3" => poly([(1,3),(b,129),(b2,96),(1,36),(b2,33),(1,66),(b,132),(b,264),(b,528)]),
]
spec(F) = sort([Int(v) for (_, v) in differential_spectrum(ortho_derivative(F))]; rev = true)
println("\n== ortho-derivative DDT counts (compare with Table 2/4 of the Triplicate paper) ==")
for (name, F) in [rows; new]
    startswith(name, "UiB") || startswith(name, "Triplicate") || startswith(name, "HIK") || name == "LiZhouLiQu2022_m5" || continue
    println(rpad(name, 26), spec(F))
end
pub = Dict(sigma_hash(F) => name for (name, F) in rows)
for (s, n0) in known; pub[s] = n0; end
println("\n== classes ==")
for (name, F) in new
    d = VBF.differential_uniformity(F)
    s = sigma_hash(F)
    hit = get(pub, s, nothing)
    line = rpad(name, 16) * " delta=$d  sigma match: " * something(hit, "none")
    if hit !== nothing && haskey(byname, hit)
        line *= "  EA=" * string(are_ea_equivalent(F, byname[hit]))
    end
    println(line)
    pub[s] = get(pub, s, name)
    byname[name] = F
end

# Triplicate Table 4, family C14-2 (Gologlu F2) representatives.
println("\n== Triplicate Table 4, C14-2 ==")
for (name, F) in ["C14-2_a x3+b2x9+x96+x288" => poly([(1,3),(b2,9),(1,96),(1,288)]),
                  "C14-2_b x3+x36+x96+bx129" => poly([(1,3),(1,36),(1,96),(b,129)])]
    s = sigma_hash(F); hit = get(pub, s, nothing)
    line = rpad(name, 26) * " delta=$(VBF.differential_uniformity(F)) spec=$(spec(F)) match: " * something(hit, "none")
    hit !== nothing && haskey(byname, hit) && (line *= "  EA=" * string(are_ea_equivalent(F, byname[hit])))
    println(line)
end
