"""
Private, read-only geometry shared by quadratic switching certificates.

`Geometry` is an immutable record. Its arrays are only read through this private
cache; all per-parent constraint rows remain local to the invocation. The lock
covers both construction and lookup, so concurrent searches never publish a
partially constructed geometry.
"""
const _SN_QUADRATIC_GEOMETRY_LOCK = ReentrantLock()
const _SN_QUADRATIC_GEOMETRY = Dict{Int,QuadraticExtensions.Geometry}()

"Return shared, privately read-only flat geometry for one supported dimension."
function _sn_quadratic_geometry(n::Int)
    lock(_SN_QUADRATIC_GEOMETRY_LOCK) do
        get!(_SN_QUADRATIC_GEOMETRY, n) do
            QuadraticExtensions.geometry(n)
        end
    end
end

"""
    _sn_quadratic_empty_certificate(F, check=nothing) -> Bool

Sufficient certificate that a previously validated APN has no nontrivial
Boolean switching neighbours. Unsupported dimensions, nonquadratic parents,
dependent component forms and inconclusive quadratic kernels return `false`.
The caller must retain the ordinary complete Boolean search on that result.

For a quadratic APN with `n` independent homogeneous component forms, let
`H_u={b.F : b.u=0}` modulo affine terms. It has dimension `n-1`. The homogeneous
quadratic switching kernel `K_u` consists of forms vanishing on each
decomposable bivector `w` with `B_F(w)=u`; its dimension is obtained by GF(2)
elimination on `n(n-1)/2` variables. If every `K_u` has dimension `n-1`, the full
Boolean switching kernel in every direction is exactly `Aff(n)+H_u`, with raw
dimension `2n` and zero quotient dimension after removing trivial solutions.

To exclude higher-degree solutions, the complete Boolean constraints are
translation invariant, hence closed under derivatives. Any solution of degree
at least three has an iterated derivative with nonzero cubic top part `T`.
Its contractions `i_a T` span a subspace `A_T` of `H_u`, of dimension at least
three. Since `dim(H_u)=n-1`, the contraction map has a nonzero radical vector
`z`. Every component form in `A_T` then vanishes polarly on `z`, so its output
mask annihilates `Im(B_F(z,.))`. This image has dimension `n-1` by APN; its
annihilator has dimension one, contradicting `dim(A_T)>=3`. Affine terms
always satisfy the switching constraints and do not change this argument.

The complete flat constraints are those of Edel--Pott switching, as used by
[`switching_neighbors`](@ref). This certificate preserves nonquadratic outputs:
they are proved absent before the Boolean algorithm is omitted.
"""
function _sn_quadratic_empty_certificate(F::SBox{N,T}, check::C=nothing) where {N,T,C}
    2 <= N <= 8 || return false
    _sn_check(check, :constraints, 0, :quadratic_degree)
    algebraic_degree(F) == 2 || return false
    coefficients = anf(F)
    forms = QuadraticExtensions.coord_forms(UInt16[
        coefficients[((1 << i) | (1 << j))+1]
        for i in 0:N-1 for j in i+1:N-1], N)
    rank_f2(forms; nbits=N*(N-1)÷2) == N || return false
    _sn_check(check, :constraints, 0, :quadratic_geometry)
    G = _sn_quadratic_geometry(N)
    rows = [UInt32[] for _ in 1:(1 << N)-1]
    @inbounds for (fi, (w, (x, y, z))) in enumerate(zip(G.flats, G.flatpts))
        _sn_check(check, :constraints, 0, fi)
        u = Int(F.lut[x+1] ⊻ F.lut[y+1] ⊻ F.lut[z+1] ⊻ F.lut[1])
        iszero(u) && return false
        push!(rows[u], w)
    end
    for u in eachindex(rows)
        _sn_check(check, :kernel, u, :quadratic_certificate)
        G.N - rank_f2(rows[u]; nbits=G.N) == N-1 || return false
    end
    return true
end
