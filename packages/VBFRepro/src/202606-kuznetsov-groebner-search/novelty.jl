# novelty.jl — Phase-2 CCZ novelty oracle.
#
# Historical local signature helpers. A mismatch separates quadratic APNs
# only from the functions actually indexed; a match requires an exact witness.
# Neither a partial corpus nor a hash-only cache certifies literature novelty.
# Use VBFCatalog's coverage-aware APIs for corpus comparisons.
using SHA
using JSON3

include(joinpath(@__DIR__, "table2.jl"))   # sigma_key, representative_sboxes, VBF, gold_apn
include(joinpath(@__DIR__, "anf.jl"))      # ANF: compact .anf catalog storage
using .ANF

const CAT_DIR   = joinpath(@__DIR__, "catalogs")
const BLP22     = joinpath(CAT_DIR, "apn8_blp22.json")
const BLP25     = joinpath(CAT_DIR, "apn8_blp2025.txt")   # 3.4 GB decimal text (raw download)
const BLP25_ANF = joinpath(CAT_DIR, "apn8_blp2025.anf")   # 139 MB ANF-packed (preferred)
const BL2021    = joinpath(CAT_DIR, "bl2021_8bit.txt")    # Beierle–Leander 2021, 12921 LUTs
const BL2021_ANF = joinpath(CAT_DIR, "bl2021_8bit.anf")   # ANF-packed (preferred)
const PRE2025   = joinpath(CAT_DIR, "known_pre2025_qam.txt")  # sboxU pre-2025: BeierleLeander
                                                              # + first/second QAM + WengTanGon (26524)
const APN_ALL   = joinpath(@__DIR__, "codes_mencioned_in_original_paper", "apn_all.json")
const SIG_CACHE = joinpath(CAT_DIR, "sigma_index_n8.bin")
const APN7      = joinpath(CAT_DIR, "apn7_known.json")    # 488 known dim-7 quadratic APN reps

# CCZ-invariant signature hashed to a stable 128-bit key.
function sig_hash(F::SBox)::UInt128
    h = sha256(string(sigma_key(F)))
    reinterpret(UInt128, view(h, 1:16))[1]
end
# parse_lut_line provided by the ANF module (delimiter-agnostic)

# add σ of an in-memory SBox collection; malformed inputs fail closed
function add_sigmas!(s::Set{UInt128}, sboxes)
    for F in sboxes
        push!(s, sig_hash(F))
    end
    s
end

# stream a line-based LUT file (one JSON array per line), σ computed threaded
function add_sigmas_file!(s::Set{UInt128}, path::AbstractString; batch::Int = 50_000)
    isfile(path) || throw(ArgumentError("missing signature source: $path"))
    buf = String[]
    function flush_buf!()
        isempty(buf) && return
        hs = Vector{UInt128}(undef, length(buf)); ok = trues(length(buf))
        Threads.@threads for i in eachindex(buf)
            try hs[i] = sig_hash(SBox{8}(parse_lut_line(buf[i]))) catch; ok[i] = false end
        end
        all(ok) || error("invalid function in signature source $path; refusing a partial index")
        @inbounds for i in eachindex(buf); push!(s, hs[i]); end
        empty!(buf)
    end
    for ln in eachline(path)
        isempty(strip(ln)) && continue
        push!(buf, ln)
        length(buf) >= batch && flush_buf!()
    end
    flush_buf!()
    s
end

# stream an ANF-packed .anf catalog, σ computed threaded over batches
function add_sigmas_anf!(s::Set{UInt128}, path::AbstractString; batch::Int = 50_000)
    isfile(path) || throw(ArgumentError("missing signature source: $path"))
    buf = Vector{Vector{UInt8}}()
    function flush_buf!()
        isempty(buf) && return
        hs = Vector{UInt128}(undef, length(buf)); ok = trues(length(buf))
        Threads.@threads for i in eachindex(buf)
            try hs[i] = sig_hash(SBox{8}(buf[i])) catch; ok[i] = false end
        end
        all(ok) || error("invalid function in signature source $path; refusing a partial index")
        @inbounds for i in eachindex(buf); push!(s, hs[i]); end
        empty!(buf)
    end
    ANF.foreach_anf_lut(path) do lut
        push!(buf, lut)
        length(buf) >= batch && flush_buf!()
    end
    flush_buf!()
    s
