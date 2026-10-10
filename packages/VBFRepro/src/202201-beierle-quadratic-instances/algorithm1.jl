# Implements Algorithm 1 (QuadraticAPNSearch) from Beierle & Leander (2022).
# Paper: Beierle, Leander (2022), "New Instances of Quadratic APN Functions",
#        IEEE Trans. Inf. Theory 68(1):670–678 / arXiv:2009.07204
# Section: §3 — A Recursive Tree Search for Quadratic APN Functions, Algorithm 1 (p.8)
#
# The algorithm is a randomised recursive tree search that fills the LUT of F
# entry by entry, simultaneously enforcing two constraints:
#   - APN: the DDT never exceeds 2 (§3.1, AddDDTInformation).
#   - Quadratic: no ANF coefficient of bit-weight ≥ 3 is non-zero (§3.2, AddDegreeInformation).
# At the start every depth level's trial order is independently shuffled (lines 1–3).
# F(0) is fixed to 0 (line 4). The basic search (§3) places no LE-automorphism
# constraint; for n ≥ 8 the LE-automorphism variant of §4 is more efficient.
#
# VBF API used: SBox

using VBF
import Random

# ── APN check (§3.1) ────────────────────────────────────────────────────────────

function _add_ddt!(c::Int, sbox::Vector{Int}, ddt::Matrix{Int})::Bool
    c_val = sbox[c + 1]
    field_size = length(sbox)
    ok = true
    @inbounds for alpha in 1:(field_size - 1)
        paired_val = sbox[xor(c, alpha) + 1]
        paired_val == -1 && continue
        beta = xor(c_val, paired_val)
        ddt[alpha + 1, beta + 1] += 2
        ok &= ddt[alpha + 1, beta + 1] <= 2
    end
    return ok
end

function _remove_ddt!(c::Int, sbox::Vector{Int}, ddt::Matrix{Int})
    c_val = sbox[c + 1]
    field_size = length(sbox)
    @inbounds for alpha in 1:(field_size - 1)
        paired_val = sbox[xor(c, alpha) + 1]
        paired_val == -1 && continue
        ddt[alpha + 1, xor(c_val, paired_val) + 1] -= 2
    end
end

# ── Algebraic degree check (§3.2) ───────────────────────────────────────────────
#
# Tracks the partial Möbius (ANF) transform incrementally:
#   ctr[u+1]     = number of x ≼ u (in the bit-vector partial order) already assigned.
#   sum_arr[u+1] = XOR of sbox[x+1] over assigned x ≼ u.
# When ctr[u+1] = 2^wt(u), sum_arr[u+1] equals the ANF coefficient a_u.
# Returning false signals that a_u ≠ 0 for some wt(u) ≥ 3, i.e., degree ≥ 3.

function _add_degree!(x::Int, sbox::Vector{Int},
                      ctr::Vector{Int}, sum_arr::Vector{Int}, n::Int)::Bool
    x_val = sbox[x + 1]
    field_size = 1 << n
    ok = true
    @inbounds for u in 1:(field_size - 1)
        count_ones(u) < 3 && continue
        (x & u) == x || continue
        ctr[u + 1] += 1
        sum_arr[u + 1] ⊻= x_val
        if ctr[u + 1] == 1 << count_ones(u)
            ok &= sum_arr[u + 1] == 0
        end
    end
    return ok
end

function _remove_degree!(x::Int, sbox::Vector{Int},
                         ctr::Vector{Int}, sum_arr::Vector{Int}, n::Int)
    x_val = sbox[x + 1]
    field_size = 1 << n
    @inbounds for u in 1:(field_size - 1)
        count_ones(u) < 3 && continue
        (x & u) == x || continue
        ctr[u + 1] -= 1
        sum_arr[u + 1] ⊻= x_val
    end
end

# ── AddPoint / RemovePoint (§3, lines 23–33) ─────────────────────────────────────

function _add_point!(c::Int, sbox::Vector{Int}, ddt::Matrix{Int},
                     ctr::Vector{Int}, sum_arr::Vector{Int}, n::Int)::Bool
    ddt_ok = _add_ddt!(c, sbox, ddt)
    degree_ok = _add_degree!(c, sbox, ctr, sum_arr, n)
    return ddt_ok && degree_ok
end

function _remove_point!(c::Int, sbox::Vector{Int}, ddt::Matrix{Int},
                        ctr::Vector{Int}, sum_arr::Vector{Int}, n::Int)
    _remove_ddt!(c, sbox, ddt)
    _remove_degree!(c, sbox, ctr, sum_arr, n)
end

# ── NextVal (§3, lines 7–22) ────────────────────────────────────────────────────
#
# _remove_point! is called while sbox[x+1] still holds the trial value y so that
# the DDT and degree arrays can read sbox[x+1]; the reset to -1 follows.

function _next_val!(depth::Int, sbox::Vector{Int}, ddt::Matrix{Int},
                    ctr::Vector{Int}, sum_arr::Vector{Int}, n::Int,
                    P::Matrix{Int}, solutions::Vector{SBox},
                    max_solutions::Int, deadline::Union{Nothing,Float64})
    length(solutions) >= max_solutions && return
    deadline !== nothing && time() > deadline && return

    x = -1
    @inbounds for i in eachindex(sbox)
        sbox[i] == -1 && (x = i - 1; break)
    end
    if x == -1
        push!(solutions, SBox(copy(sbox)))
        return
    end

    field_size = length(sbox)
    @inbounds for z in 1:field_size
        length(solutions) >= max_solutions && break
        y = P[depth + 1, z]
        sbox[x + 1] = y
        if _add_point!(x, sbox, ddt, ctr, sum_arr, n)
            _next_val!(depth + 1, sbox, ddt, ctr, sum_arr, n,
                       P, solutions, max_solutions, deadline)
        end
        _remove_point!(x, sbox, ddt, ctr, sum_arr, n)
        sbox[x + 1] = -1
    end
end

# ── Public API ───────────────────────────────────────────────────────────────────

"""
    quadratic_apn_search(n; max_solutions, seed, timeout_seconds) -> Vector{SBox}

Run Algorithm 1 (QuadraticAPNSearch) for n-bit functions. Searches for quadratic
APN functions F: F_2^n → F_2^n using a randomised recursive tree search that
simultaneously enforces the APN property (§3.1) and algebraic degree ≤ 2 (§3.2).
Always fixes F(0) = 0. Returns up to max_solutions solutions.

For n ≥ 8, the direct search is slow; §4's LE-automorphism variant is preferable.
Beierle–Leander (2022), §3, Algorithm 1, p.8.
"""
function quadratic_apn_search(n::Int;
                               max_solutions::Int = 1,
                               seed::Int = 42,
                               timeout_seconds::Union{Nothing,Real} = nothing)::Vector{SBox}
    field_size = 1 << n
    Random.seed!(seed)

    P = Matrix{Int}(undef, field_size, field_size)
    for i in 1:field_size
        P[i, :] = Random.shuffle!(collect(0:(field_size - 1)))
    end

    sbox    = fill(-1, field_size)
    ddt     = zeros(Int, field_size, field_size)
    ctr     = zeros(Int, field_size)
    sum_arr = zeros(Int, field_size)
    solutions = SBox[]
    deadline  = timeout_seconds === nothing ? nothing : time() + Float64(timeout_seconds)

    sbox[1] = 0
    _add_point!(0, sbox, ddt, ctr, sum_arr, n)

    _next_val!(0, sbox, ddt, ctr, sum_arr, n, P, solutions, max_solutions, deadline)
    return solutions
end
