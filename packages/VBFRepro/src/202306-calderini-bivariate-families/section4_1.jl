# Implements Section 4.1 — N_F invariant for n=12 from Calderini, Li, Villa (2023).
# Paper: Calderini, Li, Villa (2023), "Extending two families of bivariate APN functions",
#        Finite Fields and Their Applications.
# Section: 4.1 — New APN functions from our families
#
# Pseudocode (section4_1_build):
#   1. Build F1 SBox{12} with m=6, k=1, valid alpha
#   2. Build F2 SBox{12} with m=6, valid alpha
#   3. For each: sig = nonbent_signature(F) — the Gologlu N_F EA-invariant
#      (for quadratic APN F, NB_F = {b : exists a, W_F(a,b)=0} equals the
#       nonbent-component set, so the core export computes exactly the paper's N_F)
#   4. Compare trimmed sig to Table 3 paper values:
#       F1: [n1=1365, n2=100100, n3=140664]
#       F2: [n1=1365, n2=100100, n3=144198, n4=192]
# VBF API used: nonbent_signature, differential_uniformity,
#               print_section, print_check, print_kv

include(joinpath(@__DIR__, "helpers.jl"))

# Paper Table 3 expected N_F signatures for n=12
const TABLE3_F1 = [1365, 100100, 140664]
const TABLE3_F2 = [1365, 100100, 144198, 192]

function section4_1_build(; full_search::Bool = false)
    if !full_search
        return (; skipped = true,
                  note = "Set full_search=true or run 'make section4_1' for n=12 N_F computation")
    end
    m = 6
    mod6 = primitive_polynomial(m)
    alpha = find_alpha(m, 1; modulus = mod6)
    @assert alpha !== nothing "No valid alpha for m=6, k=1"

    # Build F1 (k=1) and F2 for n=12
    F1 = family_f1_lut(m, 1, alpha; modulus = mod6)
    F2 = family_f2_lut(m, alpha; modulus = mod6)

    # Verify APN first (sanity check)
    du1 = differential_uniformity(F1)
    du2 = differential_uniformity(F2)

    # Compute N_F invariant (core EA-invariant; trailing zero counts trimmed
    # to match the paper's presentation)
    sig1 = trim_signature(nonbent_signature(F1))
    sig2 = trim_signature(nonbent_signature(F2))

    # Check against paper Table 3 values (exact)
    match_f1 = (sig1 == TABLE3_F1)
    match_f2 = (sig2 == TABLE3_F2)

    (; skipped = false, m, alpha,
       du1, du2, apn1 = du1==2, apn2 = du2==2,
       sig1, sig2, match_f1, match_f2)
end

function section4_1_report(io::IO = stdout; full_search::Bool = false)
    print_section("Section 4.1 — N_F EA-invariant for n=12 (Table 3)", io)
    println(io, "  N_F = [n_i(NB_F) : 1<=i<=n], n_i = #i-dim F_2-subspaces of NB_F")
    println(io, "  NB_F = {b : exists a, W_F(a,b)=0} (= nonbent components, F quadratic APN)")
    println(io, "  Paper Table 3 claims F1 and F2 distinct from all known families")

    r = section4_1_build(; full_search = full_search)
    if r.skipped
        println(io, "  [SKIP] $(r.note)")
        return
    end

    print_kv("m", r.m, io)
    print_kv("alpha (F1+F2)", r.alpha, io)
    print_check("F1 APN (du=2)", r.apn1, io)
    print_check("F2 APN (du=2)", r.apn2, io)
    print_kv("N_F1", r.sig1, io)
    print_kv("N_F2", r.sig2, io)
    print_kv("Table3 F1 expected", TABLE3_F1, io)
    print_kv("Table3 F2 expected", TABLE3_F2, io)
    print_check("N_F1 matches Table 3 (exact)", r.match_f1, io)
    print_check("N_F2 matches Table 3 (exact)", r.match_f2, io)
    if !r.match_f1 || !r.match_f2
        println(io, "  NOTE: mismatch may reflect different F_{2^{12}} embedding vs paper (MAGMA)")
    end
    println(io, "  completeness: exact for n=12; known-family rows recomputed in table3.jl")
end

if abspath(PROGRAM_FILE) == @__FILE__
    paper_banner()
    section4_1_report(; full_search = true)
end
