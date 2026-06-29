include("helpers.jl")
include("phase2.jl")
using VBF
using Printf

function build_projection_basis()
    A = build_A_matrix()
    M = build_M_A(A)
    pivot_cols, free_cols = rref_f2!(M)
    n_free = length(free_cols)
    S = [Int[] for _ in 1:length(pivot_cols)]
    for i in 1:length(pivot_cols)
        for (j, fc) in enumerate(free_cols)
            M[i, fc] && push!(S[i], j)
        end
    end

    # The 200 fixed coordinates are those not in PH2_FREE_PAIRS
    fixed_indices = Int[]
    for j in 0:7, (p, q) in PH2_PAIRS
        if !((p, q) in PH2_FREE_PAIRS)
            push!(fixed_indices, ph2_vi(j, p, q) + 1)
        end
    end

    cols = BigInt[]
    for i in 1:n_free
        b = falses(n_free)
        b[i] = true
        c = apply_fc22_sol22(b, pivot_cols, free_cols, S)
        
        val = BigInt(0)
        for (idx, fi) in enumerate(fixed_indices)
            if c[fi]
                val |= (BigInt(1) << (idx - 1))
            end
        end
        push!(cols, val)
    end

    # GF2 rank and basis
    basis = Dict{Int, BigInt}()
    basis_param_indices = Int[]

    for (idx, x) in enumerate(cols)
        while x != 0
            p = ndigits(x, base=2) - 1
            if haskey(basis, p)
                x ⊻= basis[p]
            else
                basis[p] = x
                push!(basis_param_indices, idx)
                break
            end
        end
    end

    return length(basis), basis_param_indices, pivot_cols, free_cols, S
end

function run_slice(slice_idx::Int, basis_param_indices, pivot_cols, free_cols, S)
    b = falses(length(free_cols))
    for (t, param_idx) in enumerate(basis_param_indices)
        b[param_idx] = ((slice_idx >> (t - 1)) & 1) == 1
    end
    c = apply_fc22_sol22(b, pivot_cols, free_cols, S)
    lut = quadratic_lut(c)
    
    # Run Phase 2
    @printf("Slice %d: running Gröbner Basis...\n", slice_idx)
    apns = phase2_slice(lut, verify=true)
    if !isempty(apns)
        @printf("  => Found %d APNs!\n", length(apns))
    end
    return apns
end

if abspath(PROGRAM_FILE) == @__FILE__
    rank, basis_param_indices, pc, fc, S = build_projection_basis()
    @printf("Projection Rank: %d\n", rank)
    @printf("Total Slices: %d\n", 1 << rank)
    
    # Run first 5 slices as a test
    for i in 0:4
        @time run_slice(i, basis_param_indices, pc, fc, S)
    end
end
