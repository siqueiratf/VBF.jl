"""
Lift graph actions to ambient affine automorphisms (Kaleyski–Sunde Lemma 13).
The pointwise kernel fixes the affine graph span. Elementary transvections
generate its shear factor and GL of a complement; EA uses a basis adapted to
the low-bit output subspace. Orders use BigInt rather than saturation.
"""

_pr_gl_order(r::Int) = prod((BigInt(1) << r) - (BigInt(1) << i)
                           for i = 0:(r-1); init = BigInt(1))

"""Kernel generators and exact order; nothing means construction was interrupted."""
function _pr_affine_kernel(F::AbstractTruthTable{N,M}, points, ea::Bool, budget) where {N,M}
    d, anchor = (N+M), first(points)
    generators = F2AffineMap{d,UInt32}[]
    _pr_check!(budget) || return generators, nothing
    S = linear_basis(UInt32[p ⊻ anchor for p in points]; nbits = d)
    s = length(S)
    if ea
        # S ∩ O = (S^perp + O^perp)^perp, using VBF's packed GF(2) kernel.
        constraints = vcat(kernel_f2(S; nbits = d), UInt32[1 << (M+i) for i = 0:(N-1)])
        basis = kernel_f2(constraints; nbits = d)
        k = length(basis)
        for v in vcat(S, UInt32[1 << i for i = 0:(M-1)])
            is_in_span(v, linear_basis(basis; nbits = d); nbits = d) || push!(basis, v)
        end
        # A total function graph projects onto every input, hence S + O = V.
        @assert length(basis) == d && k == s - N
    else
        basis, k = complete_basis(S, d), s
    end
    r = d - s
    order = (BigInt(1) << (k*r)) * _pr_gl_order(r)
    r == 0 && return generators, order
    B = F2LinearMap{d,UInt32}(basis)
    Binv = inv(B)
    for j = (s+1):d, i = 1:d
        i == j && continue
        ea && !(i <= k || i > s) && continue
        _pr_check!(budget) || return generators, nothing
        T = identity_linear_map(d, UInt32)
        T.cols[j] ⊻= UInt32(1) << (i - 1)
        L = B ∘ T ∘ Binv
        A = F2AffineMap(L, anchor ⊻ L(anchor))
        @assert is_invertible(A) && all(p -> A(p) == p, points)
        push!(generators, A)
    end
    return generators, order
end

"""Validate an affine automorphism and return its permutation of graph indices."""
function _pr_graph_permutation(F::AbstractTruthTable{N,M}, A::F2AffineMap; ea::Bool = false) where {N,M}
    length(A.linear.cols) == (N+M) && is_invertible(A) ||
        throw(ArgumentError("automorphism must be invertible on the 2n-bit ambient space"))
    ea && !all(v -> v >> M == 0, view(A.linear.cols, 1:M)) &&
        throw(ArgumentError("EA pruning requires automorphisms preserving the output subspace"))
    points = FunctionGraph(F).packed
    permutation = Vector{Int}(undef, length(points))
    for (i, p) in pairs(points)
        y = A(p)
        index = Int(y >> M) + 1
        1 <= index <= length(points) && points[index] == y ||
            throw(ArgumentError("the supplied map is not an automorphism of the target graph"))
        permutation[i] = index
    end
    return permutation
end

"""Known quadratic translations, Lemma 14, in input-high/output-low packing."""
function _pr_quadratic_translations(F::AbstractTruthTable{N,M}) where {N,M}
    return [_pr_quadratic_translation(F,1<<i) for i in 0:(N-1)]
end

"""Lemma 14's τₐ, evaluated for any input translation a."""
function _pr_quadratic_translation(F::AbstractTruthTable{N,M},a::Int) where {N,M}
    c = UInt32(F(a) ⊻ F(0))
    cols = UInt32[1 << j for j = 0:((N+M)-1)]
    for j = 0:(N-1)
        cols[M+j+1] ⊻= UInt32(F((1 << j) ⊻ a) ⊻ F(1 << j)) ⊻ c
    end
    return F2AffineMap(F2LinearMap{(N+M),UInt32}(cols),(UInt32(a)<<M)|c)
end
