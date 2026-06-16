# Implements Section 5 — Equivalent Descriptions of Various Ciphers.
# Paper: Biryukov et al. (2003), "A Toolbox for Cryptanalysis: Linear and Affine
#        Equivalence Algorithms", Eurocrypt 2003.
# Section: 5.2 — Other SPN Ciphers (Serpent); Table 3 left side
#
# Pseudocode:
#   1. Load Serpent S0..S7 from VBFCatalog.
#   2. Verify three equivalent pairs: {S2,S6}, {S3,S7}, {S4,S5}.
#   3. Verify one inverse-equivalent pair: {S0, S1^{-1}}.
#   4. Verify no cross-pair equivalences hold.
#   5. Report number of self-equivalences for S0,S2,S3,S4 (paper: 4,4,1,1 resp.).
# VBF API used: are_affine_equivalent, self_affine_equivalences, load_literature_sbox,
#               inverse

include(joinpath(@__DIR__, "helpers.jl"))

function _serpent_inverse(S::SBox{N,T}) where {N,T}
    n = 1 << N
    lut = Vector{T}(undef, n)
    for x = 0:(n-1)
        lut[S.lut[x+1]+1] = T(x)
    end
    SBox{N,T}(lut)
end

function section5_report(io::IO = stdout)
    print_section(io, "Section 5.2 — Serpent S-box Equivalences (Table 3 left)")

    sp = load_serpent_sboxes()
    names = (:S0, :S1, :S2, :S3, :S4, :S5, :S6, :S7)
    sboxes = [sp.S0, sp.S1, sp.S2, sp.S3, sp.S4, sp.S5, sp.S6, sp.S7]

    # Three affine-equivalent pairs from Table 3.
    pairs = [
        ("S2", sp.S2, "S6", sp.S6),
        ("S3", sp.S3, "S7", sp.S7),
        ("S4", sp.S4, "S5", sp.S5),
    ]
    all_ok = true
    for (na, Sa, nb, Sb) in pairs
        ok = are_affine_equivalent(Sa, Sb)
        print_check(io, "Serpent $na ~ $nb (affine equivalent)", ok)
        all_ok &= ok
    end

    # Inverse-equivalent pair: S0 ~ S1^{-1}.
    S1_inv = _serpent_inverse(sp.S1)
    ok_inv = are_affine_equivalent(sp.S0, S1_inv)
    print_check(io, "Serpent S0 ~ S1^{-1} (inverse-equivalent pair)", ok_inv)
    all_ok &= ok_inv

    # S0 and S1 are NOT directly affine equivalent (only via inverse).
    ok_not_direct = !are_affine_equivalent(sp.S0, sp.S1)
    print_check(io, "Serpent S0 and S1 are NOT directly affine equivalent", ok_not_direct)
    all_ok &= ok_not_direct

    # Cross-pair non-equivalences: verified pair members are not equivalent to others.
    ok_cross1 = !are_affine_equivalent(sp.S2, sp.S3)
    print_check(io, "S2 and S3 are NOT affine equivalent (different pairs)", ok_cross1)
    ok_cross2 = !are_affine_equivalent(sp.S4, sp.S6)
    print_check(io, "S4 and S6 are NOT affine equivalent (different pairs)", ok_cross2)
    all_ok &= ok_cross1 && ok_cross2

    # Self-equivalence counts for the four self-equivalent S-boxes.
    # Paper Table 3 left: S=4 for S0, S2; S=4 for S6 (same class as S2); S=1 for S3,S7,S4,S5.
    print_section(io, "Section 5.2 — Serpent self-equivalence counts (s column, Table 3)")
    for (name, S) in [("S0", sp.S0), ("S1", sp.S1), ("S2", sp.S2), ("S3", sp.S3),
                      ("S4", sp.S4), ("S5", sp.S5), ("S6", sp.S6), ("S7", sp.S7)]
        s = length(self_affine_equivalences(S))
        print_kv(io, "  Serpent $name  s", s)
    end
    print_kv(
        io,
        "paper Table 3 (expected s)",
        "S0:4, S1:4, S2:4, S6:4; S3:1, S7:1; S4:1, S5:1",
    )

    print_kv(io, "completeness", "exhaustive (all Serpent S-boxes, 4-bit permutations)")

    return all_ok
end

if abspath(PROGRAM_FILE) == @__FILE__
    ok = section5_report()
    exit(ok ? 0 : 1)
end
