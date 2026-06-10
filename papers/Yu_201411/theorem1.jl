include(joinpath(@__DIR__, "helpers.jl"))

# Implements Theorem 1: restricted quadratic APN functions correspond to QAMs.
# Paper section: II.B, "One to One Correspondence between Restricted Quadratic
# APN Functions and QAMs".
#
# VBF API used: gold_apn, quadratic_apn_matrix, qam_to_sbox, is_qam,
#               differential_uniformity, algebraic_degree.

function _is_symmetric_zero_diagonal(M::AbstractMatrix{<:Integer})
    n = size(M, 1)
    size(M, 2) == n || return false
    @inbounds for i = 1:n
        M[i, i] == 0 || return false
        for j = (i + 1):n
            M[i, j] == M[j, i] || return false
        end
    end
    true
end

"""
    theorem1_case(n; k = 1) -> NamedTuple

Check Theorem 1 on the Gold restricted quadratic APN function
`x^(2^k + 1)` over `F_2^n`.
"""
function theorem1_case(n::Int; k::Int = 1)
    F = gold_apn(n, k)
    M = quadratic_apn_matrix(F)
    H = qam_to_sbox(M)
    M2 = quadratic_apn_matrix(H)

    du_F = differential_uniformity(F)
    deg_F = algebraic_degree(F)
    du_H = differential_uniformity(H)
    deg_H = algebraic_degree(H)
    matrix_shape_ok = _is_symmetric_zero_diagonal(M)
    matrix_is_qam = is_qam(M)
    round_trip = M == M2
    homogeneous_is_qam = is_qam(H)
    homogeneous_is_apn = du_H == 2
    homogeneous_quadratic = deg_H == 2

    overall = du_F == 2 &&
        deg_F == 2 &&
        matrix_shape_ok &&
        matrix_is_qam &&
        round_trip &&
        homogeneous_is_qam &&
        homogeneous_is_apn &&
        homogeneous_quadratic

    (;
        n,
        k,
        gold_exponent = (1 << k) + 1,
        gold_differential_uniformity = du_F,
        gold_algebraic_degree = deg_F,
        matrix_symmetric_zero_diagonal = matrix_shape_ok,
        matrix_is_qam,
        round_trip,
        homogeneous_is_qam,
        homogeneous_differential_uniformity = du_H,
        homogeneous_algebraic_degree = deg_H,
        overall,
    )
end

"""
    theorem1_zero_matrix_case(n = 5) -> NamedTuple

Negative direction sanity check: the zero matrix is not a QAM and its
homogeneous representative is not APN.
"""
function theorem1_zero_matrix_case(n::Int = 5)
    M = zeros(Int, n, n)
    H = qam_to_sbox(M)
    matrix_not_qam = !is_qam(M)
    homogeneous_not_apn = differential_uniformity(H) != 2
    (;
        n,
        matrix_not_qam,
        homogeneous_differential_uniformity = differential_uniformity(H),
        homogeneous_algebraic_degree = algebraic_degree(H),
        homogeneous_not_apn,
        overall = matrix_not_qam && homogeneous_not_apn,
    )
end

"""
    theorem1_report(io; dims = (5, 6, 7), save_results = false) -> NamedTuple

Run the bounded/default Theorem 1 reproduction checks.
"""
function theorem1_report(
    io::IO = stdout;
    dims = (5, 6, 7),
    save_results::Bool = false,
)
    print_section("Theorem 1 - QAM/APN correspondence", io)

    cases = [theorem1_case(Int(n)) for n in dims]
    for r in cases
        print_kv("n = $(r.n), Gold exponent", r.gold_exponent, io)
        print_check("Gold function is APN and quadratic", r.gold_differential_uniformity == 2 && r.gold_algebraic_degree == 2, io)
        print_check("H is symmetric with zero diagonal", r.matrix_symmetric_zero_diagonal, io)
        print_check("H is a QAM", r.matrix_is_qam, io)
        print_check("quadratic_apn_matrix(qam_to_sbox(H)) == H", r.round_trip, io)
        print_check("homogeneous representative is APN and quadratic", r.homogeneous_differential_uniformity == 2 && r.homogeneous_algebraic_degree == 2, io)
    end

    zero = theorem1_zero_matrix_case(first(dims))
    print_check("zero matrix is not a QAM", zero.matrix_not_qam, io)
    print_check("zero homogeneous representative is not APN", zero.homogeneous_not_apn, io)

    result = (;
        cases,
        zero_matrix = zero,
        all_ok = all(r -> r.overall, cases) && zero.overall,
    )

    if save_results
        path = write_results_toml(Dict("theorem1" => result), "theorem1.toml")
        println(io, "\n  Results written to: ", path)
    end

    result
end

if abspath(PROGRAM_FILE) == @__FILE__
    print_header()
    theorem1_report()
end
