"""
Ortho-derivative of quadratic APN functions.

For quadratic `F` and `a ≠ 0`, the linearized derivative
`B_a(x)=F(x⊕a)⊕F(x)⊕F(a)⊕F(0)` has kernel `{0,a}` exactly when `F` is APN.
Its image is an `(n−1)`-dimensional linear hyperplane. The annihilator is
one-dimensional, with unique nonzero vector `π_F(a)` satisfying
`⟨π_F(a),B_a(x)⟩=0` for all x. Set `π_F(0)=0`.

The affine derivative `D_aF(x)=F(x⊕a)⊕F(x)` has the same direction, but its
constant inner product with this normal may be either 0 or 1. Affine drift
therefore leaves the ortho-derivative unchanged. Its linear-equivalence class
is an EA-invariant ([Canteaut, Couvreur and Perrin, 2022](@cite Canteaut_202205));
for quadratic APNs, EA and CCZ equivalence coincide ([Yoshiara, 2012](@cite Yoshiara_201200)).
Equal ortho-derivative spectra remain only necessary equivalence filters.
"""

"""
    ortho_derivative(F::SBox{N,T}) -> Union{SBox{N,T}, Nothing}

The unique annihilator normal of every nonzero linearized derivative, with
`π_F(0)=0`. Explicitly checks algebraic degree ≤2, then constructs `B_a` from
its N basis images and computes its annihilator with [`kernel_f2`](@ref).
An annihilator of dimension one is equivalent to rank `N−1` and hence APN-ness.
Returns `nothing` if quadraticity or any rank condition fails. Handles arbitrary
linear/constant drift; no condition on whether a derivative image contains zero.

```jldoctest
julia> using VBF

julia> π = ortho_derivative(gold_apn(5));

julia> π isa SBox{5, UInt8}
true

julia> π.lut[1] == 0
true
```
"""
function ortho_derivative(F::SBox{N,T}) where {N,T}
    algebraic_degree(F)<=2 || return nothing
    n_size=1<<N;result=zeros(T,n_size);rows=Vector{T}(undef,N)
    f0=F.lut[1]
    @inbounds for a in 1:(n_size-1)
        fa=F.lut[a+1] ⊻ f0
        for j in 0:(N-1)
            e=1<<j
            rows[j+1]=F.lut[(e⊻a)+1] ⊻ F.lut[e+1] ⊻ fa
        end
        normal=kernel_f2(rows;nbits=N)
        length(normal)==1 || return nothing
        result[a+1]=only(normal)
    end
    SBox{N,T}(result)
end

"""
    is_quadratic_apn(F::SBox) -> Bool

`true` iff F has algebraic degree ≤2 and every nonzero linearized derivative has
rank `N−1`. Equivalent to `ortho_derivative(F) !== nothing`.
"""
is_quadratic_apn(F::SBox)=ortho_derivative(F)!==nothing
