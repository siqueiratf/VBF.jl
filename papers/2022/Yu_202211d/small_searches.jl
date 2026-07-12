include(joinpath(@__DIR__, "helpers.jl"))
using VBF

# ── Full QAM search over all symmetric derivative matrices for n = 4.
# The space of quadratic APN functions over GF(2^4) is a single CCZ-class
# (the Gold x^3 class). search_qam_full recovers this exhaustively at n = 4.
function small_search_full(
    n::Int = 4;
    limit::Int = typemax(Int),
    max_evaluations::Int = 1 << 24,
)
    gold_ref = gold_apn(n, 1)
    gold_mug = apn_ea_mugshot(gold_ref)

    results = search_qam_full(n; limit, max_evaluations)
    n_classes = length(results)
    # exhaustive when search terminated naturally (not by budget or limit)
    exhaustive = n_classes < limit && max_evaluations > 1 << 24 - 1

    gold_found = any(apn_ea_mugshot(s) == gold_mug for s in results)
    (n_classes = n_classes, gold_found = gold_found, exhaustive = exhaustive,
     limit = limit, max_evaluations = max_evaluations)
end

# ── Cyclic QAM search for GF(2^m)-coefficient functions over GF(2^n).
# For (n=4, m=2): sweeps the GF(4)-cyclic subspace; the Gold class is present.
# For (n=5, m=1): sweeps the GF(2)-cyclic subspace.
function small_search_cyclic(
    n::Int,
    m::Int;
    limit::Int = typemax(Int),
    max_evaluations::Int = 1 << 22,
)
    gold_ref = gold_apn(n, 1)
    gold_mug = apn_ea_mugshot(gold_ref)

    results = search_qam(n, m; limit, max_evaluations)
    n_classes = length(results)
    gold_found = any(apn_ea_mugshot(s) == gold_mug for s in results)
    (n = n, m = m, n_classes = n_classes, gold_found = gold_found,
     limit = limit, max_evaluations = max_evaluations)
end

function small_searches_report(;
    limit::Int = typemax(Int),
    max_evaluations::Int = 1 << 22,
    save_results::Bool = false,
    io::IO = stdout,
)
    print_section("Small-Dimensional QAM Searches", io)

    # Full search at n = 4 (should be exhaustive with default budget)
    r4 = small_search_full(4; limit, max_evaluations)
    print_kv("n = 4 full search: CCZ-classes found", r4.n_classes, io)
    print_check("n = 4: Gold x³ class found", r4.gold_found, io)
    print_kv("      (result is exhaustive with no limit)", r4.exhaustive, io)

    # Cyclic search at (n=4, m=2)
    c42 = small_search_cyclic(4, 2; limit, max_evaluations)
    print_kv("n=4 m=2 cyclic: CCZ-classes found", c42.n_classes, io)
    print_check("n=4 m=2 cyclic: Gold x³ class found", c42.gold_found, io)

    # Cyclic search at (n=5, m=1)
    c51 = small_search_cyclic(5, 1; limit, max_evaluations)
    print_kv("n=5 m=1 cyclic: CCZ-classes found", c51.n_classes, io)
    print_check("n=5 m=1 cyclic: Gold x³ class found", c51.gold_found, io)

    data = (
        n4_full = (classes = r4.n_classes, gold = r4.gold_found, exhaustive = r4.exhaustive),
        n4m2_cyclic = (classes = c42.n_classes, gold = c42.gold_found),
        n5m1_cyclic = (classes = c51.n_classes, gold = c51.gold_found),
    )

    if save_results
        path = write_results_toml(Dict("small_searches" => data), "small_searches.toml")
        println(io, "\n  Results written to: ", path)
    end

    data
end

if abspath(PROGRAM_FILE) == @__FILE__
    print_header()
    small_searches_report()
end
