include("helpers.jl")

function check_order_space(A::FqMatrix, i::Int)
    @assert size(A, 1) == size(A, 2) "Matrix must be square"
    F = base_ring(A)
    n = nrows(A)
    A_power = A^i
    count = 0
    for v in _each_column_vector(F, n)
        A_power * v == v && (count += 1)
    end
    log(2, count)
end

function is_permutation_tuple(A::FqMatrix, B::FqMatrix)
    @assert size(A) == size(B) "A and B must have the same dimensions"
    # Fixed points of M^i are exactly the cycles whose lengths divide i.
    # Equal cycle multisets therefore certify every Ord dimension at once.
    matrix_cycle_structure(A) == matrix_cycle_structure(B)
end

function same_multiplicative_order(A::FqMatrix, B::FqMatrix)
    _matrix_multiplicative_order(A) == _matrix_multiplicative_order(B)
end

function has_prime_multiplicative_order(A::FqMatrix)::Bool
    order = _matrix_multiplicative_order(A)
    return Nemo.is_prime(order)
end

function _permutation_cycle_structure(permutation::Vector{Int})::Vector{Int}
    n = length(permutation)
    seen = falses(n)
    cycle_lengths = Int[]
    @inbounds for start in 0:(n - 1)
        seen[start + 1] && continue
        current = start
        len = 0
        while !seen[current + 1]
            seen[current + 1] = true
            len += 1
            current = permutation[current + 1]
            0 <= current < n || error("Permutation value out of range: $current")
        end
        push!(cycle_lengths, len)
    end
    sort!(cycle_lengths)
end

function matrix_cycle_structure(A::FqMatrix)::Vector{Int}
    _permutation_cycle_structure(_matrix_to_sbox(A))
end

function is_power_similar(A_pair, B_pair)
    A1, A2 = A_pair
    B1, B2 = B_pair

    order_A1 = _matrix_multiplicative_order(A1)
    order_A2 = _matrix_multiplicative_order(A2)
    order_B1 = _matrix_multiplicative_order(B1)
    order_B2 = _matrix_multiplicative_order(B2)

    (order_A1 != order_B1 || order_A2 != order_B2) && return false

    limit = max(order_A1, order_A2)
    for i in 0:(limit - 1)
        if _matrix_is_similar(A1^i, B1) && _matrix_is_similar(A2^i, B2)
            return true
        end
    end
    false
end

function is_extended_power_similar(A_pair::Tuple{T,T}, B_pair::Tuple{T, T}) where T <: FqMatrix
    is_power_similar(A_pair, B_pair) && return true
    A1, A2 = A_pair
    B1, B2 = B_pair
    is_power_similar([inv(A1), inv(A2)], [B2, B1])
end

function candidate_pairs_with_same_order(matrices::Vector{T}) where T <: FqMatrix
    candidates = Vector{Tuple{T, T}}()
    for A in matrices, B in matrices
        same_multiplicative_order(A, B) && push!(candidates, (A, B))
    end
    candidates
end

function candidate_pairs_with_same_cycle_structure(matrices::Vector{T}) where T <: FqMatrix
    candidates = Vector{Tuple{T, T}}()
    cycle_structures = Dict{Int, Vector{Int}}()
    for (index, matrix) in pairs(matrices)
        cycle_structures[index] = matrix_cycle_structure(matrix)
    end
    for (i, A) in pairs(matrices), (j, B) in pairs(matrices)
        cycle_structures[i] == cycle_structures[j] && push!(candidates, (A, B))
    end
    candidates
end

function remove_extended_power_similar_pairs(pairs::Vector{Tuple{T, T}}) where T <: FqMatrix
    n = length(pairs)
    active = trues(n)
    for i in 1:n
        !active[i] && continue
        for j in 1:n
            if i == j || !active[j]
                continue
            end
            if is_extended_power_similar(pairs[j], pairs[i])
                active[i] = false
                break
            end
        end
    end
    pairs[active]
end

function filter_permutation_tuples(pairs::Vector{Tuple{T, T}}) where T <: FqMatrix
    filter(pair -> is_permutation_tuple(pair[1], pair[2]), pairs)
end

