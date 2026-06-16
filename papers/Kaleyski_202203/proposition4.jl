# Implements verification of Proposition 4.
# Paper: Kaleyski, N. (2022), "Deciding EA-equivalence via invariants",
#        Cryptography and Communications, 2021
# Section: 2 — A family of EA-invariants, Proposition 4
#
# Proposition 4 (Eq. 2):
#   2^{m+n} · M_k^F(0, s) = Σ_{a ∈ F₂ⁿ, b ∈ F₂ⁿ} (-1)^{Tr(b·s)} · W_F(a,b)^k
#
# Pseudocode:
#   1. Compute ea_multiplicities(F, k) — direct k-tuple enumeration.
#   2. Compute sigma_multiplicities_vec(F; k) — Walsh-power formula.
#   3. Verify elementwise equality for all s ∈ F₂ⁿ.
# VBF API used: SBox, ea_multiplicities, lat, sigma_multiplicities_vec (helpers.jl)

include(joinpath(@__DIR__, "helpers.jl"))
using VBFCatalog


"""
    proposition4_walsh_vs_direct(F::SBox{N}; k, io) -> Bool

Verify Prop 4: Walsh formula == direct k-tuple enumeration for all s ∈ F₂ⁿ.
Returns true iff all 2ⁿ values agree.
"""
function proposition4_walsh_vs_direct(
    F::SBox{N,T};
    k::Int = 4,
    io::IO = stdout,
) where {N,T}
    direct = ea_multiplicities(F, k)
    walsh = sigma_multiplicities_vec(F; k = k)
    ok = (direct == walsh)
    print_check("Walsh formula == direct (k=$k, n=$N)", ok, io)
    if !ok
        ndiff = count(d != w for (d, w) in zip(direct, walsh))
        print_kv("  mismatches", ndiff, io)
    end
    return ok
end

"""
    proposition4_report(; io, n_values, k_values) -> NamedTuple

Verify Proposition 4 across multiple functions and k values.
"""
function proposition4_report(;
    io::IO = stdout,
    n_values::Vector{Int} = [5, 6],
    k_values::Vector{Int} = [4, 6],
)
    print_section("Proposition 4 — Walsh formula for M_k^F(0,s)", io)
    println(
        io,
        "  Compare direct k-tuple enumeration with Walsh-power formula (Eq. 2).",
    )

    db = load_catalog()
    all_ok = true
    for n in n_values
        rows = filter(r -> r.is_quadratic, list_functions(db; is_apn = true, n = n))
        funcs = [(r.canonical_name, load_sbox(db, r.canonical_name)) for r in rows[1:min(3, end)]]
        for (name, F) in funcs
            for k in k_values
                ok = proposition4_walsh_vs_direct(F; k, io)
                all_ok &= ok
            end
        end
    end
    return (; all_ok, n_values, k_values)
end

if abspath(PROGRAM_FILE) == @__FILE__
    include(joinpath(@__DIR__, "helpers.jl"))
    print_header()
    proposition4_report()
end
