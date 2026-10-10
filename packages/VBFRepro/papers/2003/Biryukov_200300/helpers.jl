# Implements shared utilities for Biryukov_200300 reproduction.
# Paper: Biryukov et al. (2003), "A Toolbox for Cryptanalysis: Linear and Affine
#        Equivalence Algorithms", Eurocrypt 2003.
# Section: shared helpers
#
# Pseudocode:
#   1. Load named S-boxes from VBFCatalog.
#   2. Carry the paper-local S-box tables that VBFCatalog does not hold
#      (Khazad P/Q mini-boxes, the 6x4-bit DES S4).
#   3. Print the report banner via the exported print_banner.
# VBF API used: load_literature_sbox, print_banner, SBox

using VBF
using VBFCatalog
using Dates

function load_aes_sbox()
    load_literature_sbox("AES")
end

function load_aes_inv_sbox()
    load_literature_sbox("AES_inv")
end

function load_serpent_sboxes()
    (
        S0 = load_literature_sbox("SERPENT_S0"),
        S1 = load_literature_sbox("SERPENT_S1"),
        S2 = load_literature_sbox("SERPENT_S2"),
        S3 = load_literature_sbox("SERPENT_S3"),
        S4 = load_literature_sbox("SERPENT_S4"),
        S5 = load_literature_sbox("SERPENT_S5"),
        S6 = load_literature_sbox("SERPENT_S6"),
        S7 = load_literature_sbox("SERPENT_S7"),
    )
end

# ----------------------------------------------------------------------------
# Paper-local S-box tables (absent from VBFCatalog's literature_sboxes.toml).
# ----------------------------------------------------------------------------

"""
    khazad_sboxes() -> (P = SBox{4}, Q = SBox{4})

The two 4x4-bit "mini-boxes" P and Q from which the 8x8-bit Khazad S-box is
built (Barreto & Rijmen, *The Khazad Legacy-Level Block Cipher*, NESSIE 2000 —
reference [2] of the paper).  Both are involutions, which is what makes the
composed Khazad S-box an involution; consequently `P^{-1} = P` and
`Q^{-1} = Q`, and Table 3's Khazad row `{P, P^{-1}, Q, Q^{-1}}` reduces to the
single affine class of `P`.

Kept paper-local rather than pushed into `VBFCatalog`: these are internal
components of a cipher's S-box, not an S-box any cipher applies directly.
"""
function khazad_sboxes()
    (
        P = SBox{4}([0x3, 0xF, 0xE, 0x0, 0x5, 0x4, 0xB, 0xC,
                     0xD, 0xA, 0x9, 0x6, 0x7, 0x8, 0x2, 0x1]),
        Q = SBox{4}([0x9, 0xE, 0x5, 0x6, 0xA, 0x2, 0x3, 0xC,
                     0xF, 0x0, 0x4, 0xD, 0x7, 0xB, 0x1, 0x8]),
    )
end

# DES S4, in the FIPS 46-3 row/column layout: four rows of sixteen entries.
const DES_S4_ROWS = [
    [7, 13, 14, 3, 0, 6, 9, 10, 1, 2, 8, 5, 11, 12, 4, 15],
    [13, 8, 11, 5, 6, 15, 0, 3, 4, 7, 2, 12, 1, 10, 14, 9],
    [10, 6, 9, 0, 12, 11, 7, 13, 15, 1, 3, 14, 5, 2, 8, 4],
    [3, 15, 0, 6, 10, 1, 13, 8, 9, 4, 5, 11, 12, 7, 2, 14],
]

"""
    des_s4_lut() -> Vector{Int}

The 6-to-4-bit DES S-box `S4` flattened to a 64-entry lookup table indexed by
the raw input `x = b1 b2 b3 b4 b5 b6` (b1 the most significant bit).  Per FIPS
46-3 the outer bits select the row (`r = 2*b1 + b6`) and the inner four bits
select the column (`c = b2 b3 b4 b5`).

Not an `SBox`: `SBox{N}` models n-to-n-bit maps, and this one is 6-to-4.
"""
function des_s4_lut()
    lut = Vector{Int}(undef, 64)
    for x = 0:63
        r = 2 * ((x >> 5) & 1) + (x & 1)
        c = (x >> 1) & 0xF
        lut[x+1] = DES_S4_ROWS[r+1][c+1]
    end
    lut
end

# ----------------------------------------------------------------------------
# Report banner.
# ----------------------------------------------------------------------------

function print_header(io::IO = stdout)
    print_banner(
        io,
        "Biryukov, De Cannière, Braeken, Preneel (2003)",
        "A Toolbox for Cryptanalysis: Linear and Affine Equivalence Algorithms",
        "Eurocrypt 2003  |  Julia $(VERSION)  |  $(today())",
    )
    println(io)
    println(io, "  Scope:")
    println(io, "    EXACT      — Section 2 (LE correctness), Section 3 (AE/representative),")
    println(io, "                 Section 4.1 (Rijndael 2040, constructive), Section 4.2 (DES S4),")
    println(io, "                 Section 5.1-5.2 (Serpent + Khazad, Table 3),")
    println(io, "                 Section 6 (Even-Mansour key recovery), Section 7 (Table 1),")
    println(io, "                 Appendix A (Table 2), Appendix B.2 (Table 4),")
    println(io, "                 Appendix C (Table 5 class counts, n≤3)")
    println(io, "    OPT-IN     — exhaustive s counts: the GF(2^7) power map 889 (~380 s) and")
    println(io, "                 Rijndael 2040 (2^16 LE searches, tens of minutes);")
    println(io, "                 Table 5 n=3 (8! perms, ~50 s)")
    println(io, "    NOT RUN    — Sect. 3.3 (birthday AE), Sect. 4.2 (the 28 DES S-box pairs),")
    println(io, "                 Sect. 4.3 (almost equivalence), Sect. 5.3 / App. B.1 (DES and")
    println(io, "                 S⁵DES 4x4 decompositions); each section prints its own reason")
    println(io)
end

