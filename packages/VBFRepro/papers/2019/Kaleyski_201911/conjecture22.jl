# Implements Conjecture 22 — no APN function admits an APN two-point swap for n≥5.
# Paper: Kaleyski, N. (2019), "Changing APN functions at two points",
#        arXiv:1911.02608 / Des. Codes Cryptogr. 88(8):1387–1416
# Section: 4 — Conjecture 22 (main conjecture)
#
# Pseudocode:
#   For each APN function F in the catalog (n=5..8):
#   For each pair (u₁,u₂) with F(u₁) ≠ F(u₂)  [Observation 7's precondition]:
#   1. Normalize: F' = A₁ ∘ F ∘ A₂ + A  with F'(0)=0, F'(1)=1  (Observation 7),
#      so that swap(F', 0, 1) is EA-equivalent to swap(F, u₁, u₂)
#   2. Compute S1(F'), S2(F'), Δ_{F'}(1,0)
#   3. Theorem 17: swap(F, u₁, u₂) is APN  ⟺  6·Δ_{F'}(1,0) = S1(F')+S2(F')
#   If the condition fails for ALL pairs of ALL F → Conjecture 22 supported.
#
# Exhaustive over all pairs for n ≤ exhaustive_max_n (default 6); sampled above
# that (all-pairs at n=7 is ≈3.9M swaps — too slow for a test suite).
# VBF API used: SBox, ddt, differential_uniformity
# Catalog API used: load_catalog, list_functions, load_sbox

include(joinpath(@__DIR__, "helpers.jl"))
using VBFCatalog
using Random


"""
    swap_pairs_for(s::SBox, n::Int; exhaustive::Bool, pair_samples::Int, rng) -> Vector{Tuple{Int,Int}}

Pairs `(u₁,u₂)` at which to test the two-point swap of `s`. Exhaustive mode
returns every pair with `F(u₁) ≠ F(u₂)`; sampled mode returns `(0,1)` (when it is
genuine) plus `pair_samples` further pairs drawn without replacement.
"""
function swap_pairs_for(s::SBox, n::Int; exhaustive::Bool, pair_samples::Int, rng)
    pairs = genuine_pairs(s)
    exhaustive && return pairs
    k = min(pair_samples, length(pairs))
    idx = randperm(rng, length(pairs))[1:k]
    sel = pairs[idx]
    # keep the paper's canonical (0,1) swap in the sample whenever it is genuine
    if !is_swap_degenerate(s, 0, 1) && (0, 1) ∉ sel
        pushfirst!(sel, (0, 1))
    end
    return sel
end


