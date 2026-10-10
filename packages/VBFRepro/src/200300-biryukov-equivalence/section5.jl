# Implements Section 5 — Equivalent Descriptions of Various Ciphers.
# Paper: Biryukov et al. (2003), "A Toolbox for Cryptanalysis: Linear and Affine
#        Equivalence Algorithms", Eurocrypt 2003.
# Section: 5.2 — Other SPN Ciphers (Serpent, Khazad); Appendix B.2, Table 3
#
# Pseudocode:
#   Table 3 has six Serpent rows and one Khazad row; every row asserts that its
#   members form one affine equivalence class and shares one value of s.
#   1. Load Serpent S0..S7 from VBFCatalog, Khazad P/Q from helpers.jl.
#   2. Row {S0, S1^{-1}}     : S0 ~ S1^{-1}, s = 4.
#   3. Row {S0^{-1}, S1}     : S0^{-1} ~ S1, s = 4  (the inverse of row 2).
#   4. Row {S2,S2^{-1},S6,S6^{-1}} : all four mutually equivalent, s = 4.
#   5. Row {S3,S3^{-1},S7,S7^{-1}} : all four mutually equivalent, s = 1.
#   6. Row {S4, S5}          : S4 ~ S5, s = 1.
#   7. Row {S4^{-1}, S5^{-1}}: S4^{-1} ~ S5^{-1}, s = 1.
#   8. Row {P,P^{-1},Q,Q^{-1}} (Khazad): P and Q are involutions, so the row is
#      the single class of P; P ~ Q and s = 4.
#   9. Verify the rows are pairwise distinct classes (S0 ≁ S1; S2 ≁ S3;
#      S4 ≁ S6; Serpent ≁ Khazad).
# VBF API used: are_affine_equivalent, self_affine_equivalences, load_literature_sbox,
#               compositional_inverse

include(joinpath(@__DIR__, "helpers.jl"))

# Table 3, verbatim: (cipher, row label, members as name=>SBox, s).
function table3_rows()
    sp = load_serpent_sboxes()
    kz = khazad_sboxes()
    inv_(S) = compositional_inverse(S)
    [
        ("Serpent", "{S0, S1^{-1}}", ["S0" => sp.S0, "S1^{-1}" => inv_(sp.S1)], 4),
        ("Serpent", "{S0^{-1}, S1}", ["S0^{-1}" => inv_(sp.S0), "S1" => sp.S1], 4),
        (
            "Serpent",
            "{S2, S2^{-1}, S6, S6^{-1}}",
            ["S2" => sp.S2, "S2^{-1}" => inv_(sp.S2), "S6" => sp.S6, "S6^{-1}" => inv_(sp.S6)],
            4,
        ),
        (
            "Serpent",
            "{S3, S3^{-1}, S7, S7^{-1}}",
            ["S3" => sp.S3, "S3^{-1}" => inv_(sp.S3), "S7" => sp.S7, "S7^{-1}" => inv_(sp.S7)],
            1,
        ),
        ("Serpent", "{S4, S5}", ["S4" => sp.S4, "S5" => sp.S5], 1),
        ("Serpent", "{S4^{-1}, S5^{-1}}", ["S4^{-1}" => inv_(sp.S4), "S5^{-1}" => inv_(sp.S5)], 1),
        (
            "Khazad",
            "{P, P^{-1}, Q, Q^{-1}}",
            ["P" => kz.P, "P^{-1}" => inv_(kz.P), "Q" => kz.Q, "Q^{-1}" => inv_(kz.Q)],
            4,
        ),
    ]
end

function section5_report(io::IO = stdout)
    all_ok = true

    # --- Table 3 rows: members share one affine class and one value of s. ----
    print_section(io, "Section 5.2 / Appendix B.2 — Table 3 (Serpent and Khazad)")
    for (cipher, label, members, s_paper) in table3_rows()
        head = first(members)
        ok_class = all(are_affine_equivalent(head.second, m.second) for m in members)
        print_check(io, "$cipher $label — all members in one affine class", ok_class)
        counts = [length(self_affine_equivalences(m.second)) for m in members]
        ok_s = all(==(s_paper), counts)
        got = join(counts, ", ")
        print_check(io, "$cipher $label — s = $s_paper (got $got)", ok_s)
        all_ok &= ok_class && ok_s
    end

    # --- The rows are distinct classes. --------------------------------------
    print_section(io, "Section 5.2 — Table 3 rows are pairwise distinct classes")
    sp = load_serpent_sboxes()
    kz = khazad_sboxes()
    separations = [
        ("Serpent S0 ≁ S1 (equivalent only through the inverse)", sp.S0, sp.S1),
        ("Serpent S2 ≁ S3 (different rows)", sp.S2, sp.S3),
        ("Serpent S4 ≁ S6 (different rows)", sp.S4, sp.S6),
        ("Serpent S4 ≁ S4^{-1} (the two S4/S5 rows are distinct)", sp.S4, compositional_inverse(sp.S4)),
        ("Khazad P ≁ Serpent S0 (Khazad is its own row)", kz.P, sp.S0),
        ("Khazad P ≁ Serpent S2 (Khazad is its own row)", kz.P, sp.S2),
    ]
    for (label, Sa, Sb) in separations
        ok = !are_affine_equivalent(Sa, Sb)
        print_check(io, label, ok)
        all_ok &= ok
    end

    # --- Per-S-box s, as printed by the paper. -------------------------------
    print_section(io, "Section 5.2 — self-equivalence counts (s column, Table 3)")
    for (name, S) in [("Serpent S0", sp.S0), ("Serpent S1", sp.S1), ("Serpent S2", sp.S2),
                      ("Serpent S3", sp.S3), ("Serpent S4", sp.S4), ("Serpent S5", sp.S5),
                      ("Serpent S6", sp.S6), ("Serpent S7", sp.S7),
                      ("Khazad P", kz.P), ("Khazad Q", kz.Q)]
        print_kv(io, "  $name  s", length(self_affine_equivalences(S)))
    end
    print_kv(
        io,
        "paper Table 3 (expected s)",
        "Serpent S0:4, S1:4, S2:4, S6:4; S3:1, S7:1; S4:1, S5:1 — Khazad P:4, Q:4",
    )
    print_kv(
        io,
        "Khazad P, Q",
        "involutions (P^{-1} = P, Q^{-1} = Q), so the four-member row is one class",
    )
    print_kv(
        io,
        "not run",
        "Sect. 5.3 / Appendix B.1 (DES and S⁵DES 4x4 decompositions): the paper " *
        "defers those tables to its extended version, so there is no printed " *
        "target here to check (0 of 32+32 4x4 boxes evaluated)",
    )
    print_kv(io, "completeness", "exhaustive (all 7 Table 3 rows, 4-bit permutations)")

    return all_ok
end

if abspath(PROGRAM_FILE) == @__FILE__
    ok = section5_report()
    exit(ok ? 0 : 1)
end
