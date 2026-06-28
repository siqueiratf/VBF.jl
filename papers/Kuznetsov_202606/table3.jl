# Implements Table III — CCZ-Class vs. V_A Membership
# Paper: Kuznetsov (2026), "Quadratic APN Functions in Dimension 8 via
#        Gröbner Basis Search in a Self-Equivalence Subspace",
#        IEEE Trans. Inf. Theory (2026) / arXiv:2606.11967
# Section: VI.C — Membership of APN classes in V_A (Table III)
#
# Pseudocode:
#   For each of the 6 CCZ-class representatives:
#   1. Check in_va(F, A_lut, A)
#   2. Report membership: CLASS-A, E, F ∈ V_A;  CLASS-B, C, D ∉ V_A
# VBF API used: SBox, print_section, print_check, print_kv

include("helpers.jl")

function table3_run()
    A     = build_A_matrix()
    A_lut = build_A_lut(A)
    sb    = representative_sboxes()
    names = [:class_a, :class_b, :class_c, :class_d, :class_e, :class_f]

    # Paper Theorem 4: A and E,F inside V_A; B,C,D outside
    expected = Dict(
        :class_a => true,
        :class_b => false,
        :class_c => false,
        :class_d => false,
        :class_e => true,
        :class_f => true,
    )

    rows = map(names) do name
        F  = getfield(sb, name)
        va = in_va(F.lut, A_lut, A)
        (; name, va, expected = expected[name], correct = va == expected[name])
    end

    all_correct = all(r.correct for r in rows)
    (; rows, all_correct)
end

function table3_report(io::IO = stdout)
    r = table3_run()
    print_section("Table III — CCZ-Class vs. V_A Membership", io)
    print_kv("A", "block_diag(C(q), C(q)), ord(A) = 5", io)
    for row in r.rows
        nm  = uppercase(String(row.name))
        exp = row.expected ? "∈ V_A" : "∉ V_A"
        ok  = row.correct
        print_check("$nm: $exp", ok, io)
    end
    print_check("all membership results match paper (Theorem 4)", r.all_correct, io)
end

if abspath(PROGRAM_FILE) == @__FILE__
    table3_report()
end
