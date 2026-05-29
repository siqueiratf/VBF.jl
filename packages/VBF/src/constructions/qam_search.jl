"""
The QAM construction method — searching for quadratic APN functions with
coefficients in a subfield (Ivković–Nikova, eprint 2024/1838).

Quadratic APN functions over `GF(2ⁿ)` whose univariate coefficients lie in the
subfield `GF(2ᵐ)` (`m ∣ n`) have a **cyclic derivative matrix**: in a normal
basis the Frobenius `x ↦ x^(2ᵐ)` shifts indices by `m`, so

    M[i+m, j+m] = M[i, j]^(2ᵐ)   (indices mod n).

The off-diagonal positions therefore split into orbits under
`(i, j) ↦ (i+m, j+m) (mod n)`, and `M` is determined by one **free field
element per orbit** ([`qam_cyclic_orbits`](@ref) / [`qam_from_cyclic`](@ref) —
the general form of the reference's per-`(n,m)` `Assign` routines). The QAM
search assigns these free variables and keeps the assignments for which `M` is a
QAM ([`is_qam`](@ref)), recovering each solution as a quadratic APN function
([`qam_to_sbox`](@ref)). Theorem 1 of the reference restricts the leading
variable to the elements whose `m`-spaced conjugates are linearly independent
([`independent_conjugate_elements`](@ref)).

[`search_qam`](@ref) runs this for a given `(n, m)`, deterministically, returning
the distinct quadratic APN functions found (deduplicated by EA-class via
[`apn_ea_mugshot`](@ref)). The reference accelerates the search with a
linear-permutation-group orbit reduction over each variable and Theorem-3
submatrix pruning; this port instead relies on the exact `is_qam` oracle and the
EA-class deduplication of the results, which is reuse-faithful but heavier per
candidate — practical for small `(n, m)`.
"""

# Frobenius `x ↦ x^(2^t)` in GF(2ⁿ), by repeated squaring (handles x = 0).
@inline function _frobenius(x::Int, t::Int, n::Int)
    @inbounds for _ in 1:t
        x = Int(gf_pow(x, 2, n))
    end
    x
end

"""
    qam_cyclic_orbits(n, m) -> Vector{Vector{Tuple{Int,Int}}}

The orbits of the off-diagonal positions `{i,j}` (1-indexed) of an `n×n` matrix
under the index shift `(i,j) ↦ (i+m, j+m) (mod n)`. One orbit per free variable
of a `GF(2ᵐ)`-coefficient QAM; within an orbit the entries are Frobenius
conjugates (the `k`-th entry is the rep raised to `2^{m·k}`). Reproduces the
reference's per-`(n,m)` `Assign` structure.
"""
function qam_cyclic_orbits(n::Integer, m::Integer)
    m >= 1 && n % m == 0 || throw(ArgumentError("qam_cyclic_orbits: need m ≥ 1 and m ∣ n"))
    key(i, j) = i < j ? (i, j) : (j, i)
    seen = Set{Tuple{Int, Int}}()
    orbits = Vector{Vector{Tuple{Int, Int}}}()
    for i in 0:n - 1, j in i + 1:n - 1
        key(i, j) in seen && continue
        orb = Tuple{Int, Int}[]
        ci, cj = i, j
        while !(key(ci, cj) in seen)
            k = key(ci, cj)
            push!(seen, k)
            push!(orb, (k[1] + 1, k[2] + 1))         # 1-indexed
            ci = (ci + m) % n
            cj = (cj + m) % n
        end
        push!(orbits, orb)
    end
    orbits
end

