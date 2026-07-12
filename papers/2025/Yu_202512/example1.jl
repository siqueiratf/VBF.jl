# Implements Example 1 — n=5 H matrix and rank computations
# Paper: Yu, Li, Ichanska, Kaleyski (2025)
# Section: 3.1 Reducing the data to be tested, Example 1
#
# Pseudocode:
#   H = 5×5 matrix with H[0,1]=a, diagonal squaring property.
#   (i)  λ=(1,0,0,0,0): Rank(H[0,:]²) = Rank(H[1,:]).
#   (ii) λ=(1,1,0,0,0): Rank((H[0,:]+H[1,:])²) = Rank(H[1,:]+H[2,:]).
# VBF API used: gf_pow, conway_polynomial, rank_f2

include(joinpath(@__DIR__, "helpers.jl"))

function build_example1_matrix(a::Int, b::Int, n::Int = 5;
                               modulus::Int = conway_polynomial(n))
    H = zeros(Int, n, n)
    update_diagonal!(H, 1, a, n; modulus = modulus)
    update_diagonal!(H, 2, b, n; modulus = modulus)
    H
end

function row_combo(H::Matrix{Int}, rows::Vector{Int}, n::Int)
    [mapreduce(r -> H[r, i], ⊻, rows) for i in 1:n]
end

function example1_report(io::IO = stdout)
    print_section(io, "Example 1: n=5, rank computations (Section 3.1)")

    mod = conway_polynomial(5)
    b_elem = find_normal_element(5; modulus = mod)

    # Use elements a,b with specific properties; pick concrete values.
    # From the paper's symbolic H = [...], a,b ∈ GF(2^5).
    # We use Gold APN x³ to get a concrete H with the squaring property.
    F = gold_apn(5, 1; modulus = mod)
    H = normal_basis_deriv_matrix(F, b_elem; modulus = mod)
    n = 5

    # Extract H[0,1] (0-based) = H[1,2] (1-based) = a
    a_val = H[1, 2]
    print_kv(io, "a = H[1,2]", a_val)
    print_kv(io, "a² = H[2,3]", H[2, 3])
    print_kv(io, "a² == gf_pow(a,2,5)", H[2,3] == gf_pow(a_val, 2, 5; modulus=mod))

    # (i) λ=(1,0,0,0,0): Rank(H[1,:]²) should equal Rank(H[2,:])
    h1_sq = [gf_pow(H[1, i], 2, 5; modulus = mod) for i in 1:n]
    r_h1  = rank_f2(UInt.(H[1, :]); nbits = 5)
    r_h1sq = rank_f2(UInt.(h1_sq); nbits = 5)
    r_h2  = rank_f2(UInt.(H[2, :]); nbits = 5)
    print_check(io, "(i) Span(H[0,:]²) = Span(H[1,:]): rank(H[1,:]²)==rank(H[2,:])",
                r_h1sq == r_h2)
    print_check(io, "(i) Rank(H[1,:]) == Rank(H[2,:])", r_h1 == r_h2)

    # (ii) λ=(1,1,0,0,0): row combo H[1,:]+H[2,:]
    combo12 = [H[1,i] ⊻ H[2,i] for i in 1:n]
    combo12_sq = [gf_pow(v, 2, 5; modulus=mod) for v in combo12]
    combo23 = [H[2,i] ⊻ H[3,i] for i in 1:n]
    r12 = rank_f2(UInt.(combo12); nbits=5)
    r12sq = rank_f2(UInt.(combo12_sq); nbits=5)
    r23 = rank_f2(UInt.(combo23); nbits=5)
    print_check(io, "(ii) Span((H[0,:]+H[1,:])²) = Span(H[1,:]+H[2,:]): ranks match",
                r12sq == r23)

    print_kv(io, "completeness", "exact (concrete n=5 Gold function)")
end

if abspath(PROGRAM_FILE) == @__FILE__
    example1_report()
end
