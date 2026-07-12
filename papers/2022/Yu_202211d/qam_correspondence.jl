include(joinpath(@__DIR__, "helpers.jl"))
using VBF

# ── Claim: qam_to_sbox is the left-inverse of quadratic_apn_matrix on the
# homogeneous representative. For any QAM matrix M, let H = qam_to_sbox(M)
# (the unique quadratic homogeneous function with derivative matrix M); then
# quadratic_apn_matrix(H) == M. This follows because H(bᵢ) = 0 for all basis
# vectors, so D_{bⱼ}H(bᵢ) = H(bᵢ⊕bⱼ) = M[i,j].
function qam_round_trip(; n::Int = 5)
    F = gold_apn(n, 1)
    M = quadratic_apn_matrix(F)
    H = qam_to_sbox(M)
    M2 = quadratic_apn_matrix(H)
    M == M2
end

# ── Claim: for the homogeneous representative H = qam_to_sbox(M), APN-ness
# (differential uniformity 2) is equivalent to M being a QAM. We check both
# directions on a known QAM (Gold) and on the zero matrix (not a QAM).
function qam_apn_equivalence_checks(; n::Int = 5)
    # Gold x^3: known quadratic APN
    F = gold_apn(n, 1)
    M_qam = quadratic_apn_matrix(F)
    H_qam = qam_to_sbox(M_qam)
    qam_check = is_qam(M_qam)
    apn_check = differential_uniformity(H_qam) == 2

    # Zero matrix: not a QAM; homogeneous rep is the zero function
    M_zero = zeros(Int, n, n)
    H_zero = qam_to_sbox(M_zero)
    non_qam_check = !is_qam(M_zero)
    non_apn_check = differential_uniformity(H_zero) != 2

    (gold_is_qam = qam_check,
     gold_hom_is_apn = apn_check,
     zero_not_qam = non_qam_check,
     zero_hom_not_apn = non_apn_check)
end

# ── Claim: is_qam(F::SBox) agrees with the APN check for quadratic homogeneous
# S-boxes returned by qam_to_sbox.
function sbox_is_qam_consistency(; n::Int = 5)
    F = gold_apn(n, 1)
    M = quadratic_apn_matrix(F)
    H = qam_to_sbox(M)
    is_qam(H) == (differential_uniformity(H) == 2)
end

function qam_correspondence_report(io::IO = stdout)
    print_section("QAM Correspondence Checks (n = 5, Gold x³)", io)

    rt = qam_round_trip(n = 5)
    print_check("round-trip: quadratic_apn_matrix(qam_to_sbox(M)) == M", rt, io)

    eq = qam_apn_equivalence_checks(n = 5)
    print_check("Gold is_qam(M) == true", eq.gold_is_qam, io)
    print_check("Gold homogeneous rep has differential uniformity 2", eq.gold_hom_is_apn, io)
    print_check("zero matrix is not a QAM", eq.zero_not_qam, io)
    print_check("zero homogeneous rep is not APN", eq.zero_hom_not_apn, io)

    con = sbox_is_qam_consistency(n = 5)
    print_check("is_qam(SBox) consistent with APN check on homogeneous rep", con, io)

    all_pass = rt && eq.gold_is_qam && eq.gold_hom_is_apn &&
               eq.zero_not_qam && eq.zero_hom_not_apn && con
    println(io, "\n  Overall: ", status_str(all_pass))

    (
        round_trip = rt,
        gold_is_qam = eq.gold_is_qam,
        gold_hom_is_apn = eq.gold_hom_is_apn,
        zero_not_qam = eq.zero_not_qam,
        zero_hom_not_apn = eq.zero_hom_not_apn,
        is_qam_consistent = con,
        overall = all_pass,
    )
end

if abspath(PROGRAM_FILE) == @__FILE__
    print_header()
    qam_correspondence_report()
end
