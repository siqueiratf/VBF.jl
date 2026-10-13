# Implements the Knuth estimator and the exact tree counter for pure quadratic APN functions
# Study: census of quadratic APN functions on F_2^8 (census/quadratic_apn8)
# Source: Beierle et al. (2025, v2), Theorem 4.1 (extension by one input variable)
#
# Math:
#   A pure quadratic (n,m)-function is F(x) = XOR_{i<j} x_i x_j C[i,j], C[i,j] in F_2^m.
#   Its bilinear form is B(x,y) = XOR_{i,j} x_i y_j C[i,j] (C symmetric, zero diagonal).
#   F is APN iff the linear map Lambda^2(F_2^n) -> F_2^m, e_i ^ e_j -> C[i,j], is nonzero on
#   every decomposable x ^ y, i.e. iff I_alpha = Im B(alpha, .) has dimension n-1 for all
#   alpha != 0. T(n,m) = #{APN coefficient tuples} = chi_{G(2,n)}(2^m) (Crapo-Rota).
#   Theorem 4.1: G(x, x_n) = F(x) + x_n L(x) is APN iff F is APN and L(alpha) not in I_alpha
#   for all alpha != 0 (L linear).  Build L one basis vector at a time: the value L(e_k) must
#   avoid L(a) + I_{a + e_k} for every a in span(e_1..e_{k-1}).
#
# Pseudocode (probe = one Knuth path through the extension tree):
#   1. C = 0; logw = 0.
#   2. For nv = 1 .. n-1 (current number of variables), for k = 1 .. nv:
#        free = F_2^m minus the union of L(a) + I_{a|e_k};  d = |free|.
#        d == 0 -> return logw = -Inf (dead end).  logw += log d.
#        L(e_k) = uniform element of free; C[k, nv+1] = L(e_k).
#   3. E[exp(logw)] = T(n,m) (Knuth 1975): the estimator is unbiased; dead ends count as 0.
#
# Module QK:  images, free_values!, probe, exact_count, gl_order, lut, logsumexp.
# Module QK2: completions (slow exact count of the last extension step, reference for
#             fastlast.jl) and probe_last_exact (slow pipeline).
# VBF API used: none (pure F_2 arithmetic; tests check results with VBF).

module QK

using Random

const MAXN = 12

"""
    images(C, nv, m) -> Vector{Vector{UInt16}} or nothing

Image `I_alpha = { B(alpha, x) : x }` of the bilinear form of the pure quadratic
function on `nv` variables with coefficient matrix `C`, for every `alpha` in
`1:2^nv-1`. Returns `nothing` when some kernel is larger than `{0, alpha}`, that is,
when the function is not APN.
"""
function images(C::Matrix{UInt16}, nv::Int, m::Int)
    out = Vector{Vector{UInt16}}(undef, (1 << nv) - 1)
    rows = zeros(UInt16, nv)
    for α in 1:(1 << nv) - 1
        for j in 1:nv
            r = UInt16(0)
            for i in 1:nv
                (α >> (i - 1)) & 1 == 1 && (r ⊻= C[i, j])
            end
            rows[j] = r
        end
        # Gaussian elimination -> basis
        basis = UInt16[]
        for r0 in rows
            r = r0
            for b in basis
                r = min(r, r ⊻ b)
            end
            r != 0 && push!(basis, r)
            sort!(basis; rev = true)
        end
        length(basis) == nv - 1 || return nothing
        els = Vector{UInt16}(undef, 1 << (nv - 1))
        els[1] = 0
        for (t, b) in enumerate(basis)
            h = 1 << (t - 1)
            for s in 1:h
                els[h + s] = els[s] ⊻ b
            end
        end
        out[α] = els
    end
    out
end

"""
    free_values!(forb, L, I, k, m) -> forb

Mark in `forb` the values that `L(e_k)` must avoid, given `L` on
`span(e_1..e_{k-1})` (indices `0:2^(k-1)-1`): the union of `L(a) + I_{a|e_k}`.
"""
function free_values!(forb::BitVector, L::Vector{UInt16}, I, k::Int, m::Int)
    fill!(forb, false)
    hk = 1 << (k - 1)
    @inbounds for a in 0:hk - 1
        base = L[a + 1]
        for y in I[a | hk]
            forb[(base ⊻ y) + 1] = true
        end
    end
    forb
end

"""
    probe(rng, n, m) -> (logw, C, nreached)

One plain Knuth probe down to `n` variables. `logw = -Inf` on a dead end.
"""
function probe(rng::AbstractRNG, n::Int, m::Int)
    C = zeros(UInt16, n, n)
    forb = falses(1 << m)
    logw = 0.0
    free = Vector{UInt16}(undef, 1 << m)
    for nv in 1:n - 1
        I = images(C, nv, m)
        I === nothing && error("internal: non-APN node")
        L = zeros(UInt16, 1 << nv)
        for k in 1:nv
            free_values!(forb, L, I, k, m)
            d = 0
            @inbounds for b in 0:(1 << m) - 1
                if !forb[b + 1]
                    d += 1
                    free[d] = b
                end
            end
            d == 0 && return (-Inf, C, nv)
            logw += log(d)
            b = free[rand(rng, 1:d)]
            C[k, nv + 1] = b
            C[nv + 1, k] = b
            hk = 1 << (k - 1)
            @inbounds for a in 0:hk - 1
                L[(a | hk) + 1] = L[a + 1] ⊻ b
            end
        end
    end
    (logw, C, n)
