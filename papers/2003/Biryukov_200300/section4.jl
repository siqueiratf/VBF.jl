# Implements Section 4.1 — Self-Equivalent S-Boxes (Rijndael claim).
# Paper: Biryukov et al. (2003), "A Toolbox for Cryptanalysis: Linear and Affine
#        Equivalence Algorithms", Eurocrypt 2003.
# Section: 4.1 — Self-Equivalent S-Boxes; 5.1 — Rijndael
#
# Pseudocode:
#   1. (fast path) Report paper claim: Rijndael S-box has 2040 affine self-equivalences.
#   2. (full_search=true) Compute self_affine_equivalences(AES) and verify count == 2040.
#      The algebraic explanation: A1(x) = [a]·Q^i·x, A2(x) = A(Q^{-i}·[a]·A^{-1}(x))
#      with 0 ≤ i < 8 and a ∈ GF(2^8)\{0} gives 8×255 = 2040 pairs.
# VBF API used: self_affine_equivalences, load_literature_sbox

include(joinpath(@__DIR__, "helpers.jl"))

const RIJNDAEL_EXPECTED_SELF_EQUIV = 2040

function section4_report(io::IO = stdout; full_search::Bool = false)
    print_section(io, "Section 4.1 — Self-Equivalent S-Boxes / Section 5.1 Rijndael")

    print_kv(
        io,
        "paper claim",
        "Rijndael S-box has $RIJNDAEL_EXPECTED_SELF_EQUIV affine self-equivalences",
    )
    print_kv(
        io,
        "algebraic explanation",
        "A1 = [a]·Q^i, A2 = A(Q^{-i}·[a]·A^{-1}) for i∈0..7, a∈GF(2^8)\\{0} → 8×255=2040",
    )

    if full_search
        aes = load_aes_sbox()
        t0 = time()
        equivs = self_affine_equivalences(aes)
        elapsed = time() - t0
        count = length(equivs)
        ok = count == RIJNDAEL_EXPECTED_SELF_EQUIV
        print_check(
            io,
            "self_affine_equivalences(AES) == $RIJNDAEL_EXPECTED_SELF_EQUIV (got $count)",
            ok,
        )
        print_kv(io, "elapsed", "$(round(elapsed; digits=1))s")
        print_kv(io, "completeness", "exhaustive (2^16 LE searches over GF(2^8)×GF(2^8))")
        return ok
    else
        println(io, "  [SKIP] full_search=false; run with full_search=true or 'rijndael_2040' target")
        print_kv(io, "note", "2040 is transcribed from Table 4; not confirmed in the default run (~580s here)")
        print_kv(io, "completeness", "budget-limited (0 evaluated)")
        return true
    end
end

if abspath(PROGRAM_FILE) == @__FILE__
    full = lowercase(get(ENV, "FULL_SEARCH", "false")) == "true"
    ok = section4_report(; full_search = full)
    exit(ok ? 0 : 1)
end