"""
    qam_from_cyclic(n, m, values) -> Matrix{Int}

Build the `n×n` symmetric, zero-diagonal derivative matrix of a
`GF(2ᵐ)`-coefficient QAM from one free field element per orbit of
[`qam_cyclic_orbits`](@ref): along each orbit the entry at step `k` is the
free value raised to `2^{m·k}` (Frobenius).
"""
function qam_from_cyclic(n::Integer, m::Integer, values::AbstractVector{<:Integer})
    orbits = qam_cyclic_orbits(n, m)
    length(values) == length(orbits) ||
        throw(ArgumentError("qam_from_cyclic: expected $(length(orbits)) values, got $(length(values))"))
    M = zeros(Int, n, n)
    @inbounds for (vi, orb) in enumerate(orbits)
        v = Int(values[vi])
        for (k, (i, j)) in enumerate(orb)
            val = _frobenius(v, m * (k - 1), Int(n))
            M[i, j] = val
            M[j, i] = val
        end
    end
    M
end

"""
    independent_conjugate_elements(n, m) -> Vector{Int}

Theorem 1 of Ivković–Nikova (the set `Cat^m_I`): the nonzero `a ∈ GF(2ⁿ)` whose
`m`-spaced conjugates `a, a^(2ᵐ), …, a^(2^{m(n/m-1)})` are linearly independent
over `GF(2)`. Used to restrict the leading free variable of the QAM search.
"""
function independent_conjugate_elements(n::Integer, m::Integer)
    n % m == 0 || throw(ArgumentError("independent_conjugate_elements: need m ∣ n"))
    r = n ÷ m
    out = Int[]
    conj = Vector{UInt}(undef, r)
    for a in 1:(1 << n) - 1
        x = a
        @inbounds for k in 1:r
            conj[k] = UInt(x)
            x = Int(gf_pow(x, 1 << m, Int(n)))       # x^(2ᵐ)
        end
        rank_f2(conj; nbits = Int(n)) == r && push!(out, a)
    end
    out
end

"""
    search_qam(n, m; limit=typemax(Int), max_evaluations=1<<22) -> Vector{SBox{n}}

Search for quadratic APN functions over `GF(2ⁿ)` with `GF(2ᵐ)` coefficients by
the QAM method: enumerate the cyclic derivative matrices ([`qam_from_cyclic`](@ref))
— each free variable ranges over the subfield its orbit closes into — keep those
that are QAMs ([`is_qam`](@ref)), recover each as a function ([`qam_to_sbox`](@ref)),
and return the distinct ones up to EA-class ([`apn_ea_mugshot`](@ref)). At most
`limit` classes are returned; the scan stops after `max_evaluations` candidates
(a guard for large `(n,m)` — the enumeration is exhaustive only when it completes
within that budget). Practical for small `(n,m)`; see the module docstring for
the acceleration the reference uses at `n = 8, 10`.
"""
function search_qam(n::Integer, m::Integer; limit::Integer = typemax(Int),
                    max_evaluations::Integer = 1 << 22)
    nn = Int(n)
    orbits = qam_cyclic_orbits(nn, m)
    k = length(orbits)
    # each free variable lies in the subfield GF(2^d) its orbit closes into
    subfields = Vector{Vector{Int}}(undef, k)
    for (oi, orb) in enumerate(orbits)
        d = gcd(m * length(orb), nn)
        subfields[oi] = [x for x in 0:(1 << nn) - 1 if _frobenius(x, d, nn) == x]
    end
    sizes = length.(subfields)

    found = SBox{nn, _storage_for(nn)}[]
    seen = Set{APNEAMugshot}()
    vals = zeros(Int, k)
    counter = zeros(Int, k)
    evals = 0
    while true
        @inbounds for vi in 1:k
            vals[vi] = subfields[vi][counter[vi] + 1]
        end
        M = qam_from_cyclic(nn, m, vals)
        if is_qam(M)
            S = qam_to_sbox(M)
            mug = apn_ea_mugshot(S)
            if !(mug in seen)
                push!(seen, mug)
                push!(found, S)
                length(found) >= limit && break
            end
        end
        evals += 1
        evals >= max_evaluations && break
        # odometer increment over the per-variable subfields
        p = 1
        while p <= k
            counter[p] += 1
            counter[p] < sizes[p] && break
            counter[p] = 0
            p += 1
        end
        p > k && break
    end
    found
end