end

"""
    exact_count(n, m) -> BigInt

Exact number `T(n,m)` of leaves of the extension tree, by depth-first search.
Small cases only (the tree has `T(n,m)` leaves).
"""
function exact_count(n::Int, m::Int)
    C = zeros(UInt16, n, n)
    _dfs(C, 1, n, m)
end

function _dfs(C, nv, n, m)
    nv == n && return big(1)
    I = images(C, nv, m)
    L = zeros(UInt16, 1 << nv)
    _dfs_k(C, nv, 1, n, m, I, L)
end

function _dfs_k(C, nv, k, n, m, I, L)
    if k > nv
        return _dfs(C, nv + 1, n, m)
    end
    forb = free_values!(falses(1 << m), L, I, k, m)
    tot = big(0)
    hk = 1 << (k - 1)
    for b in 0:(1 << m) - 1
        forb[b + 1] && continue
        C[k, nv + 1] = b; C[nv + 1, k] = b
        for a in 0:hk - 1
            L[(a | hk) + 1] = L[a + 1] ⊻ UInt16(b)
        end
        tot += _dfs_k(C, nv, k + 1, n, m, I, L)
    end
    C[k, nv + 1] = 0; C[nv + 1, k] = 0
    tot
end

"`|GL(n,2)|` as a `BigInt`."
gl_order(n) = prod(big(2)^n - big(2)^i for i in 0:n - 1)

"""
    lut(C, n) -> Vector{UInt16}

Lookup table of the pure quadratic function with coefficient matrix `C`
(`lut[x+1] = F(x)`), for checks with VBF.
"""
function lut(C::Matrix{UInt16}, n::Int)
    out = zeros(UInt16, 1 << n)
    for x in 0:(1 << n) - 1
        v = UInt16(0)
        for i in 1:n, j in i + 1:n
            ((x >> (i - 1)) & 1 == 1 && (x >> (j - 1)) & 1 == 1) && (v ⊻= C[i, j])
        end
        out[x + 1] = v
    end
    out
end

"Numerically stable `log(sum(exp.(v)))`."
logsumexp(v) = (mx = maximum(v); isfinite(mx) ? mx + log(sum(exp.(v .- mx))) : mx)

end

module QK2

using ..QK, Random

"""
    completions(C, nv, m; keep = 0) -> (count, sols)

Exact number of linear `L: F_2^nv -> F_2^m` that extend the APN function `C`
(on `nv` variables) to an APN function on `nv+1` variables. Plain backtracking
without symmetry reduction; reference for the fast counters in fastlast.jl.
`sols` holds the first `keep` solutions as `[L(e_1), ..., L(e_nv)]`.
"""
function completions(C::Matrix{UInt16}, nv::Int, m::Int; keep::Int = 0)
    I = QK.images(C, nv, m)
    L = zeros(UInt16, 1 << nv)
    sols = Vector{Vector{UInt16}}()
    forbs = [falses(1 << m) for _ in 1:nv]
    cnt = _rec(I, L, 1, nv, m, forbs, sols, keep)
    cnt, sols
end

function _rec(I, L, k, nv, m, forbs, sols, keep)
    forb = QK.free_values!(forbs[k], L, I, k, m)
    if k == nv
        c = (1 << m) - count(forb)
        if keep > length(sols)
            for b in 0:(1 << m) - 1
                forb[b + 1] && continue
                # L(e_1..e_{nv-1}) are pairwise distinct and nonzero (0 is in every I_alpha).
                sol = UInt16[L[(1 << (i - 1)) + 1] for i in 1:nv - 1]
                push!(sol, UInt16(b))
                push!(sols, sol)
                length(sols) >= keep && break
            end
        end
        return c
    end
    tot = 0
    hk = 1 << (k - 1)
    for b in 0:(1 << m) - 1
        forb[b + 1] && continue
        @inbounds for a in 0:hk - 1
            L[(a | hk) + 1] = L[a + 1] ⊻ UInt16(b)
        end
        tot += _rec(I, L, k + 1, nv, m, forbs, sols, keep)
    end
    tot
end

"""
    probe_last_exact(rng, n, m) -> (logw, C, e)

Knuth probe down to `n-1` variables, then the slow exact count `e` of the last step.
`logw` includes `log(e)`; it is `-Inf` on a dead end or when `e == 0`.
"""
function probe_last_exact(rng, n, m)
    C = zeros(UInt16, n, n)
    forb = falses(1 << m); free = Vector{UInt16}(undef, 1 << m)
    logw = 0.0
    for nv in 1:n - 2
        I = QK.images(C, nv, m)
        L = zeros(UInt16, 1 << nv)
        for k in 1:nv
            QK.free_values!(forb, L, I, k, m)
            d = 0
            @inbounds for b in 0:(1 << m) - 1
                forb[b + 1] || (d += 1; free[d] = b)
            end
            d == 0 && return (-Inf, C, 0)
            logw += log(d)
            b = free[rand(rng, 1:d)]
            C[k, nv + 1] = b; C[nv + 1, k] = b
            hk = 1 << (k - 1)
            @inbounds for a in 0:hk - 1
                L[(a | hk) + 1] = L[a + 1] ⊻ b
            end
        end
    end
    e, _ = completions(C, n - 1, m)
    (e == 0 ? -Inf : logw + log(e), C, e)
end

end
