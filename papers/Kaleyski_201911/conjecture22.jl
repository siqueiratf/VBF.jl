# Implements Conjecture 22 — no APN function admits an APN two-point swap for n≥5.
# Paper: Kaleyski, N. (2019), "Changing APN functions at two points",
#        arXiv:1911.02608 / Des. Codes Cryptogr. 88(8):1387–1416
# Section: 4 — Conjecture 22 (main conjecture)
#
# Pseudocode:
#   For each APN function F in the catalog (n=5..8):
#   1. Normalize F to F'  with F'(0)=0, F'(1)=1 (via EA output transform)
#   2. Compute S1(F'), S2(F'), DD_{F'}(1,0)
#   3. Check: 6·DD_{F'}(1,0) ≠ S1(F')+S2(F')  (Theorem 17 condition FAILS)
#   If condition fails for ALL functions → Conjecture 22 supported for these n
# VBF API used: SBox, ddt, normalize_apn (via helpers)
# Catalog API used: load_catalog, list_functions, load_sbox

include(joinpath(@__DIR__, "helpers.jl"))
using VBFCatalog


"""
    conjecture22_report(; ns::Vector{Int} = [5,6,7,8], limit::Int = typemax(Int),
                          io::IO = stdout) -> NamedTuple

Verify Conjecture 22 for all catalog APN functions in given dimensions.
`limit` caps functions per dimension for fast testing.
Reports any counterexample found (would disprove the conjecture).
"""
function conjecture22_report(; ns::Vector{Int} = [5,6,7,8], limit::Int = typemax(Int),
                               io::IO = stdout)
    print_section("Conjecture 22 — no APN function admits an APN two-point swap (n≥5)", io)
    println(io, "  Conjecture 22: for any APN F over F_{2^n} with n≥5,")
    println(io, "  no G obtained by swapping two points of F is APN.")
    println(io, "  By Theorem 17 (after EA normalisation): check 6·DD_F(1,0) ≠ S1+S2.")
    println(io)

    db = load_catalog()
    all_fns = VBFCatalog.list_functions(db)

    total_checked = 0
    counterexamples = NamedTuple[]
    summary = NamedTuple[]

    for n in ns
        apn_n = filter(r -> r.is_apn && r.n == n, all_fns)
        isempty(apn_n) && continue
        apn_n = first(apn_n, limit)

        n_fail = 0
        n_total = 0
        for row in apn_n
            s = VBFCatalog.load_sbox(db, row.id)
            sn = normalize_apn(s)
            r = theorem17_holds(sn)
            n_total += 1
            total_checked += 1
            if r.holds
                name = something(row.canonical_name, "id$(row.id)")
                push!(counterexamples, (; n, name, s1=r.s1, s2=r.s2, dd10=r.dd10))
            else
                n_fail += 1
            end
        end
        pct = round(100 * n_fail / n_total; digits=1)
        print_kv("n=$n", "$(n_fail)/$(n_total) fail condition ($(pct)% support conjecture)", io)
        push!(summary, (; n, n_fail, n_total))
    end

    no_counterexample = isempty(counterexamples)
    println(io)
    print_check("No counterexample found: Conjecture 22 supported for n ∈ $ns", no_counterexample, io)
    print_kv("total functions checked", total_checked, io)
    if !no_counterexample
        print_kv("COUNTEREXAMPLES", length(counterexamples), io)
        for cx in counterexamples
            println(io, "    !! n=$(cx.n) $(cx.name): S1=$(cx.s1), S2=$(cx.s2), 6·DD(1,0)=$(6*cx.dd10)")
        end
    end
    print_kv("completeness",
        "bounded demo — catalog APN n=5..8 only; does not cover all APN functions", io)

    return (; summary, total_checked, counterexamples, no_counterexample)
end


if abspath(PROGRAM_FILE) == @__FILE__
    print_header()
    conjecture22_report()
end
