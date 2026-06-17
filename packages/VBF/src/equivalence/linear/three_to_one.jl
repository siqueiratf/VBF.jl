"""
3-to-1 and triplicate functions ([Budaghyan, Ivković and Kaleyski, 2023](@cite Budaghyan_202300)).

A function `F : GF(2ⁿ) → GF(2ⁿ)` is **3-to-1** when every nonzero value is
attained exactly three times (so `n` is even and the image has `(2ⁿ-1)/3 + 1`
distinct values). `F` is **EA-equivalent to a triplicate function** iff there is
an invertible F₂-linear map `L` with `W_F(L(b), b) ≡ 1 (mod 3)` for every `b`,
where `W_F` is the Walsh/LAT coefficient
([Ivković and Kaleyski, 2022](@cite Ivkovic_202200)); [`triplicate_adjoint`](@ref) searches
for such an `L` by backtracking over the standard-basis images, pruned by the
mod-3 condition. (`L` is the adjoint of the linear `l` for which `F ⊕ l` is
triplicate.)

!!! note "Deferred: the canonical-triplicate linear-equivalence drivers"
    The standalone `alg1` / `alg2` / `alg_e1` routines (deciding linear
    equivalence of two canonical 3-to-1 functions, finding a uniform-3-to-1
    representative, and enumerating linear self-equivalences) are a large,
    dedicated dual-`L₁`/`L₂` propagation search over the β-coset triple
    structure. They are **not yet ported**; the building block
    [`are_sets_linear_equivalent`](@ref) (on image sets) is in place for a
    future native implementation.
"""

"""
    is_3_to_1(F) -> Bool

`true` iff `F` is a uniform 3-to-1 function: every value is attained at most
three times, and the image has exactly `(2ⁿ-1)/3 + 1` distinct values (forces
`n` even).
"""
function is_3_to_1(F::SBox{N,T}) where {N,T}
    n = 1 << N
    (n - 1) % 3 == 0 || return false
    counts = zeros(Int, n)
    @inbounds for v in F.lut
        (counts[Int(v)+1] += 1) > 3 && return false
    end
    count(!iszero, counts) == (n - 1) ÷ 3 + 1
end

function _triplicate_adjoint_search(
    Lmat::Matrix{Int},
    N::Int,
    collect_all::Bool,
)
    n = 1 << N
    basis = zeros(Int, N)
    results = F2LinearMap{N,_storage_for(N)}[]
    found = Ref{Union{Nothing,F2LinearMap{N,_storage_for(N)}}}(nothing)
    m3(v) = (r = v % 3; r < 0 ? r + 3 : r)
    function rec(i::Int)
        if i == N
            lm = F2LinearMap{N}(copy(basis))
            collect_all ? (push!(results, lm); false) : (found[] = lm; true)
        else
            b = 1 << i
            for y = 0:(n-1)
                m3(Lmat[y+1, b+1]) == 1 || continue
                ok = true
                for d = 0:((1<<(i==0 ? 0 : i-1))-1)
                    i == 0 && break  # no combinations before the first image
                    nx = b ⊻ d
                    ny = y
                    for j = 0:(i-2)
                        (d >> j) & 1 == 1 && (ny ⊻= basis[j+1])
                    end
                    if m3(Lmat[ny+1, nx+1]) != 1
                        ok = false
                        break
                    end
                end
                ok || continue
                basis[i+1] = y
                rec(i + 1) && return true
            end
            false
        end
    end
    rec(0)
    collect_all ? results : found[]
end

"""
    triplicate_adjoint(F) -> Union{F2LinearMap, Nothing}

An invertible F₂-linear `L` with `W_F(L(b), b) ≡ 1 (mod 3)` for all `b` (the
adjoint of the linear `l` making `F ⊕ l` triplicate), or `nothing` if none
exists.
"""
triplicate_adjoint(F::SBox{N,T}) where {N,T} =
    _triplicate_adjoint_search(lat(F), N, false)

"""
    is_equivalent_to_triplicate(F) -> Bool

`true` iff `F` is EA-equivalent to a triplicate function (i.e.
[`triplicate_adjoint`](@ref) succeeds).
"""
is_equivalent_to_triplicate(F::SBox) = triplicate_adjoint(F) !== nothing

"""
    triplicate_adjoints(F) -> Vector{F2LinearMap}

Every `L` satisfying the triplicate mod-3 Walsh condition (see
[`triplicate_adjoint`](@ref)).
"""
triplicate_adjoints(F::SBox{N,T}) where {N,T} =
    _triplicate_adjoint_search(lat(F), N, true)
