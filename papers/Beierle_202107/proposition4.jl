include("helpers.jl")

function proposition4_filter(A::FqMatrix, B::FqMatrix, n::Int)::Bool
    @assert size(A) == (n, n) "A must be $n×$n"
    @assert size(B) == (n, n) "B must be $n×$n"
    @assert size(A) == size(B) "A and B must have the same dimensions"

    order_A = _matrix_multiplicative_order(A)
    A_power = identity_matrix(base_ring(A), n)
    B_power = identity_matrix(base_ring(B), n)
    forbidden_dimensions = (2, 4, n - 1)

    for _ in 1:order_A
        A_power = A_power * A
        B_power = B_power * B

        d_A = fixed_space_dimension_gf2(A_power)
        d_B = fixed_space_dimension_gf2(B_power)

        if d_A != d_B || d_A in forbidden_dimensions || d_B in forbidden_dimensions
            return false
        end
    end

    return true
end

function proposition4_filter(A::AbstractMatrix, B::AbstractMatrix, n::Int)::Bool
    return proposition4_filter(_gf2_matrix(A, n), _gf2_matrix(B, n), n)
end