end

# in-memory catalog (small sources only: BLP22 json, paper, reps, gold)
function load_catalog(; blp22=true, paper=true, reps=true, gold=true)
    cat = SBox{8}[]
    if blp22 && isfile(BLP22)
        for lut in JSON3.read(read(BLP22, String)).luts
            push!(cat, SBox{8}(UInt8.(collect(lut))))
        end
    end
    if paper && isfile(APN_ALL)
        for f in JSON3.read(read(APN_ALL, String)).functions
            push!(cat, SBox{8}(UInt8.(collect(f.sbox))))
        end
    end
    if reps
        r = representative_sboxes()
        for nm in (:class_a, :class_b, :class_c, :class_d, :class_e, :class_f)
            push!(cat, getfield(r, nm))
        end
    end
    gold && (push!(cat, gold_apn(8, 1)); push!(cat, gold_apn(8, 3)))
    cat
end

# σ-index over the small in-memory sources
sigma_index(catalog::AbstractVector{<:SBox}) = add_sigmas!(Set{UInt128}(), catalog)

# Historical local cache, without source provenance; not a novelty certificate.
function build_sigma_index(; cache=SIG_CACHE, rebuild=false, blp25=true, kwargs...)
    if !rebuild && isfile(cache)
        return load_index(cache)
    end
    s = sigma_index(load_catalog(; kwargs...))
    add_sigmas_source!(s, BL2021_ANF, BL2021)          # Beierle–Leander 2021 (12921)
    add_sigmas_file!(s, PRE2025)                        # pre-2025 QAM/BeierleLeander/WTG (26524)
    blp25 && add_sigmas_source!(s, BLP25_ANF, BLP25)   # Beierle et al. 2025 (3.78M)
    mkpath(CAT_DIR); save_index(s, cache)
    s
end

# add a catalog's σ, preferring the compact .anf over the raw decimal text
function add_sigmas_source!(s::Set{UInt128}, anf_path, txt_path)
    isfile(anf_path) ? add_sigmas_anf!(s, anf_path) :
    isfile(txt_path) ? add_sigmas_file!(s, txt_path) :
    throw(ArgumentError("missing signature source: $anf_path or $txt_path"))
end

function save_index(s::Set{UInt128}, path)
    v = sort!(collect(s))
    open(path, "w") do io
        write(io, UInt64(length(v))); write(io, v)
    end
end
function load_index(path)::Set{UInt128}
    open(path) do io
        n = read(io, UInt64); v = Vector{UInt128}(undef, n); read!(io, v); Set(v)
    end
end

# Scope-limited invariant comparison: positive equivalence is not inferred.
function classify_against_catalog(F::SBox, index::AbstractSet{UInt128})
    algebraic_degree(F) == 2 && differential_uniformity(F) == 2 ||
        throw(ArgumentError("signature comparison requires quadratic APN functions"))
    isempty(index) && return :inconclusive
    (sig_hash(F) in index) ? :signature_match : :signature_absent
end

# build a σ-index from a JSON {"luts":[...]} catalog of n-bit LUTs (n via Val(N)).
# Generic over dimension — used for the dim-7 known catalog (apn7_known.json).
function known_sigma_index(json_path::AbstractString, ::Val{N}) where {N}
    s = Set{UInt128}()
    isfile(json_path) || throw(ArgumentError("missing signature source: $json_path"))
    for l in JSON3.read(read(json_path, String)).luts
        push!(s, sig_hash(SBox{N}(UInt8.(collect(l)))))
    end
    s
end
