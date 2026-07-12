# Implements Theorem 2 — cyclically equivalent row-combination vectors give equal rank
# Paper: Yu, Li, Ichanska, Kaleyski (2025)
# Section: 3.1 Reducing the data to be tested, Theorem 2
#
# Pseudocode (Theorem 2):
#   For H with H[u,u]=0, H[u,v]=H[v,u], H[u+1,v+1]=H[u,v]² (mod n):
#   Rank(Σ λ_u H[u,:]) = Rank(Σ_{u=0}^{n-2} λ_u H[u+1,:] + λ_{n-1} H[0,:])
#   i.e., cyclically shifting (λ_0,…,λ_{n-1}) preserves the rank.
# VBF API used: gold_apn, rank_f2, gf_pow, conway_polynomial

include(joinpath(@__DIR__, "helpers.jl"))

# Compute GF(2)-rank of the linear combination Σ λ_u H[u+1,:] for bits of mask.
function row_combo_rank(H::Matrix{Int}, mask::Int, n::Int)
    vec = zeros(UInt, n)
    for i in 1:n
        acc = UInt(0)
        s = mask
        while s != 0
            j = trailing_zeros(s) + 1
            acc ⊻= UInt(H[j, i])
            s &= s - 1
        end
        vec[i] = acc
    end
    rank_f2(vec; nbits = n)
end

# Cyclic left shift of n-bit mask: bit i → bit (i-1) mod n.
function cyclic_left_shift(mask::Int, n::Int)
    msb = (mask >> (n - 1)) & 1
    ((mask << 1) & ((1 << n) - 1)) | msb
end

function verify_cyclic_rank_preservation(H::Matrix{Int}, n::Int)
    all_pass = true
    for mask in 1:(1 << n) - 1
        r1 = row_combo_rank(H, mask, n)
        shifted = cyclic_left_shift(mask, n)
        r2 = row_combo_rank(H, shifted, n)
        if r1 != r2
            all_pass = false
            break
        end
    end
    all_pass
end

function theorem2_report(io::IO = stdout)
    print_section(io, "Theorem 2: cyclic shift of coefficient vector preserves rank")

    for (n, k) in [(5, 1), (5, 3), (6, 1)]
        mod = conway_polynomial(n)
        F   = gold_apn(n, k; modulus = mod)
        b   = find_normal_element(n; modulus = mod)
        H   = normal_basis_deriv_matrix(F, b; modulus = mod)
        ok  = verify_cyclic_rank_preservation(H, n)
        print_check(io, "GF(2^$n) Gold x^{2^$k+1}: cyclic rank preservation", ok)
    end

    print_kv(io, "completeness", "exhaustive (all 2^n-1 masks for each function)")
end

if abspath(PROGRAM_FILE) == @__FILE__
    theorem2_report()
end
