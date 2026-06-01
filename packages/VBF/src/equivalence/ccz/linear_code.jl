"""
Edel-Pott graph-code generator matrices.

For a function `F : F₂ⁿ → F₂ⁿ`, the **CCZ-code** and **EA-code** are
binary linear codes whose permutation-equivalence captures CCZ- and
EA-equivalence of the underlying functions (Edel-Pott, "On the
equivalence of nonlinear functions", 2009, Theorems 9 and 10). This
file builds their generator matrices (`ccz_matrix` / `ea_matrix`).

!!! note "Out of scope: the code-equivalence test"
    Deciding equivalence from these codes requires testing binary linear-code
    *permutation-equivalence* (J. Leon's algorithm / group-theoretic backends).
    VBF ships the generator matrices as invariant building blocks but does
    **not** implement the permutation-equivalence kernel — that would require a
    native binary-code-equivalence implementation, a project in its
    own right. Use these matrices for downstream tooling or external
    code-equivalence software.
"""

"""
    ccz_matrix(F::SBox{N,T}) -> BitMatrix

The `(2n+1) × 2ⁿ` generator matrix of the CCZ-code of `F`. Column `x`
is `[1, (x ≪ n) | F(x)]` written LSB-first over `2n` bits with a
leading constant `1`. (Edel-Pott Theorem 9.)
"""
function ccz_matrix(F::SBox{N,T}) where {N,T}
    n_size = 1 << N
    M = falses(2N + 1, n_size)
    @inbounds for x = 0:(n_size-1)
        M[1, x+1] = true
        v = (UInt64(x) << N) | UInt64(F.lut[x+1])
        for b = 0:(2N-1)
            M[b+2, x+1] = ((v >> b) & 1) == 1
        end
    end
    return M
end

"""
    ea_matrix(F::SBox{N,T}) -> BitMatrix

The `(2n+1) × (2ⁿ + 2ⁿ - 1)` generator matrix of the EA-code of `F`:
the CCZ-code columns followed by the `2ⁿ - 1` columns
`[y]` (LSB-first, `2n+1` bits) for `y ∈ 1:2ⁿ-1`. (Edel-Pott Theorem 10.)
"""
function ea_matrix(F::SBox{N,T}) where {N,T}
    n_size = 1 << N
    ncols = n_size + (n_size - 1)
    M = falses(2N + 1, ncols)
    @inbounds for x = 0:(n_size-1)
        M[1, x+1] = true
        v = (UInt64(x) << N) | UInt64(F.lut[x+1])
        for b = 0:(2N-1)
            M[b+2, x+1] = ((v >> b) & 1) == 1
        end
    end
    @inbounds for y = 1:(n_size-1)
        col = n_size + y
        for b = 0:(2N)
            M[b+1, col] = ((UInt64(y) >> b) & 1) == 1
        end
    end
    return M
end
