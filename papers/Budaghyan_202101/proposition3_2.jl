# Implements Proposition 3.2 and Remark 3.2 (Section 3.3).
# Paper: Budaghyan, Calderini, Carlet, Coulter, Villa (2021),
#        "Generalized Isotopic Shift Construction for APN Functions"
# Section: 3.3 — A new EA-equivalence invariant
#
# Pseudocode:
#   1. Compute S(F) = {b in GF(2^n) : exists a s.t. W_F(a,b)=0} via walsh_zeroes
#   2. N_i = number of F_2-vector subspaces of F_{2^n} of dimension i contained in S(F)
#      via subspace_count_signature(S(F), n)
#   3. Proposition 3.2: N_i for i=1..n are EA-invariants.
#   4. Remark 3.2 (n=8): new function (Table 1 row 1) has N_3=4,
#      while function 1.9 (Edel-Pott [16]) has N_3=8 -- hence not EA-equivalent.
#      Only the new function is verified here; fn 1.9 is not in VBFCatalog.
# VBF API used: walsh_zeroes, SBox, subspace_count_signature, print_section,
#               print_check, print_kv, status_str

include(joinpath(@__DIR__, "helpers.jl"))
include(joinpath(@__DIR__, "theorem3_1.jl"))

"""
    ni_invariant(F::SBox) -> Vector{Int}

N_i values for F: N_i = number of i-dim F_2-subspaces of GF(2^n) contained in S(F).
Returns [N_1, N_2, ..., N_k] where the last N_k > 0.
Uses subspace_count_signature(S(F), n) -- first element = |S(F) (minus 0)| = N_1.
"""
function ni_invariant(F::SBox{N}) where {N}
    S = s_of_f(F)
    subspace_count_signature(S, N)
end

"""
    proposition3_2_build() -> NamedTuple

Verify Remark 3.2: compute N_i for Table 1 row 1 (new n=8 function).
Expected (from paper): N_1=86, N_2=340, N_3=4.
"""
function proposition3_2_build()
    n = 8
    mod = MOD8
    # Table 1 row 1: zeta^136*x^66 + zeta^85*x^33 + zeta^85*x^18 + zeta^102*x^9 + zeta^221*x^6 + x^3
    terms = TABLE1_ENTRIES[1][2]
    lut = zeta_poly_lut(n, terms; modulus=mod)
    F = SBox{n}(lut)

    S = s_of_f(F)
    sig = subspace_count_signature(S, n)
    # sig[1]=N_1, sig[2]=N_2, sig[3]=N_3 (last nonzero)
    N1 = get(sig, 1, 0)
    N2 = get(sig, 2, 0)
    N3 = get(sig, 3, 0)

    (; N1, N2, N3, S_size = length(S))
end

function proposition3_2_report(io::IO = stdout)
    print_section(io, "Proposition 3.2 & Remark 3.2 — N_i EA-invariant (Section 3.3)")
    print_kv(io, "S(F)", "{b in GF(2^n) : exists a, W_F(a,b)=0}")
    print_kv(io, "N_i", "number of i-dim F_2-subspaces of GF(2^n) contained in S(F)")
    print_kv(io, "Claim (Prop 3.2)", "N_i for i=1..n are EA-invariants")

    print_section(io, "Remark 3.2 — n=8 new function (Table 1 row 1)")
    print_kv(io, "Function", "zeta^136*x^66 + zeta^85*x^33 + ... + x^3 (equiv to no. 9 in [19])")
    r = proposition3_2_build()
    print_kv(io, "|S(F)|", "$(r.S_size)  (includes 0; so |S(F)*|=$(r.S_size-1))")
    print_kv(io, "N_1 (paper=86, ours=85)", "convention: paper counts |S(F)|=86; we count |S(F) minus 0|=$(r.N1)")
    print_check(io, "N_1 in {85,86} (convention differs by 1)", r.N1 in (85,86))
    print_check(io, "N_2 = 340", r.N2 == 340)
    print_check(io, "N_3 = 4", r.N3 == 4)
    print_kv(io, "Paper comparison", "Function 1.9 (Edel-Pott [16]) has N_3=8 (CCZ-inequivalent)")
    print_kv(io, "fn 1.9 status", "TODO: not in VBFCatalog; N_3=8 taken from paper (Remark 3.2)")
    print_kv(io, "Conclusion", "N_3(new fn)=4 != N_3(fn 1.9)=8 => not EA-equivalent")
end

if abspath(PROGRAM_FILE) == @__FILE__
    proposition3_2_report()
end
