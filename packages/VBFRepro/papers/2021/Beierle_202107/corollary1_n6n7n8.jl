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
    n = nrows(A)
    for i in 0:(1 << n - 1)
        check_order_space(A, i) != check_order_space(B, i) && return false
    end
    true
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

function gen_permutation_tuples(n::Int)::Vector{Tuple{FqMatrix, FqMatrix}}
    rcfs = get_rcfs(n)
    prime_order_rcfs = filter(has_prime_multiplicative_order, rcfs)
    candidates = candidate_pairs_with_same_cycle_structure(prime_order_rcfs)
    representatives = remove_extended_power_similar_pairs(candidates)
    filter_permutation_tuples(representatives)
end
