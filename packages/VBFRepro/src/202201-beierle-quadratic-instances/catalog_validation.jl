# Implements catalog cross-validation against the VBFCatalog bulk corpus.
# Paper: Beierle, Leander (2022), "New Instances of Quadratic APN Functions",
#        IEEE Trans. Inf. Theory 68(1):670–678 / arXiv:2009.07204
# Section: Results — catalog-cross-validation
#
# NOTE: This is the ONLY file in packages/VBFRepro/src/202201-beierle-quadratic-instances/ permitted to import
#       VBFCatalog (architecture rule: VBF must never import VBFCatalog).
#
# VBF API used: SBox (via VBFCatalog)
# VBFCatalog API used: load_catalog, list_corpora, corpus_length, corpus_function

include(joinpath(@__DIR__, "helpers.jl"))

using VBFCatalog

const _CORPUS_N8  = "beierleleander2022_n8"
# The catalog was built from sboxU's BeierleLeander.py (12923 functions), which
# contains 2 more entries than the paper's apn_8bit.txt artifact (12921 lines).
# The two additional catalog entries are quadratic-APN functions present in the
# sboxU Python database but absent from the author-released TXT file.
const _EXPECTED_N8 = 12923

"""
    catalog_cross_check(io; sample_size) -> NamedTuple

Cross-check the dim-8 corpus in VBFCatalog against apn_8bit.txt.
Gracefully handles absent dim-9/10 corpora.
Beierle–Leander (2022), Results — catalog-cross-validation.
"""
function catalog_cross_check(io::IO = stdout; sample_size::Int = 20)
    print_section("catalog-cross-validation", io)
    cat = load_catalog()
    available = list_corpora(cat)
    print_kv("available corpora", available, io)

    # ── dim-8 ────────────────────────────────────────────────────────────────
    if !(_CORPUS_N8 in available)
        print_check("corpus '$_CORPUS_N8' found in catalog", false, io)
        println(io, "  Skipping dim-8 cross-check — corpus not present in catalog.")
        return (; n8_found=false, n8_length_ok=false, n8_sample_ok=false)
    end
    print_check("corpus '$_CORPUS_N8' found in catalog", true, io)

    len = corpus_length(cat, _CORPUS_N8)
    len_ok = len == _EXPECTED_N8
    print_kv("corpus length", len, io)
    print_kv("expected length", _EXPECTED_N8, io)
    print_check("corpus length == $_EXPECTED_N8", len_ok, io)

    # Sample: compare first sample_size functions from the file vs. corpus.
    path8 = joinpath(@__DIR__, "inputs", "apn_8bit.txt")
    if !isfile(path8)
        print_kv("cross-check", "INCONCLUSIVE: original apn_8bit.txt unavailable; corpus presence is not source validation", io)
        return (; n8_found = true, n8_length_ok = len_ok, n8_sample_ok = missing, status = :unavailable)
    end
    n_compare = min(sample_size, len, _EXPECTED_N8)
    mismatches = 0
    file_sboxes = SBox[]
    for f in stream_dataset(path8; limit = n_compare)
        push!(file_sboxes, f)
    end
    for i in 1:length(file_sboxes)
        cat_f = corpus_function(cat, _CORPUS_N8, i)
        if cat_f.lut != file_sboxes[i].lut
            mismatches += 1
        end
    end
    sample_ok = mismatches == 0
    print_kv("sampled", length(file_sboxes), io)
    print_kv("mismatches", mismatches, io)
    print_check(
        "first $(length(file_sboxes)) LUTs match between file and corpus",
        sample_ok,
        io,
    )

    # ── dim-9 and dim-10 (may be absent) ────────────────────────────────────
    for (corpus_name, n) in [("beierleleander2022_n9", 9), ("beierleleander2022_n10", 10)]
        if corpus_name in available
            l = corpus_length(cat, corpus_name)
            println(io, "  Note: corpus '$corpus_name' found (length=$l) — skipping detailed check.")
        else
            println(io, "  Note: corpus '$corpus_name' (n=$n) not present in catalog — skipping (expected per PLAN.md).")
        end
    end

    return (; n8_found=true, n8_length_ok=len_ok, n8_sample_ok=sample_ok)
end
