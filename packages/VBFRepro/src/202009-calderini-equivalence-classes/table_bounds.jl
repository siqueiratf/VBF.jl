# Tables 2–4 — bounded simplex-code counts using VBF's native subspace enumerator.
# The count is an upper bound on EA classes; it is not an equivalence classification.
include(joinpath(@__DIR__, "helpers.jl"))

const TABLE_BOUND_POWER_ROWS = [
    (table=2, row=1, n=7, exponent=3, published_bound=256),
    (table=2, row=2, n=7, exponent=5, published_bound=256),
    (table=2, row=3, n=7, exponent=9, published_bound=256),
    (table=2, row=4, n=7, exponent=13, published_bound=2),
    (table=2, row=5, n=7, exponent=57, published_bound=2),
    (table=2, row=6, n=7, exponent=63, published_bound=2),
    (table=3, row=1, n=8, exponent=3, published_bound=256),
    (table=3, row=2, n=8, exponent=9, published_bound=256),
    (table=3, row=3, n=8, exponent=57, published_bound=1),
    (table=3, row=24, n=8, exponent=127, published_bound=2),
    (table=4, row=1, n=9, exponent=13, published_bound=2),
    (table=4, row=2, n=9, exponent=19, published_bound=2),
    (table=4, row=3, n=9, exponent=241, published_bound=2),
    (table=4, row=4, n=9, exponent=255, published_bound=2),
]

"Exact upper bound only when the Walsh-zero subspace search is exhausted."
function simplex_bound_evidence(F::SBox{N}; max_nodes::Int=100_000,
        max_subspaces::Int=10_000, timeout_seconds::Real=10,
        algorithm::Symbol=:optimized) where N
    outcome = extract_linear_subspaces_bounded(walsh_zeroes(F), N;
        max_bits=2N, max_nodes, max_subspaces, timeout_seconds, algorithm)
    complete = outcome isa Exhausted
    (; outcome, complete, upper_bound=complete ? length(search_solutions(outcome)) : nothing,
        partial_subspace_count=length(search_solutions(outcome)))
end

"""
    table_bounds_report(; limit=1, tables=[2,3,4], max_nodes=100_000, timeout_seconds=10)

Bounded validation of the unambiguously specified power-function rows of Tables
2–4. Other polynomial rows require explicit source/field reconciliation and are
not counted as reproduced. A timed-out enumeration supplies no upper bound.
"""
function table_bounds_report(; limit::Int=1, tables=[2,3,4],
        max_nodes::Int=100_000, max_subspaces::Int=10_000,
        timeout_seconds::Real=10, io::IO=stdout)
    limit >= 0 || throw(ArgumentError("limit must be nonnegative"))
    selected = first(filter(r -> r.table in tables, TABLE_BOUND_POWER_ROWS), limit)
    records = NamedTuple[]
    for row in selected
        evidence = simplex_bound_evidence(power_sbox(row.n, row.exponent);
            max_nodes, max_subspaces, timeout_seconds)
        matches = evidence.complete ? evidence.upper_bound == row.published_bound : nothing
        push!(records, (; row..., evidence, matches))
        print_kv(io, "Table $(row.table) row $(row.row)",
            evidence.complete ? "exact simplex count $(evidence.upper_bound), published $(row.published_bound)" :
                "INCONCLUSIVE; $(evidence.partial_subspace_count) subspaces found before budget")
    end
    print_kv(io, "scope", "selected power-function rows only; subspaces are not EA classes")
    (; records, selected_rows=length(records), full_tables_reproduced=false)
end

if abspath(PROGRAM_FILE) == @__FILE__
    table_bounds_report()
end
