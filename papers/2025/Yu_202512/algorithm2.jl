# Implements Algorithm 2 — Generate APN functions on GF(2^n) with F₂ coefficients
# Paper: Yu, Li, Ichanska, Kaleyski (2025)
# Section: 4.1 Algorithm, Algorithm 2
#
# Pseudocode (Algorithm 2, generalised to dimension n):
#   num_vars = floor(n/2)                     # free variables = diagonal offsets 1..num_vars
#   for a ∈ Fₙ:                               # first variable: one per Frobenius orbit of size n
#     if 2×2 upper-left submatrix is proper:
#       for b ∈ GF(2^n)*:                     # second variable
#         if 3×3 upper-left submatrix is proper:
#           … (recurse for remaining variables)
#           if IsQAM(n, H): yield H
#
# free variable domains:
#   diagonal d=1 (first): Fₙ = {min of each Frobenius orbit of size n}
#   diagonal d=2..floor(n/2)-1 (if n odd): all of GF(2^n)*
#   diagonal d=floor(n/2) (if n even, self-paired): GF(2^{n/2})*
#
# VBF API used: conway_polynomial, gf_pow, rank_f2, is_qam

include(joinpath(@__DIR__, "algorithm1.jl"))

# Fₙ: one representative per Frobenius orbit of size exactly n in GF(2^n)*.
# Elements in proper subfields GF(2^d), d|n, d<n have orbit size d < n and are excluded.
function fn_set(n::Int; modulus::Int = conway_polynomial(n))
    result = Int[]
    assigned = Set{Int}()
    for v in 1:(1 << n) - 1
        v in assigned && continue
        orbit = Int[]
        cur = v
        for _ in 1:n
            push!(orbit, cur)
            cur = gf_pow(cur, 2, n; modulus = modulus)
        end
        uorb = unique(orbit)
        if length(uorb) == n            # orbit size exactly n → outside all proper subfields
            push!(result, minimum(uorb))
        end
        union!(assigned, uorb)
    end
    sort!(result)
end

# Nonzero elements of GF(2^gcd(d,n)) ⊆ GF(2^n) (subfield for self-paired diagonal d=n/2).
function subfield_nonzero(d::Int, n::Int; modulus::Int = conway_polynomial(n))
    g = gcd(d, n)
    g == n && return Int[]      # degenerate (shouldn't happen for d ∈ 1..n-1)
    # elements x ∈ GF(2^n)* with x^{2^g} = x
    [x for x in 1:(1 << n) - 1 if gf_pow(x, 1 << g, n; modulus = modulus) == x]
end

# Domain of the k-th free variable (diagonal offset d=k).
function _var_domain(k::Int, n::Int; modulus::Int, fn::Vector{Int})
    k == 1           && return fn
    2k == n          && return subfield_nonzero(k, n; modulus = modulus)
    return collect(1:(1 << n) - 1)
end

# Depth-first search implementing Algorithm 2.
# H: mutable n×n matrix (updated in place, backtracked by overwriting).
# level: current free-variable index (1..num_vars).
function _dfs!(H::Matrix{Int}, level::Int, n::Int, num_vars::Int,
               cr::Vector{Int}, id_arr::Matrix{Int},
               domains::Vector{Vector{Int}},
               count::Ref{Int}, limit::Int, max_evals::Ref{Int};
               modulus::Int)
    count[] >= limit && return
    if level > num_vars
        max_evals[] -= 1
        max_evals[] < 0 && return
        if is_qam_fast(H, n; modulus = modulus, cr = cr, id_arr = id_arr)
            count[] += 1
        end
        return
    end
    d = level
    for v in domains[level]
        count[] >= limit && return
        update_diagonal!(H, d, v, n; modulus = modulus)
        if is_proper_sub(H, d + 1, n)
            _dfs!(H, level + 1, n, num_vars, cr, id_arr, domains,
                  count, limit, max_evals; modulus = modulus)
        end
    end
end

"""
    generate_apn_f2(n; limit, max_evaluations, modulus) -> Int

Algorithm 2: count quadratic APN functions on GF(2^n) with F₂ coefficients.
`limit` caps the number of APN functions found; `max_evaluations` caps the number
of full is_qam_fast calls. Returns the raw count of passing H matrices.
Exhaustive for the default parameters at n≤8; budget-limited for n≥9.
"""
function generate_apn_f2(
    n::Int;
    limit::Int          = 200,
    max_evaluations::Int = 1 << 20,
    modulus::Int         = conway_polynomial(n),
)
    num_vars = n ÷ 2
    cr      = get_cyclic_reps(n)
    id_arr  = get_indices(n, cr)
    fn      = fn_set(n; modulus = modulus)
    domains = [_var_domain(k, n; modulus = modulus, fn = fn) for k in 1:num_vars]
    H       = zeros(Int, n, n)
    count   = Ref(0)
    evals   = Ref(max_evaluations)
    _dfs!(H, 1, n, num_vars, cr, id_arr, domains, count, limit, evals; modulus = modulus)
    count[]
end

function algorithm2_report(io::IO = stdout)
    print_section(io, "Algorithm 2: APN generation with F₂ coefficients")

    for n in [5, 6]
        mod = conway_polynomial(n)
        print_kv(io, "n=$n: |Fₙ|", length(fn_set(n; modulus=mod)))
        t0  = time()
        cnt = generate_apn_f2(n; limit = 500, max_evaluations = 1<<22, modulus = mod)
        elapsed = time() - t0
        print_kv(io, "n=$n: APN count (raw, full domain)", cnt)
        print_kv(io, "n=$n: time (s)", round(elapsed, digits=3))
    end

    print_kv(io, "note", "Table 2 counts come from Algorithm 3 (partial search), not Algorithm 2")
    print_kv(io, "completeness", "demo only; Algorithm 2 finds all F₂-coefficient APN matrices")
end

if abspath(PROGRAM_FILE) == @__FILE__
    algorithm2_report()
end
