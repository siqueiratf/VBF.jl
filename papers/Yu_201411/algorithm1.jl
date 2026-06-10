include(joinpath(@__DIR__, "helpers.jl"))

# Implements Algorithm 1 from Yu-Wang-Li (2014): the recursive QAM construction
# based on Problem 1 candidate sets S_lambda.
# Paper section: IV, "New Quadratic APN Functions".
#
# VBF API used: quadratic_apn_matrix, qam_to_sbox, is_qam, search_qam_full,
#               gold_apn, rank_f2, apn_ea_mugshot, differential_uniformity,
#               algebraic_degree.

function f2_span_elements(elements)::Vector{Int}
    span = Set{Int}((0,))
    for a in elements
        ai = Int(a)
        for x in collect(span)
            push!(span, x ⊻ ai)
        end
    end
    sort!(collect(span))
end

function row_combination(A::AbstractMatrix{<:Integer}, mask::Integer)::Vector{Int}
    m, k = size(A)
    0 < mask < (1 << m) || throw(ArgumentError("row_combination: mask out of range"))
    out = zeros(Int, k)
    s = Int(mask)
    while s != 0
        r = trailing_zeros(s) + 1
        @inbounds for c = 1:k
            out[c] ⊻= A[r, c]
        end
        s &= s - 1
    end
    out
end

function problem1_candidate_set(row::AbstractVector{<:Integer}, n::Int)::Vector{Int}
    span = Set(f2_span_elements(row))
    [x for x = 0:((1 << n) - 1) if !(x in span)]
end

"""
    algorithm1_initial_sets(H) -> Dict{Int,Vector{Int}}

Algorithm 1, initialization before line 7. For the leading
`(n-1) x (n-1)` block `A`, compute each `S_lambda` as
`F_2^n \\ Span(lambda_1 A[1] + ... + lambda_(n-1) A[n-1])`.
Masks encode `lambda` in the paper's row order.
"""
function algorithm1_initial_sets(H::AbstractMatrix{<:Integer})
    n = size(H, 1)
    size(H, 2) == n || throw(ArgumentError("algorithm1_initial_sets: H must be square"))
    A = H[1:(n - 1), 1:(n - 1)]
    sets = Dict{Int,Vector{Int}}()
    for mask = 1:((1 << (n - 1)) - 1)
        sets[mask] = problem1_candidate_set(row_combination(A, mask), n)
    end
    sets
end

_copy_sets(S::Dict{Int,Vector{Int}}) = Dict(k => copy(v) for (k, v) in S)

function _intersect_sorted(a::Vector{Int}, b::Vector{Int})::Vector{Int}
    bs = Set(b)
    [x for x in a if x in bs]
end

"""
    generate_qam_algorithm1(H; limit = typemax(Int), max_nodes = typemax(Int),
                            validate = true) -> NamedTuple

Mirror Algorithm 1 (`GenerateQAM`) on a seed QAM `H`, changing the last column
and row while keeping the leading block fixed. Completed matrices are validated
with `is_qam` by default.
"""
function generate_qam_algorithm1(
    H::AbstractMatrix{<:Integer};
    limit::Integer = typemax(Int),
    max_nodes::Integer = typemax(Int),
    validate::Bool = true,
)
    n = size(H, 1)
    size(H, 2) == n || throw(ArgumentError("generate_qam_algorithm1: H must be square"))
    limit >= 0 || throw(ArgumentError("generate_qam_algorithm1: limit must be nonnegative"))
    max_nodes >= 0 || throw(ArgumentError("generate_qam_algorithm1: max_nodes must be nonnegative"))

    work = Matrix{Int}(H)
    sets0 = algorithm1_initial_sets(work)
    matrices = Matrix{Int}[]
    visited_nodes = Ref(0)
    completed = Ref(0)
    truncated = Ref(false)

    done() = length(matrices) >= limit || visited_nodes[] >= max_nodes

    function generate_qam(i::Int, Hwork::Matrix{Int}, S::Dict{Int,Vector{Int}})
        done() && return
        ei = 1 << (i - 1)
        for xi in S[ei]
            visited_nodes[] += 1
            if visited_nodes[] > max_nodes
                truncated[] = true
                return
            end

            # Algorithm 1, lines 12-13 and 18-19: keep H symmetric.
            Hwork[n, i] = xi
            Hwork[i, n] = xi

            if i == n - 1
                completed[] += 1
                if !validate || is_qam(Hwork)
                    push!(matrices, copy(Hwork))
                    length(matrices) >= limit && return
                end
            else
                # Algorithm 1, lines 20-24.
                Sprime = _copy_sets(S)
                for suffix = 1:((1 << (n - 1 - i)) - 1)
                    lambda = suffix << i
                    Sprime[lambda] = _intersect_sorted(S[lambda], S[lambda ⊻ ei])
                end
                generate_qam(i + 1, Hwork, Sprime)
                done() && return
            end
        end
    end

    limit > 0 && max_nodes > 0 && generate_qam(1, work, sets0)
    (;
        n,
        matrices,
        generated = length(matrices),
        completed = completed[],
        visited_nodes = visited_nodes[],
        truncated = truncated[] || length(matrices) >= limit || visited_nodes[] >= max_nodes,
        limit = Int(min(limit, typemax(Int))),
        max_nodes = Int(min(max_nodes, typemax(Int))),
    )
end

