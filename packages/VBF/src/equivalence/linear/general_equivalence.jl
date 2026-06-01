"""
Linear-equivalence for **arbitrary** (possibly non-permutation) functions.

`are_linearly_equivalent_perm` (the LPP backtracking) assumes both
S-boxes are permutations — it follows the functional inverse and silently
returns `false` for non-bijective inputs. But the central APN use-case is
non-bijective: almost every APN function is 3-to-1, and the ortho-derivative
EA-test reduces EA-equivalence of quadratic APN to **linear**-equivalence of the
ortho-derivatives, which are themselves non-permutations.

[`are_linearly_equivalent_general`](@ref) decides linear-equivalence without
assuming bijectivity. It searches for invertible `L₁, L₂` with `G = L₁∘F∘L₂` by
guessing `L₂` on the standard basis (each image kept independent of the previous,
so `L₂` stays invertible) and, for every point of the span fixed so far,
propagating the constraint `L₁(F(L₂(x))) = G(x)` into a partial linear map `L₁`
maintained in row-reduced form. A branch dies on the first inconsistency; a
complete `L₂` with a full-rank `L₁` is a witness.
"""

# A partial linear map held as a row-reduced set of independent inputs `bin`
# (each with a distinct high-bit pivot) and their required outputs `bout`.
# `_lin_add!` folds in the constraint `L(u) = v`, returning `false` on conflict.
function _lin_add!(bin::Vector{Int}, bout::Vector{Int}, u::Integer, v::Integer)
    r = Int(u); o = Int(v) & 0   # o accumulates the output of the reduced part
    o = 0
    @inbounds for k in eachindex(bin)
        p = bin[k]
        hb = 1 << (8 * sizeof(Int) - 1 - leading_zeros(p))   # high set bit of p
        if r & hb != 0
            r ⊻= p
            o ⊻= bout[k]
        end
    end
    if r == 0
        return Int(v) == o            # fully reduced ⇒ L(u) is fixed; check it
    else
        push!(bin, r)
        push!(bout, Int(v) ⊻ o)        # L(r) = v ⊻ o
        return true
    end
end

"""
    are_linearly_equivalent_general(F::SBox{N,T}, G::SBox{N,T}) -> Bool

Decide whether invertible F₂-linear maps `L₁, L₂` exist with `G = L₁∘F∘L₂`,
for arbitrary (possibly non-permutation) `F, G`. See the module docstring.
"""
function are_linearly_equivalent_general(F::SBox{N,T}, G::SBox{N,T}) where {N,T}
    # Fast necessary rejects: the DDT and absolute-Walsh spectra are
    # linear-equivalence invariants. A mismatch ⇒ not linearly equivalent —
    # instant, and it spares the backtracking the costly job of *exhausting* an
    # inequivalent pair (the expensive case).
    differential_spectrum(F) == differential_spectrum(G) || return false
    absolute_walsh_spectrum(F) == absolute_walsh_spectrum(G) || return false
    NN = 1 << N
    Fl = F.lut
    Gl = G.lut
    L2 = fill(-1, NN); L2[1] = 0       # L₂(0) = 0
    used = Int[]                       # chosen L₂ basis images (for independence)

    # is `v` independent of the images chosen so far (so L₂ stays invertible)?
    indep = function (v::Int)
        v == 0 && return false
        r = v
        @inbounds for u in used
            hb = 1 << (8 * sizeof(Int) - 1 - leading_zeros(u))
            r & hb != 0 && (r ⊻= u)
        end
        r != 0
    end

    rec = function (i::Int, bin::Vector{Int}, bout::Vector{Int})
        # L₂ complete and consistent. L₁ is pinned on span(image F) by the
        # constraints (bin ↦ bout); it extends to an invertible map iff that
        # determined part is injective, i.e. the outputs are as independent as
        # the inputs. (`length(bin) == N` alone would both reject non-spanning F
        # — e.g. constant functions, breaking reflexivity — and risk accepting a
        # non-invertible L₁ when the outputs are dependent.)
        i == N && return rank_f2(UInt32.(bout); nbits = N) == length(bin)
        b = 1 << i
        @inbounds for img in 1:NN - 1
            indep(img) || continue
            bin2 = copy(bin); bout2 = copy(bout)
            newpos = Int[]; ok = true
            for x in 0:NN - 1                       # span of basis bits 0..i-1 is x < 2^i
                x >> i == 0 || continue
                nx = x ⊻ b
                L2[nx + 1] = L2[x + 1] ⊻ img
                push!(newpos, nx)
                if !_lin_add!(bin2, bout2, Fl[L2[nx + 1] + 1], Gl[nx + 1])
                    ok = false; break
                end
            end
            if ok
                push!(used, img)
                rec(i + 1, bin2, bout2) && return true
                pop!(used)
            end
            for p in newpos
                L2[p + 1] = -1
            end
        end
        false
    end

    bin = Int[]; bout = Int[]
    _lin_add!(bin, bout, Fl[1], Gl[1])              # F(L₂(0)) = F(0) ↦ G(0)
    rec(0, bin, bout)
end
