"""
Set linear-equivalence: does an invertible F₂-linear map send one set of field
elements onto another? (after `are_sets_linear_equivalent` in Kaleyski's VBF
library). This is the primitive behind 3-to-1 / triplicate equivalence testing.
"""

"""
    are_sets_linear_equivalent(A, B, n) -> Union{F2LinearMap, Nothing}

Search for an invertible F₂-linear map `L: GF(2ⁿ) → GF(2ⁿ)` with `L(A) = B`
(as **sets**), by backtracking over the images of the standard basis `e₀,…,e_{n-1}`:
at each step a candidate image is accepted only if every linear combination
produced so far respects `x ∈ A ⇔ L(x) ∈ B`, and is drawn from images not yet in
the span (keeping `L` invertible). Returns such an `L` (its columns are the basis
images), or `nothing`. `A` and `B` must have equal size.
"""
function are_sets_linear_equivalent(
    A::AbstractVector{<:Integer},
    B::AbstractVector{<:Integer},
    n::Integer,
)
    length(A) == length(B) || return nothing
    nn = Int(n)
    N = 1 << nn
    inA = falses(N)
    for a in A
        
        inA[Int(a)+1] = true
    end
    inB = falses(N)
    for b in B
        
        inB[Int(b)+1] = true
    end
    choices = trues(N)
    choices[1] = false          # 0 cannot be a basis image
    basis = zeros(Int, nn)

    function rec(m::Int)
        m == nn && return true
        b = 1 << m
        @inbounds for y = 0:(N-1)
            choices[y+1] || continue
            ok = true
            for g = 0:((1<<m)-1)
                ny = y
                for j = 0:(m-1)
                    (g >> j) & 1 == 1 && (ny ⊻= basis[j+1])
                end
                if inA[(b⊻g)+1] != inB[ny+1]
                    ok = false
                    break
                end
            end
            ok || continue
            basis[m+1] = y
            removed = Int[]
            for g = 0:((1<<m)-1)
                ny = y
                for j = 0:(m-1)
                    (g >> j) & 1 == 1 && (ny ⊻= basis[j+1])
                end
                choices[ny+1] = false
                push!(removed, ny)
            end
            rec(m + 1) && return true
            for r in removed
                choices[r+1] = true
            end
        end
        return false
    end

    rec(0) || return nothing
    F2LinearMap{nn}(basis)
end
