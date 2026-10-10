# Implements Theorem 4 — CCZ-class structure of V_A (cross-checks Table VII)
# Paper: Kuznetsov (2026), "Quadratic APN Functions in Dimension 8 via
#        Gröbner Basis Search in a Self-Equivalence Subspace",
#        IEEE Trans. Inf. Theory (2026) / arXiv:2606.11967
# Section: VI — CCZ Classification of APN Functions in V_A (Theorem 4)
#
# Pseudocode:
#   For each of the 6 CCZ-class representatives (Table VII):
#   1. Verify |LUT| = 256
#   2. Verify differential_uniformity = 2  (APN)
#   3. Verify algebraic_degree = 2          (quadratic)
#   4. Verify is_permutation (expected false for CLASS-A,B,C,D)
#   5. Verify V_A membership: in_va(lut, A_lut, A)
#      Paper states CLASS-A, E, F ∈ V_A;  CLASS-B, C, D ∉ V_A
# VBF API used: differential_uniformity, algebraic_degree, is_permutation,
#               SBox, print_section, print_check, print_kv

include("helpers.jl")

function theorem4_run()
    A     = build_A_matrix()
    A_lut = build_A_lut(A)

    sboxes = representative_sboxes()
    names  = [:class_a, :class_b, :class_c, :class_d, :class_e, :class_f]

    results = map(names) do name
        F    = getfield(sboxes, name)
        lut  = F.lut
        du   = differential_uniformity(F)
        deg  = algebraic_degree(F)
        perm = is_permutation(F)
        va   = in_va(lut, A_lut, A)
        (; name, du, deg, perm, va, n = length(lut))
    end

    (; results)
end

function theorem4_report(io::IO = stdout)
    r = theorem4_run()
    print_section("Theorem 4 — CCZ-class structure (Table VII S-box verification)", io)

    expected_va     = Dict(:class_a => true,  :class_b => false,
                           :class_c => false, :class_d => false,
                           :class_e => true,  :class_f => true)
    expected_perm   = Dict(:class_a => false, :class_b => false,
                           :class_c => false, :class_d => false,
                           :class_e => false, :class_f => false)

    for res in r.results
        nm = String(res.name)
        print_kv("class", uppercase(nm), io)
        print_check("  |LUT| = 256", res.n == 256, io)
        print_check("  APN (δ = 2)", res.du == 2, io)
        print_check("  degree = 2", res.deg == 2, io)
        print_check("  non-permutation", !res.perm == !expected_perm[res.name], io)
        exp_va = expected_va[res.name]
        print_check("  V_A membership = $exp_va", res.va == exp_va, io)
    end
end

if abspath(PROGRAM_FILE) == @__FILE__
    theorem4_report()
end
