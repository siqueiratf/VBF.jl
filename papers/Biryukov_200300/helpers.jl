# Implements shared utilities for Biryukov_200300 reproduction.
# Paper: Biryukov et al. (2003), "A Toolbox for Cryptanalysis: Linear and Affine
#        Equivalence Algorithms", Eurocrypt 2003.
# Section: shared helpers
#
# Pseudocode:
#   1. Load named S-boxes from VBFCatalog.
#   2. Provide print_header / print_section / print_check / print_kv helpers.
# VBF API used: load_literature_sbox

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

function print_header(io::IO = stdout)
    println(
        io,
        "# Biryukov et al. (2003) — A Toolbox for Cryptanalysis: Linear and Affine Equivalence Algorithms",
    )
    println(io, "  Julia $(VERSION)  |  $(today())")
    println(io)
    println(io, "  Scope:")
    println(io, "    EXACT      — Section 2 (LE correctness), Section 3 (AE/representative),")
    println(io, "                 Section 5 (Serpent Table 3)")
    println(
        io,
        "    OPT-IN     — Section 4.1 Rijndael 2040 (full_search=true or 'rijndael_2040' target)",
    )
    println(
        io,
        "    OUT-OF-SCOPE — non-bijective (DES/Khazad), Misty/Kasumi, Secs 4.2-4.3/6/7",
    )
    println(io)
end

