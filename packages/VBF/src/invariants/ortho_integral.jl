"""
The ortho-integral: invert the ortho-derivative.

Given a function `s : F₂ⁿ → F₂ⁿ` that *is* the ortho-derivative of some
quadratic APN, [`ortho_integral`](@ref) recovers a quadratic APN `Q`
with `ortho_derivative(Q) = s`. Such a `Q` is unique only up to adding
an F₂-linear function (which leaves the associated bilinear form — and
hence the ortho-derivative — unchanged), so the recovered `Q` is *a*
preimage, not *the* preimage.

# Algorithm

Unknowns are the `n·2ⁿ` output bits of `Q`: variable `i + n·x` is bit
`i` of `Q(x)`. A homogeneous F₂ linear system is assembled:

  1. `Q(0) = 0`: the `n` single-variable equations `var(i, 0) = 0`.
  2. For every `a ≠ 0` and `x ≠ a`, the constraint
     `⟨s(x), Q(x⊕a) ⊕ Q(x) ⊕ Q(a)⟩ = 0`, i.e. the XOR-sum over the set
     bits `i` of `s(x)` of `var(i, x⊕a) ⊕ var(i, x) ⊕ var(i, a)`.

The raw nullspace always contains the `n²`-dimensional space of
F₂-linear functions `L_{ij}` (output bit `j` = input bit `i`), which
satisfy every constraint trivially. We quotient them out; the first
remaining representative is returned as `Q`. Returns `nothing` if the
quotient is empty (no quadratic APN has `s` as its ortho-derivative).

The system has up to `n·2ⁿ` variables and `2ⁿ(2ⁿ-1)` equations; the
incremental row-reduction keeps at most `n·2ⁿ` pivot rows, so memory is
`O(n²·4ⁿ / 64)` words. Practical for `n ≤ 8`.
"""

# Reduce `row` against the running pivot set (REF); install as a new
# pivot if it does not vanish. Pivots stored as parallel vectors.
function _oi_reduce_and_install!(pivot_rows::Vector{BitVector},
                                 pivot_cols::Vector{Int},
                                 row::BitVector)
    @inbounds for t in eachindex(pivot_rows)
        if row[pivot_cols[t]]
            row .⊻= pivot_rows[t]
        end
    end
    lead = findfirst(row)
    if lead !== nothing
        push!(pivot_rows, row)
        push!(pivot_cols, lead)
    end
    return nothing
end

# Build a BitVector equation from a list of (0-based) variable positions,
# XOR-toggling so repeated positions cancel (the F₂-correct semantics).
function _oi_row(nvars::Int, positions::Vector{Int})
    row = falses(nvars)
    @inbounds for p in positions
        row[p + 1] = !row[p + 1]
    end
    return row
end

"""
    ortho_integral(s::SBox{N,T}) -> Union{SBox{N,T}, Nothing}

A quadratic APN `Q` with `ortho_derivative(Q) == s`, or `nothing` if no
such `Q` exists. The result is determined only up to adding an
F₂-linear function.
"""
function ortho_integral(s::SBox{N,T}) where {N,T}
    n = N
    n_size = 1 << N
    nvars = n * n_size
    s_lut = s.lut

    pivot_rows = BitVector[]
    pivot_cols = Int[]

    # (1) Q(0) = 0  →  var(i, 0) = 0 for i in 0:n-1.
    for i in 0:(n - 1)
        _oi_reduce_and_install!(pivot_rows, pivot_cols, _oi_row(nvars, [i]))
    end

    # (2) Main constraints.
    positions = Int[]
    @inbounds for a in 1:(n_size - 1)
        for x in 0:(n_size - 1)
            x == a && continue
            empty!(positions)
            sx = Int(s_lut[x + 1])
            xa = x ⊻ a
            for i in 0:(n - 1)
                if (sx >> i) & 1 == 1
                    push!(positions, i + n * xa)
                    push!(positions, i + n * x)
                    push!(positions, i + n * a)
                end
            end
            isempty(positions) && continue
            _oi_reduce_and_install!(pivot_rows, pivot_cols, _oi_row(nvars, positions))
        end
    end

    # Back-reduce to RREF so pivot columns are clean across rows.
    @inbounds for i in eachindex(pivot_rows)
        pc = pivot_cols[i]
        for j in eachindex(pivot_rows)
            i == j && continue
            if pivot_rows[j][pc]
                pivot_rows[j] .⊻= pivot_rows[i]
            end
        end
    end

    # Nullspace basis: one vector per free column.
    pivot_set = Set(pivot_cols)
    kernel = BitVector[]
    @inbounds for f in 1:nvars
        f in pivot_set && continue
        v = falses(nvars)
        v[f] = true
        for i in eachindex(pivot_rows)
            pivot_rows[i][f] && (v[pivot_cols[i]] = true)
        end
        push!(kernel, v)
    end

    # Quotient out the linear functions L_{ij}.
    qpiv_rows = BitVector[]
    qpiv_cols = Int[]
    @inbounds for i in 0:(n - 1)
        for j in 0:(n - 1)
            row = falses(nvars)
            for x in 0:(n_size - 1)
                ((x >> i) & 1) == 1 && (row[j + n * x + 1] = true)
            end
            _oi_reduce_and_install!(qpiv_rows, qpiv_cols, row)
        end
    end
    # Append kernel vectors that are independent of span(L_{ij}); the first
    # such vector is the ortho-integral representative.
    rep = nothing
    @inbounds for k in kernel
        row = copy(k)
        for t in eachindex(qpiv_rows)
            row[qpiv_cols[t]] && (row .⊻= qpiv_rows[t])
        end
        lead = findfirst(row)
        if lead !== nothing
            push!(qpiv_rows, row)
            push!(qpiv_cols, lead)
            rep === nothing && (rep = k)
        end
    end

    rep === nothing && return nothing
    return _oi_sbox_from_bits(rep, n, T)
end

# Decode a solution bit-vector into an SBox. var(i, x) = bit i of Q(x).
function _oi_sbox_from_bits(v::BitVector, n::Int, ::Type{T}) where {T}
    n_size = 1 << n
    lut = zeros(T, n_size)
    @inbounds for x in 0:(n_size - 1)
        val = zero(T)
        for i in 0:(n - 1)
            if v[i + n * x + 1]
                val |= (one(T) << i)
            end
        end
        lut[x + 1] = val
    end
    return SBox{n, T}(lut)
end