"""
    conjecture22_report(; ns::Vector{Int} = [5,6,7,8], limit::Int = typemax(Int),
                          exhaustive_max_n::Int = 6, pair_samples::Int = 16,
                          seed::Int = 20191102, full_search=false,
                          max_evaluations=typemax(Int), timeout_seconds=Inf, io=stdout) -> NamedTuple

Test selected catalog APN functions in the given dimensions. All pairs are
selected below `exhaustive_max_n`, or with `full_search=true`; other runs sample
pairs. `limit` caps functions per dimension. Returned outcomes distinguish
exhaustion of that explicit catalog region from sampling and budget stops.

Functions with `F(0) = F(1)` are **not** skipped: `F(0)=F(1)` only makes the
`(0,1)` swap a no-op, and Observation 7 lets us normalise at any other pair.

`no_counterexample` ignores n < 5 (the conjecture is stated for n ≥ 5), so passing
`ns=[4]` gives a control that is *expected* to find APN swaps (Observation 27).
"""
function conjecture22_report(; ns::Vector{Int} = [5, 6, 7, 8],
                               limit::Int = typemax(Int),
                               exhaustive_max_n::Int = 6,
                               pair_samples::Int = 16,
                               seed::Int = 20191102,
                               full_search::Bool = false,
                               max_evaluations::Int = typemax(Int),
                               timeout_seconds::Real = Inf,
                               io::IO = stdout)
    print_section("Conjecture 22 — no APN function admits an APN two-point swap (n≥5)", io)
    println(io, "  Conjecture 22: for any APN F over F_{2^n} with n≥5,")
    println(io, "  no G obtained by swapping two points of F is APN.")
    println(io, "  Theorem 17 + Observation 7: for each pair (u₁,u₂) with F(u₁)≠F(u₂),")
    println(io, "  normalise F at (u₁,u₂) and check 6·Δ_F'(1,0) ≠ S1(F')+S2(F').")
    println(io)

    limit >= 0 && pair_samples >= 0 && max_evaluations >= 0 ||
        throw(ArgumentError("limits must be nonnegative"))
    timeout_seconds >= 0 || throw(ArgumentError("timeout_seconds must be nonnegative"))
    started = time_ns()
    elapsed() = (time_ns() - started) / 1e9
    stopped = nothing
    outcomes = SearchOutcome[]
    db = load_catalog()
    try
        all_fns = VBFCatalog.list_functions(db)

        total_checked = 0     # functions
        total_swaps = 0       # (function, pair) combinations
        counterexamples = NamedTuple[]
        summary = NamedTuple[]

        for n in ns
            apn_n = filter(r -> r.is_apn && r.n == n, all_fns)
            isempty(apn_n) && continue
            available_functions = length(apn_n)
            apn_n = first(apn_n, limit)
            exhaustive = full_search || n <= exhaustive_max_n
            region = SearchRegion(:two_point_swaps, "catalog-n$n";
                params = Dict{String,Any}("n" => n, "function_ids" => [row.id for row in apn_n],
                    "available_functions" => available_functions, "seed" => seed,
                    "scope" => "all genuine pairs of these catalog members; not all APN functions"))
            rng = MersenneTwister(seed + n)

            n_swaps = 0
            n_apn_swaps = 0
            dimension_counterexamples = NamedTuple[]
            functions_started = 0
            for row in apn_n
                s = VBFCatalog.load_sbox(db, row.id)
                pairs = swap_pairs_for(s, n; exhaustive, pair_samples, rng)
                checked_this_function = false
                for (u1, u2) in pairs
                    if total_swaps >= max_evaluations || elapsed() >= timeout_seconds
                        stopped = StopPoint(total_swaps >= max_evaluations ? :nodes : :time,
                            "Stopped before evaluating another (function, pair)")
                        break
                    end
                    if !checked_this_function
                        total_checked += 1
                        functions_started += 1
                        checked_this_function = true
                    end
                    sn = normalize_apn(s, u1, u2)
                    r = theorem17_holds(sn)
                    n_swaps += 1
                    total_swaps += 1
                    if r.holds
                        n_apn_swaps += 1
                        name = something(row.canonical_name, "id$(row.id)")
                        example = (; n, name, u1, u2, s1 = r.s1, s2 = r.s2, dd10 = r.dd10)
                        push!(counterexamples, example)
                        push!(dimension_counterexamples, example)
                    end
                end
                stopped === nothing || break
            end
            completed = exhaustive && stopped === nothing
            outcome = if completed
                Exhausted(region, dimension_counterexamples; nodes_visited = n_swaps, elapsed_seconds = elapsed())
            else
                reason = stopped === nothing ? StopPoint(:external, "Pairs were sampled; unchecked pairs remain") : stopped
                BudgetHit(reason, region, dimension_counterexamples; nodes_visited = n_swaps, elapsed_seconds = elapsed())
            end
            push!(outcomes, outcome)
            mode = exhaustive ? "all pairs" : "$(pair_samples)+1 sampled pairs/function"
            print_kv("n=$n",
                "$(length(apn_n)) functions, $(n_swaps) genuine swaps ($mode) → " *
                "$(n_apn_swaps) APN swaps", io)
            push!(summary, (; n, n_functions = functions_started, available_functions,
                selected_function_ids = [row.id for row in apn_n], n_swaps, n_apn_swaps,
                exhaustive = completed, outcome))
            stopped === nothing || break
        end

        no_counterexample = !any(cx -> cx.n >= 5, counterexamples)
        println(io)
        print_check("No counterexample among evaluated swaps (not a proof of Conjecture 22)",
                    no_counterexample, io)
        print_kv("total functions checked", total_checked, io)
        print_kv("total swaps checked", total_swaps, io)
        if !isempty(counterexamples)
            n_lt5 = count(cx -> cx.n < 5, counterexamples)
            n_lt5 > 0 && print_kv("APN swaps at n<5 (expected — Observation 27)", n_lt5, io)
            for cx in counterexamples
                cx.n < 5 && continue
                println(io, "    !! n=$(cx.n) $(cx.name) at (u₁,u₂)=($(cx.u1),$(cx.u2)): " *
                            "S1=$(cx.s1), S2=$(cx.s2), 6·Δ(1,0)=$(6*cx.dd10)")
            end
        end
        print_kv("completeness",
            "per-dimension outcomes certify only explicitly selected catalog members; " *
            "samples and interrupted runs leave unchecked pairs; no global APN classification", io)

        return (; summary, total_checked, total_swaps, counterexamples, no_counterexample,
            outcomes, stopped, elapsed_seconds = elapsed())
    finally
        close(db)
    end
end


if abspath(PROGRAM_FILE) == @__FILE__
    print_header()
    conjecture22_report()
end
