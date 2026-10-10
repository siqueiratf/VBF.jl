# Implements Table 3 — 6 CCZ-inequivalent representatives for n=11 (conjectured)
# Paper: Yu, Li, Ichanska, Kaleyski (2025)
# Section: 4.2 Further observation, Table 3
#
# Pseudocode:
#   F1(x) = x^3 = x^{2^1+2^0}   (Gold k=1; paper writes "x^4", likely typo for x^3)
#   F2(x) = x^5 = x^{2^2+2^0}   (Gold k=2)
#   F3(x) = x^9 = x^{2^3+2^0}   (Gold k=3)
#   F4(x) = x^17 = x^{2^4+2^0}  (Gold k=4)
#   F5(x) = x^33 = x^{2^5+2^0}  (Gold k=5)
#   F6(x) = x^3 + Tr_{GF(2^11)/GF(2)}(x^9)
#   Verify: is_quadratic_apn(Fi) for i=1..6
#   Verify: ortho-derivative differential spectra pairwise distinct (CCZ-inequivalence evidence)
# VBF API used: is_quadratic_apn, ortho_derivative, differential_spectrum
# Note: Table 3 is CONJECTURED (partial Algorithm 3 search; no exhaustive classification for n=11)
# Note: paper writes "x^4" as first entry; x^4=x^{2^2} is linear (DDT max=2^11), NOT APN.
#       Correct Gold k=1 representative is x^3=x^{2^1+1}. Treated as a typo in the paper.
# Note: modulus 2053 = x^11+x^2+1 (primitive); VBF has no conway_polynomial(11)

include(joinpath(@__DIR__, "helpers.jl"))

const N11  = 11
const MOD11 = 2053  # x^11+x^2+1, verified primitive (ord_2(2047)=11, 2^2047 ≡ 1 mod 2053)

# Tr_{GF(2^11)/GF(2)}(x^9): exponents 9·2^k mod (2^11-1) for k=0..10
const TR_X9_EXPS_N11 = let
    e     = 9
    ord   = (1 << N11) - 1        # 2047
    exps  = Int[]
    for _ in 0:N11-1
        push!(exps, e)
        e = (2 * e) % ord
    end
    exps
end

# Table 3 polynomial exponents (univariate over GF(2^11), modulus MOD11)
const TABLE3_EXPONENTS = [
    [3],                                    # x^3 = Gold k=1
    [5],                                    # x^5 = Gold k=2
    [9],                                    # x^9 = Gold k=3
    [17],                                   # x^17 = Gold k=4
    [33],                                   # x^33 = Gold k=5
    vcat([3], TR_X9_EXPS_N11),              # x^3 + Tr(x^9)
]

const TABLE3_LABELS = [
    "x^3 (Gold k=1; paper writes x^4)",
    "x^5 (Gold k=2)",
    "x^9 (Gold k=3)",
    "x^17 (Gold k=4)",
    "x^33 (Gold k=5)",
    "x^3 + Tr(x^9)",
]

function build_table3_sboxes(modulus::Int = MOD11)
    [polynomial_sbox(N11, exps; modulus = modulus) for exps in TABLE3_EXPONENTS]
end

function table3_report(io::IO = stdout)
    print_section(io, "Table 3: 6 CCZ-inequivalent representatives for n=11 (conjectured)")

    print_kv(io, "n", N11)
    print_kv(io, "modulus (x^11+x^2+1)", MOD11)
    print_kv(io, "Tr(x^9) exponents (n=11)", TR_X9_EXPS_N11)
    print_kv(io, "paper notation",
             "writes x^4 as first entry; x^3 used here (x^4 is linear, not APN)")
    print_kv(io, "completeness",
             "conjectured (partial Algorithm 3; 15 Magma scripts × 12 days)")

    mod   = MOD11
    boxes = build_table3_sboxes(mod)

    # Verify APN
    for (i, (F, lbl)) in enumerate(zip(boxes, TABLE3_LABELS))
        ok = is_quadratic_apn(F)
        print_check(io, "F$i = $lbl is quadratic APN over GF(2^11)", ok)
    end

    # Pairwise CCZ-inequivalence via ortho-derivative differential spectra
    t0 = time()
    spectra = [differential_spectrum(ortho_derivative(F)) for F in boxes]
    print_kv(io, "ortho-derivative spectra time (s)", round(time() - t0, digits = 2))

    all_distinct = true
    for i in 1:6, j in (i+1):6
        neq = spectra[i] != spectra[j]
        all_distinct &= neq
        neq || print_check(io, "F$i and F$j: ortho-derivative spectra COLLIDE (unexpected)", false)
    end
    print_check(io, "all 6 ortho-derivative spectra pairwise distinct (CCZ-inequivalence evidence)",
                all_distinct)
end

if abspath(PROGRAM_FILE) == @__FILE__
    table3_report()
end