"""Prime-order similarity signature; charpoly suffices only for odd prime order."""
function prime_order_power_signatures(A::FqMatrix)
    p = _matrix_multiplicative_order(A)
    Nemo.is_prime(p) || throw(ArgumentError("prime-order matrix required"))
    if p == 2
        return [(p, rank(A - identity_matrix(base_ring(A), nrows(A))))]
    end
    power = A
    signatures = Tuple[]
    for i in 1:(p-1)
        polynomial = charpoly(power)
        push!(signatures, (p, Tuple((iszero(coeff(polynomial,j)) ? 0 : 1) for j in 0:degree(polynomial))))
        power *= A
    end
    signatures
end

"""
Canonical Definition3 class key: simultaneous nonzero powers, plus swapped
inverse powers. Odd prime-order matrices are semisimple (X^p-1 is squarefree);
for order2, involution similarity is determined by rank(M-I). No general matrix
similarity or APN-class classification is asserted.
"""
function extended_power_class_key(a, b)
    length(a) == length(b) || throw(ArgumentError("power orders differ"))
    minimum(vcat([(a[i],b[i]) for i in eachindex(a)],
                 [(b[i],a[i]) for i in eachindex(a)]))
end

function gen_permutation_tuples(n::Int)::Vector{Tuple{FqMatrix, FqMatrix}}
    rcfs = get_rcfs(n)
    prime_order_rcfs = filter(has_prime_multiplicative_order, rcfs)
    signatures = [prime_order_power_signatures(A) for A in prime_order_rcfs]
    cycles = matrix_cycle_structure.(prime_order_rcfs)
    representatives = Dict{Tuple,Tuple{FqMatrix,FqMatrix}}()
    for i in eachindex(prime_order_rcfs), j in eachindex(prime_order_rcfs)
        cycles[i] == cycles[j] || continue
        key = extended_power_class_key(signatures[i], signatures[j])
        get!(representatives,key,(prime_order_rcfs[i],prime_order_rcfs[j]))
    end
    [representatives[k] for k in sort!(collect(keys(representatives)))]
end

"""
    generate_tuple_matrix_constants_file(n; output, full_search=false)

Regenerate the mathematical tuple classification, writing only to an explicit
output path. Enumerated representatives/order may differ from the historical
committed constants; compare extended-power-similarity classes, not indices.
`n>=7` requires full_search=true. This is the BBL2021 APN-permutation numbering,
not the separate Beierle--Leander2022 quadratic-APN tuple catalog.
"""
function generate_tuple_matrix_constants_file(n::Int; output::AbstractString,
                                               full_search::Bool = false)
    2 <= n <= 8 || throw(ArgumentError("tuple generation supports 2 <= n <= 8"))
    n <= 6 || full_search || throw(ArgumentError("n=$n requires full_search=true"))
    pairs = gen_permutation_tuples(n)
    blocks = map(pairs) do (A, B)
        # A/B orientation is the file's actual stored orientation. The search
        # API documents its F(Bx)=A F(x) convention separately.
        Ai = Int.([iszero(A[r,c]) ? 0 : 1 for r in 1:n, c in 1:n])
        Bi = Int.([iszero(B[r,c]) ? 0 : 1 for r in 1:n, c in 1:n])
        (; tuple = vcat(_matrix_to_sbox(A), _matrix_to_sbox(B)), A = Ai, B = Bi, search = nothing)
    end
    mkpath(dirname(abspath(output)))
    open(output, "w") do io
        _write_tuple_matrix_constants(io, n, blocks)
    end
    (; n, count = length(blocks), output = abspath(output), blocks)
end

"""Compare full class sets without assuming historical class numbering."""
function verify_generated_tuple_classes(n::Int, blocks)
    committed = _load_tuple_matrix_blocks(joinpath(@__DIR__, "tuples", "AllTuplesMatrices$n.toml"))
    length(committed) == length(blocks) || return false
    known = [(_gf2_matrix(b.A,n), _gf2_matrix(b.B,n)) for b in committed]
    generated = [(_gf2_matrix(b.A,n), _gf2_matrix(b.B,n)) for b in blocks]
    key(pair) = extended_power_class_key(prime_order_power_signatures(pair[1]),
                                         prime_order_power_signatures(pair[2]))
    Set(key.(generated)) == Set(key.(known))
end
