# Implements Corollary 1 — APN functions from the class-2/class-3 permutations.
# Paper: Budaghyan, Carlet, Leander (2009), "On a construction of quadratic APN
#        functions", IEEE Trans. Inf. Theory 55(9):4218-4229.
# Section: II.A — The case n even.
#
# Corollary 1: for 6 | n, the functions
#   (4)  x³ + trₙ³(x¹⁸ + x³⁶)
#   (5)  x³ + trₙ³(x⁹  + x¹⁸)
# are APN on GF(2ⁿ).
#
# Pseudocode:
#   for n in {6, (12 gated)}:  build (4),(5); assert δ==2 and deg==2.
# VBF API used: differential_uniformity, algebraic_degree, SBox

include(joinpath(@__DIR__, "helpers.jl"))

"""
    corollary1_report(io; full_search, save_results) -> NamedTuple

Verify eqs (4) and (5) are APN quadratic for 6 | n (n=6; n=12 under full_search).
"""
function corollary1_report(
    io::IO = stdout;
    full_search::Bool = false,
    save_results::Bool = false,
)
    print_section("Corollary 1 — 6|n: eqs (4) x³+trₙ³(x¹⁸+x³⁶), (5) x³+trₙ³(x⁹+x¹⁸) APN", io)
    ns = full_search ? [6, 12] : [6]
    all_ok = true
    rows = Tuple{Int,Symbol,Int,Int}[]
    for n in ns
        for (name, lut) in ((:eq4, apn_eq4(n)), (:eq5, apn_eq5(n)))
            F = as_sbox(lut, n)
            du = differential_uniformity(F)
            deg = algebraic_degree(F)
            ok = du == 2 && deg == 2
            all_ok &= ok
            print_check("n=$n $name: APN (δ=$du), quadratic (deg=$deg)", ok, io)
            push!(rows, (n, name, du, deg))
        end
    end
    print_kv("completeness", full_search ? "n=6,12" : "n=6 (n=12 gated by full_search)", io)
    result = (; all_ok, rows)
    if save_results
        mkpath(joinpath(@__DIR__, "results"))
        open(joinpath(@__DIR__, "results", "corollary1.toml"), "w") do f
            println(f, "# Corollary 1\nall_ok = $all_ok")
        end
    end
    result
end

if abspath(PROGRAM_FILE) == @__FILE__
    print_header()
    corollary1_report()
end
