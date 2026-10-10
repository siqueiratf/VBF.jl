# Shared helpers for Yu, Li, Ichanska, Kaleyski (2025)
# Paper: "Classification of quadratic APN functions with coefficients in F₂ in dimension 10"
#
# Pseudocode:
#   find_normal_element(n)         — smallest b s.t. {b,b²,...,b^{2^{n-1}}} is F₂-basis
#   normal_basis_deriv_matrix(F,b) — derivative matrix H in normal basis (= paper's H)
#   polynomial_sbox(n, exps)       — SBox from F(x) = XOR x^e for e in exps
#   update_diagonal!(H, d, v, n)   — fill diagonal offset d of H with v, v², v⁴, …
#   is_proper_sub(H, k, n)         — properness check on k×k upper-left submatrix
# VBF API used: gf_pow, conway_polynomial, rank_f2, SBox

using VBF

# Smallest b ∈ GF(2^n)* whose Frobenius orbit {b,b²,…,b^{2^{n-1}}} is a GF(2)-basis.
function find_normal_element(n::Int; modulus::Int = conway_polynomial(n))
    function _is_normal(b)
        basis = [gf_pow(b, 1 << i, n; modulus = modulus) for i in 0:n-1]
        mat = zeros(UInt8, n, n)
        for i in 1:n, bit in 0:n-1
            mat[bit+1, i] = (basis[i] >> bit) & 1
        end
        rank = 0
        for col in 1:n
            piv = findfirst(r -> mat[r, col] == 1, col:n)
            piv === nothing && continue
            row = piv + col - 1
            mat[[col, row], :] = mat[[row, col], :]
            rank += 1
            for r in 1:n
                r != col && mat[r, col] == 1 && (mat[r, :] .⊻= mat[col, :])
            end
        end
        rank == n
    end
    b = findfirst(_is_normal, 1:(1<<n)-1)
    b === nothing && error("no normal element for n=$n modulus=$modulus")
    b
end

# H[i,j] = F(αᵢ₋₁ ⊕ αⱼ₋₁) ⊕ F(αᵢ₋₁) ⊕ F(αⱼ₋₁), αₖ = b^{2^k}.  This is the paper's H.
function normal_basis_deriv_matrix(F::SBox{N}, b::Int;
                                   modulus::Int = conway_polynomial(N)) where {N}
    basis = [gf_pow(b, 1 << i, N; modulus = modulus) for i in 0:N-1]
    M = zeros(Int, N, N)
    for i in 1:N, j in (i+1):N
        v = Int(F(basis[i] ⊻ basis[j])) ⊻ Int(F(basis[i])) ⊻ Int(F(basis[j]))
        M[i, j] = v
        M[j, i] = v
    end
    M
end

# SBox for F(x) = ⊕_{e ∈ exponents} x^e over GF(2^n).
function polynomial_sbox(n::Int, exponents::Vector{Int};
                         modulus::Int = conway_polynomial(n))
    lut = zeros(Int, 1 << n)
    for x in 1:(1<<n)-1
        acc = 0
        for e in exponents
            acc ⊻= gf_pow(x, e, n; modulus = modulus)
        end
        lut[x+1] = acc
    end
    SBox{n}(lut)
end

# Write H[r,c] = v^{2^i} and H[c,r] for each i=0..n-1 on diagonal offset d (column - row ≡ d mod n).
function update_diagonal!(H::Matrix{Int}, d::Int, v::Int, n::Int;
                          modulus::Int = conway_polynomial(n))
    cur = v
    for i in 0:n-1
        r = i + 1
        c = (i + d) % n + 1
        H[r, c] = cur
        H[c, r] = cur
        cur = gf_pow(cur, 2, n; modulus = modulus)
    end
end

# True if every nonzero F₂-linear combination of the first k rows of H has GF(2)-rank ≥ k-1.
function is_proper_sub(H::Matrix{Int}, k::Int, n::Int)
    vec = zeros(UInt, k)
    @inbounds for mask in 1:(1 << k) - 1
        for i in 1:k
            acc = UInt(0)
            s = mask
            while s != 0
                j = trailing_zeros(s) + 1
                acc ⊻= UInt(H[j, i])
                s &= s - 1
            end
            vec[i] = acc
        end
        rank_f2(view(vec, 1:k); nbits = n) < k - 1 && return false
    end
    true
end