"""
    algorithm1_last_column_summary(n; limit = 1, max_nodes = typemax(Int)) -> NamedTuple

Run the paper's Algorithm 1 from the Gold `x^3` QAM seed and summarize the
validated matrices it emits.
"""
function algorithm1_last_column_summary(
    n::Int = 5;
    limit::Integer = 1,
    max_nodes::Integer = typemax(Int),
)
    seed = quadratic_apn_matrix(gold_apn(n, 1))
    r = generate_qam_algorithm1(seed; limit, max_nodes, validate = true)
    sboxes = [qam_to_sbox(M) for M in r.matrices]
    gold_mug = apn_ea_mugshot(gold_apn(n, 1))
    mugshots = [apn_ea_mugshot(F) for F in sboxes]
    (;
        n,
        generated = r.generated,
        completed = r.completed,
        visited_nodes = r.visited_nodes,
        truncated = r.truncated,
        all_qam = all(is_qam, r.matrices),
        all_apn = all(F -> differential_uniformity(F) == 2, sboxes),
        all_quadratic = all(F -> algebraic_degree(F) == 2, sboxes),
        distinct_classes = length(unique(mugshots)),
        gold_class_found = any(==(gold_mug), mugshots),
        limit = r.limit,
        max_nodes = r.max_nodes,
    )
end

"""
    full_qam_classification_summary(n; expected_classes, limit, max_evaluations)

Use VBF's package-level full symmetric QAM search to reproduce the small
classification counts cited in the Yu-Wang-Li discussion (`n=5 -> 1`,
`n=6 -> 13`).
"""
function full_qam_classification_summary(
    n::Int;
    expected_classes::Union{Nothing,Int} = nothing,
    limit::Integer = expected_classes === nothing ? typemax(Int) : expected_classes,
    max_evaluations::Integer = 1 << 24,
)
    reps = search_qam_full(n; limit, max_evaluations)
    gold_mug = apn_ea_mugshot(gold_apn(n, 1))
    (;
        n,
        classes = length(reps),
        expected_classes,
        expected_ok = expected_classes === nothing ? nothing : length(reps) == expected_classes,
        all_apn = all(F -> differential_uniformity(F) == 2, reps),
        all_quadratic = all(F -> algebraic_degree(F) == 2, reps),
        all_qam = all(is_qam, reps),
        gold_class_found = any(F -> apn_ea_mugshot(F) == gold_mug, reps),
        limit = Int(min(limit, typemax(Int))),
        max_evaluations = Int(min(max_evaluations, typemax(Int))),
    )
end

"""
    algorithm1_report(io; kwargs...) -> NamedTuple

Report the paper-shaped Algorithm 1 reproduction and optional full small
classification checks.
"""
function algorithm1_report(
    io::IO = stdout;
    n::Int = 5,
    limit::Integer = 1,
    max_nodes::Integer = typemax(Int),
    run_full_n5::Bool = true,
    run_full_n6::Bool = false,
    max_evaluations::Integer = 1 << 24,
    save_results::Bool = false,
)
    print_section("Algorithm 1 - GenerateQAM", io)
    alg = algorithm1_last_column_summary(n; limit, max_nodes)
    print_kv("seed", "Gold x^3 QAM over F_2^$(n)", io)
    print_kv("validated QAMs generated", alg.generated, io)
    print_kv("completed matrices examined", alg.completed, io)
    print_kv("recursive nodes visited", alg.visited_nodes, io)
    print_kv("search status", alg.truncated ? "bounded" : "complete", io)
    print_check("all generated matrices are QAMs", alg.all_qam, io)
    print_check("all generated functions are APN", alg.all_apn, io)
    print_check("all generated functions are quadratic", alg.all_quadratic, io)
    print_check("Gold x^3 class present", alg.gold_class_found, io)

    full_n5 = nothing
    full_n6 = nothing
    if run_full_n5
        print_section("Full symmetric QAM search - n = 5", io)
        full_n5 = full_qam_classification_summary(5; expected_classes = 1, limit = 1, max_evaluations)
        print_kv("CCZ/EA classes found", full_n5.classes, io)
        print_check("matches paper count for n = 5", full_n5.expected_ok, io)
        print_check("Gold x^3 class present", full_n5.gold_class_found, io)
    end

    if run_full_n6
        print_section("Full symmetric QAM search - n = 6", io)
        full_n6 = full_qam_classification_summary(6; expected_classes = 13, limit = 13, max_evaluations)
        print_kv("CCZ/EA classes found", full_n6.classes, io)
        print_check("matches paper count for n = 6", full_n6.expected_ok, io)
        print_check("all representatives are APN quadratic QAMs", full_n6.all_apn && full_n6.all_quadratic && full_n6.all_qam, io)
    else
        println(io, "\n  [NOTE] n = 6 exact run is available with run_full_n6=true.")
    end

    println(io, "  [NOTE] n = 7 and n = 8 discovery searches are intentionally bounded/out-of-scope here.")

    result = (;
        algorithm1 = alg,
        full_n5,
        full_n6,
        all_ok = alg.generated > 0 &&
            alg.all_qam &&
            alg.all_apn &&
            alg.all_quadratic &&
            alg.gold_class_found &&
            (full_n5 === nothing || full_n5.expected_ok == true) &&
            (full_n6 === nothing || full_n6.expected_ok == true),
    )

    if save_results
        path = write_results_toml(Dict("algorithm1" => result), "algorithm1.toml")
        println(io, "\n  Results written to: ", path)
    end

    result
end

if abspath(PROGRAM_FILE) == @__FILE__
    print_header()
    algorithm1_report()
end
