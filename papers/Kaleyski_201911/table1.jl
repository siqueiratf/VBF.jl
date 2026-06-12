# Implements Table 1 — S1, S2 for Edel-Pott switching-class APN functions n=5..8.
# Paper: Kaleyski, N. (2019), "Changing APN functions at two points",
#        arXiv:1911.02608 / Des. Codes Cryptogr. 88(8):1387–1416
# Section: 4 — Table 1 (S1/S2 values for known APN switching classes)
#
# Pseudocode:
#   For each APN function F from the known switching classes (n=5..8):
#   1. Normalize: apply EA transform to get F(0)=0, F(1)=1
#   2. Compute S1(F) = Σ_y DD_F(y, F(y)⊕1) via DDT
#   3. Compute S2(F) = Σ_y DD_F(y⊕1, F(y)) via DDT
#   4. Check: S1+S2 ≠ 6·DD_F(1,0)  (i.e., Theorem 17 condition FAILS)
#   5. Report S1, S2, DD_F(1,0) for each function
#
# Note: This reproduction uses all VBFCatalog APN functions for n=5..8 —
# a superset of the 47 Edel-Pott switching-class representatives in the paper.
# The original paper references Edel-Pott (2009) Tables 3,5,7,9; exact
# numerical S1/S2 values will differ because we use different representatives,
# but the key claim (S1+S2 ≠ 6·DD_F(1,0)) is verified across all of them.
# VBF API used: SBox, ddt, load_apn_function, apn_catalog_names
# Catalog API used: load_catalog, list_functions, load_sbox, corpus_function, corpus_length

include(joinpath(@__DIR__, "helpers.jl"))
using VBFCatalog


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
    table1_report(; ns::Vector{Int} = [5,6,7,8], limit::Int = typemax(Int), io::IO = stdout) -> NamedTuple

Reproduce the structure of Table 1: S1, S2 for all catalog APN functions, n ∈ ns.
`limit` caps the number of functions processed per dimension (for fast tests).
"""
function table1_report(; ns::Vector{Int} = [5,6,7,8], limit::Int = typemax(Int), io::IO = stdout)
    print_section("Table 1 — S1, S2 for known APN functions (Theorem 17 check)", io)
    println(io, "  Note: uses all VBFCatalog APN functions for n=5..8 (superset of paper's 47 reps).")
    println(io, "  Key check: S1+S2 ≠ 6·DD_F(1,0) for all functions (Theorem 17 condition fails).")
    println(io)

    all_rows = NamedTuple[]
    all_ok = true

    for n in ns
        fns = load_catalog_apn_for_n(n)
        isempty(fns) && continue
        fns = first(fns, limit)
        count_ok = 0
        count_total = 0

        println(io, "  n=$n ($(length(fns)) functions from catalog):")
        println(io, "    $(rpad("name",20))  $(lpad("S1",8))  $(lpad("S2",8))  $(lpad("6·DD(1,0)",10))  cond_fails")
        println(io, "    " * "─"^60)

        for (name, s) in fns
            sn = normalize_apn(s)
            r = theorem17_holds(sn)
            lhs = 6 * r.dd10
            fails = !r.holds
            count_ok += fails ? 1 : 0
            count_total += 1
            status = fails ? "✓ (no swap)" : "✗ SWAP FOUND"
            println(io, "    $(rpad(name,20))  $(lpad(r.s1,8))  $(lpad(r.s2,8))  " *
                        "$(lpad(lhs,10))  $status")
            push!(all_rows, (; n, name, s1=r.s1, s2=r.s2, dd10=r.dd10, condition_fails=fails))
            all_ok &= fails
        end
        println(io, "    → $(count_ok)/$(count_total) fail Theorem 17 condition (no APN swap)")
    end

    println(io)
    print_check("Theorem 17 condition FAILS for ALL catalog APN n=5..8", all_ok, io)
    print_kv("completeness",
        "bounded demo — catalog APN functions only (not all APN classes)", io)

    return (; all_rows, all_ok)
end


if abspath(PROGRAM_FILE) == @__FILE__
    print_header()
    table1_report()
end
