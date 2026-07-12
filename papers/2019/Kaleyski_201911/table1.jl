# Implements Table 1 — S1, S2 for Edel-Pott switching-class APN functions n=5..8.
# Paper: Kaleyski, N. (2019), "Changing APN functions at two points",
#        arXiv:1911.02608 / Des. Codes Cryptogr. 88(8):1387–1416
# Section: 4 — Table 1 (S1/S2 values for known APN switching classes)
#
# Pseudocode:
#   For each APN function F from the known switching classes (n=5..8):
#   1. Normalize (Observation 7) at a pair (u₁,u₂) with F(u₁) ≠ F(u₂): F'(0)=0, F'(1)=1
#   2. Compute S1(F') = Σ_y Δ_F'(y, F'(y)⊕1) via DDT
#   3. Compute S2(F') = Σ_y Δ_F'(y⊕1, F'(y)) via DDT
#   4. Check: S1+S2 ≠ 6·Δ_F'(1,0)  (i.e., Theorem 17 condition FAILS ⇒ no APN swap)
#   5. Report S1, S2, Δ_F'(1,0) for each function
#
# Scope caveat (README R4): this is NOT a row-by-row reproduction of the paper's
# Table 1. The paper tabulates Edel-Pott's specific polynomial representatives [10];
# we use the VBFCatalog APN functions for n=5..8, a different (larger) set. S1/S2 are
# not EA-invariant — they depend on the chosen normalised representative — so the
# numbers are not comparable row-by-row. What *is* reproduced is the structural claim
# the paper draws from Table 1 (Observation 18): S1+S2 > 12 ≥ 6·Δ_F(1,0), hence the
# Theorem 17 condition fails and no two-point swap of these functions is APN.
# Reproducing the printed table needs the Edel-Pott LUTs plus a normalisation
# convention the paper never states.
# VBF API used: SBox, ddt
# Catalog API used: load_catalog, list_functions, load_sbox

include(joinpath(@__DIR__, "helpers.jl"))
using VBFCatalog
using Random


"""
    load_catalog_apn_for_n(n::Int) -> Vector{Tuple{String,SBox}}

Load all first-class APN functions of dimension `n` from the catalog.
Returns (name, sbox) pairs.
"""
function load_catalog_apn_for_n(n::Int)
    db = load_catalog()
    all_fns = VBFCatalog.list_functions(db)
    apn_n = filter(r -> r.is_apn && r.n == n, all_fns)
    result = Tuple{String,SBox}[]
    for row in apn_n
        name = something(row.canonical_name, "id$(row.id)")
        s = VBFCatalog.load_sbox(db, row.id)
        push!(result, (name, s))
    end
    return result
end


"""
    table1_report(; ns::Vector{Int} = [5,6,7,8], limit::Int = typemax(Int),
                    rep_samples::Int = 8, seed::Int = 20191102,
                    io::IO = stdout) -> NamedTuple

S1, S2 and the Theorem 17 check for all catalog APN functions, n ∈ ns — the
structural content of the paper's Table 1 (see the scope caveat at the top of
this file).

Every function is covered: one with `F(0) = F(1)` is normalised at its first
genuine pair (Observation 7) instead of being skipped.

`rep_samples` additionally normalises each function at up to that many *other*
genuine pairs and counts the representatives with S₁ ≠ S₂ — the asymmetry the
paper's Table 1 exhibits and remarks on ("the two values may differ in the
general case"). S₁/S₂ are not EA-invariant, so this asymmetry only becomes
reachable once Observation 7's input map A₂ is applied (README R4).
"""
function table1_report(; ns::Vector{Int} = [5, 6, 7, 8], limit::Int = typemax(Int),
                         rep_samples::Int = 8, seed::Int = 20191102,
                         io::IO = stdout)
    print_section("Table 1 — S1, S2 for known APN functions (Theorem 17 check)", io)
    println(io, "  Note: catalog APN functions n=5..8, not the paper's Edel-Pott reps —")
    println(io, "  S1/S2 are representative-dependent, so values are not row-comparable.")
    println(io, "  Key check: S1+S2 ≠ 6·Δ_F(1,0) for all functions (Theorem 17 fails).")
    println(io)

    all_rows = NamedTuple[]
    all_ok = true
    n_reps = 0        # normalised representatives scanned (Observation 7)
    n_asym = 0        # of those, how many have S1 ≠ S2

    for n in ns
        fns = load_catalog_apn_for_n(n)
        isempty(fns) && continue
        fns = first(fns, limit)
        count_ok = 0
        count_total = 0
        rng = MersenneTwister(seed + n)

        println(io, "  n=$n ($(length(fns)) functions from catalog):")
        println(io, "    $(rpad("name",20))  $(lpad("S1",8))  $(lpad("S2",8))  $(lpad("6·Δ(1,0)",10))  cond_fails")
        println(io, "    " * "─"^62)

        for (name, s) in fns
            # Observation 7: normalise at a pair with F(u₁) ≠ F(u₂). For most
            # functions that is (0,1); for those with F(0)=F(1) it is the first
            # genuine pair. Nothing is skipped (README R3).
            u1, u2 = first_genuine_pair(s)
            sn = normalize_apn(s, u1, u2)
            r = theorem17_holds(sn)
            lhs = 6 * r.dd10
            fails = !r.holds
            count_ok += fails ? 1 : 0
            count_total += 1
            pair_note = (u1, u2) == (0, 1) ? "" : "  [normalised at ($u1,$u2)]"
            status = fails ? "✓ (no swap)" : "✗ SWAP FOUND"
            println(io, "    $(rpad(name,20))  $(lpad(r.s1,8))  $(lpad(r.s2,8))  " *
                        "$(lpad(lhs,10))  $status$pair_note")
            push!(all_rows, (; n, name, u1, u2, s1 = r.s1, s2 = r.s2, dd10 = r.dd10,
                             condition_fails = fails))
            all_ok &= fails

            # R4: look for the S1 ≠ S2 asymmetry across other representatives.
            n_reps += 1
            r.s1 != r.s2 && (n_asym += 1)
            pairs = genuine_pairs(s)
            k = min(rep_samples, length(pairs))
            for idx in randperm(rng, length(pairs))[1:k]
                (v1, v2) = pairs[idx]
                rr = theorem17_holds(normalize_apn(s, v1, v2))
                n_reps += 1
                rr.s1 != rr.s2 && (n_asym += 1)
                all_ok &= !rr.holds
            end
        end
        println(io, "    → $(count_ok)/$(count_total) fail Theorem 17 condition (no APN swap)")
    end

    pct = n_reps == 0 ? 0.0 : round(100 * n_asym / n_reps; digits = 1)
    println(io)
    print_check("Theorem 17 condition FAILS for ALL catalog APN n=5..8", all_ok, io)
    print_kv("normalised representatives scanned", n_reps, io)
    print_kv("of those with S1 ≠ S2 (Table 1's asymmetry)", "$(n_asym) ($(pct)%)", io)
    print_kv("completeness",
        "bounded demo — catalog APN functions only (not the paper's Edel-Pott reps)", io)

    return (; all_rows, all_ok, n_reps, n_asym)
end


if abspath(PROGRAM_FILE) == @__FILE__
    print_header()
    table1_report()
end
