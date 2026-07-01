# Implements Section 4.1 — N_F invariant for n=12 from Calderini, Li, Villa (2023).
# Paper: Calderini, Li, Villa (2023), "Extending two families of bivariate APN functions",
#        Finite Fields and Their Applications.
# Section: 4.1 — New APN functions from our families
#
# Pseudocode (section4_1_build):
#   1. Build F1 SBox{12} with m=6, k=1, valid alpha
#   2. Build F2 SBox{12} with m=6, valid alpha
#   3. For each: S(F) = walsh_zeroes b-projection
#   4. Compute sig = subspace_count_signature(S, 12)
#   5. Compare sig to Table 3 paper values:
#       F1: [n1=1365, n2=100100, n3=140664]
#       F2: [n1=1365, n2=100100, n3=144198, n4=192]
# VBF API used: walsh_zeroes, subspace_count_signature, differential_uniformity,
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

    # Compute N_F invariant
    S1   = s_of_f_bv(F1)
    sig1 = subspace_count_signature(S1, 2 * m)

    S2   = s_of_f_bv(F2)
    sig2 = subspace_count_signature(S2, 2 * m)

    # Check against paper Table 3 values
    match_f1 = (sig1[1:min(end,length(TABLE3_F1))] == TABLE3_F1[1:min(length(sig1),end)])
    match_f2 = (sig2[1:min(end,length(TABLE3_F2))] == TABLE3_F2[1:min(length(sig2),end)])

    (; skipped = false, m, alpha,
       du1, du2, apn1 = du1==2, apn2 = du2==2,
       sig1, sig2, S1_size = length(S1), S2_size = length(S2),
       match_f1, match_f2)
end

function section4_1_report(io::IO = stdout; full_search::Bool = false)
    print_section("Section 4.1 — N_F EA-invariant for n=12 (Table 3)", io)
    println(io, "  N_F = [n_i(NB_F) : 1<=i<=n], n_i = #i-dim F_2-subspaces of NB_F")
    println(io, "  NB_F = {b : exists a, W_F(a,b)=0}")
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
    print_kv("|S(F1)|", r.S1_size, io)
    print_kv("|S(F2)|", r.S2_size, io)
    print_kv("N_F1", r.sig1, io)
    print_kv("N_F2", r.sig2, io)
    print_kv("Table3 F1 expected", TABLE3_F1, io)
    print_kv("Table3 F2 expected", TABLE3_F2, io)
    print_check("N_F1 matches Table 3 (leading terms)", r.match_f1, io)
    print_check("N_F2 matches Table 3 (leading terms)", r.match_f2, io)
    if !r.match_f1 || !r.match_f2
        println(io, "  NOTE: mismatch may reflect different F_{2^{12}} embedding vs paper (MAGMA)")
    end
    println(io, "  completeness: exact for n=12; Table 3 comparison vs paper's MAGMA values")
end

if abspath(PROGRAM_FILE) == @__FILE__
    paper_banner()
    section4_1_report(; full_search = true)
end
