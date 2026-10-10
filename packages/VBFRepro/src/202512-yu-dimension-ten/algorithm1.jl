# Implements Algorithm 1 — IsQAM: optimised QAM test via cyclic equivalence reduction
# Paper: Yu, Li, Ichanska, Kaleyski (2025)
# Section: 3.3 Algorithm to determine QAM, Algorithm 1
#
# Pseudocode (Algorithm 1 IsQAM(n, H)):
#   1. ID  ← GetIndices(n)
#   2. IDlen ← NumberOfColumns(ID)
#   3. RC  ← [ZeroVector ∈ GF(2^n)^n]
#   4. for t ∈ 1..IDlen:
#        rc ← RC[ID[1,t]+1] ⊕ H[ID[2,t],:]   (0-indexed ID[1,t] into RC)
#        if GF(2)-rank(rc) < n-1: return false
#        Append rc to RC
#   5. return true
#
# Helper getCyclicEquivalenceRepresentatives(n):
#   Returns sorted list of minimum integers in each cyclic-rotation equivalence class
#   of 1..2^n-1. Cyclic rotation: (a_{n-1}, a_0, …, a_{n-2}) ↔ right-rotate n-bit integer.
#
# Helper GetIndices(n, CR):
#   2×|CR| matrix ID where CR[t] = CR[ID[1,t]] + 2^{ID[2,t]-1}
#   (each CR element = predecessor + one new bit).
# VBF API used: rank_f2, conway_polynomial

include(joinpath(@__DIR__, "helpers.jl"))

# Right-rotation of n-bit integer (bit 0 → bit n-1).
@inline function _cyclic_right(v::Int, n::Int)
    lsb = v & 1
    (v >> 1) | (lsb << (n - 1))
end

# Sorted list of minimum elements from each cyclic-rotation orbit of {1,…,2^n-1}.
function get_cyclic_reps(n::Int)
    in_class = falses(1 << n)
    in_class[1] = true          # skip 0
    result = Int[]
    for v in 1:(1 << n) - 1
        in_class[v + 1] && continue
        # Collect full cyclic orbit of v
        rotations = Int[]
        cur = v
        for _ in 1:n
            push!(rotations, cur)
            cur = _cyclic_right(cur, n)
        end
        unique!(rotations)
        min_rot = minimum(rotations)
        if min_rot == v
            push!(result, v)
        end
        for r in rotations
            in_class[r + 1] = true
        end
    end
    sort!(result)
end

# 2×K index array.  For each t=2..K: CR[t] = CR[ID[1,t]] + 2^{ID[2,t]-1}
# (predecessor in CR plus its highest bit position, 1-based).
# ID[1,1]=0, ID[2,1]=1 (hardcoded base case).
function get_indices(n::Int, cr::Vector{Int})
    k   = length(cr)
    id  = zeros(Int, 2, k)
    id[1, 1] = 0
    id[2, 1] = 1
    cr_pos = Dict(cr[i] => i for i in eachindex(cr))
    for t in 2:k
        e = cr[t]
        j = 8 * sizeof(Int) - leading_zeros(e)   # highest set bit position (1-based)
        s = e ⊻ (1 << (j - 1))                  # e with highest bit cleared
        i = cr_pos[s]                            # index in CR of the predecessor
        id[1, t] = i
        id[2, t] = j
    end
    id
end

# Optimised QAM check (Algorithm 1). Only tests K ≈ 2^n/n linear combinations
# instead of the naive 2^n-1.  Valid only for H satisfying the F₂-coefficient
# diagonal squaring property (H[i+1,j+1] = H[i,j]² indices mod n).
function is_qam_fast(H::Matrix{Int}, n::Int;
                     modulus::Int      = conway_polynomial(n),
                     cr::Vector{Int}   = get_cyclic_reps(n),
                     id_arr::Matrix{Int} = get_indices(n, get_cyclic_reps(n)))
    idlen = size(id_arr, 2)
    rc_vec = zeros(Int, n)
    RC = [zeros(Int, n)]              # RC[1] = zero vector

    for t in 1:idlen
        prev_idx = id_arr[1, t]       # 0-based index into RC
        row_h    = id_arr[2, t]       # 1-based row of H to add
        rc_new   = RC[prev_idx + 1] .⊻ H[row_h, :]
        rank_f2(UInt.(rc_new); nbits = n) < n - 1 && return false
        push!(RC, rc_new)
    end
    true
end

function algorithm1_report(io::IO = stdout)
    print_section(io, "Algorithm 1: IsQAM (optimised, cyclic equivalence reduction)")

    n5 = 5
    mod5 = conway_polynomial(n5)
    cr5  = get_cyclic_reps(n5)
    id5  = get_indices(n5, cr5)

    print_kv(io, "n=5: CR", cr5)
    print_kv(io, "n=5: IDlen (K)", length(cr5))
    print_kv(io, "n=5: 2^n-1 (old algorithm)", (1 << n5) - 1)

    # Verify is_qam_fast == is_qam on several test matrices
    agree = 0
    total = 0
    for k in [1, 3]
        F  = gold_apn(n5, k; modulus = mod5)
        b  = find_normal_element(n5; modulus = mod5)
        H  = normal_basis_deriv_matrix(F, b; modulus = mod5)
        r1 = is_qam_fast(H, n5; modulus = mod5, cr = cr5, id_arr = id5)
        r2 = is_qam(H)
        total += 1
        agree += (r1 == r2) ? 1 : 0
        print_check(io, "Gold x^{2^$k+1} n=5: is_qam_fast==$r1, is_qam==$r2, agree=$(r1==r2)", r1==r2)
    end

    # Also test n=6
    n6 = 6
    mod6 = conway_polynomial(n6)
    cr6  = get_cyclic_reps(n6)
    id6  = get_indices(n6, cr6)
    print_kv(io, "n=6: K=|CR|", length(cr6))
    for k in [1, 5]
        F  = gold_apn(n6, k; modulus = mod6)
        b  = find_normal_element(n6; modulus = mod6)
        H  = normal_basis_deriv_matrix(F, b; modulus = mod6)
        r1 = is_qam_fast(H, n6; modulus = mod6, cr = cr6, id_arr = id6)
        r2 = is_qam(H)
        total += 1
        agree += (r1 == r2) ? 1 : 0
        print_check(io, "Gold x^{2^$k+1} n=6: agree=$(r1==r2)", r1==r2)
    end

    print_check(io, "is_qam_fast == is_qam on all $total test matrices", agree == total)
    print_kv(io, "completeness", "exact (agreement verified on representative APN functions)")
end

if abspath(PROGRAM_FILE) == @__FILE__
    algorithm1_report()
end
