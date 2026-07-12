include("helpers.jl")

function proposition5_filter(A, B, n::Int)::Bool
    A_bit = gf2_bitmatrix(A, n, name = "A")
    B_bit = gf2_bitmatrix(B, n, name = "B")

    multiplicative_order = bitmatrix_multiplicative_order(A_bit)
    bitmatrix_multiplicative_order(B_bit) == multiplicative_order || return false
    multiplicative_order >= 4 || return true

    A_powers = precompute_gf2_bit_powers(A_bit, multiplicative_order)
    B_powers = precompute_gf2_bit_powers(B_bit, multiplicative_order)

    for first_power in 1:(multiplicative_order - 3)
        for second_power in (first_power + 1):(multiplicative_order - 2)
            for third_power in (second_power + 1):(multiplicative_order - 1)
                if has_matching_identity_xor_triple(
                    A_powers,
                    B_powers,
                    first_power,
                    second_power,
                    third_power,
                )
                    return false
                end
            end
        end
    end

    return true
end
