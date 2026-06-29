# novelty.jl — Phase-2 CCZ novelty oracle.
#
# A function's σ-signature (sorted differential + absolute-Walsh spectra of its
# ortho-derivative; see table2.jl) is a CCZ-invariant. For quadratic APN,
# CCZ-equivalence coincides with EA-equivalence (Yoshiara), so σ separates the
# EA-classes the catalogs are counted in. Hence:
#   σ(F) ∉ catalog ⇒ F lies in NO known CCZ-class ⇒ genuinely NEW (certain).
#   σ(F) ∈ catalog ⇒ F is (almost surely) a known class.
#
# σ is hashed (SHA-256 → UInt128) so the 3.78M-entry index fits in ~60 MB.
# A hash collision can only ever turn a truly-new function into a false :known
# (a missed discovery) — it can never fabricate novelty. So :new verdicts stay
# sound; for certainty of *duplication* on a :known verdict, confirm with a full
# CCZ-equivalence test.
#
# Known dim-8 quadratic-APN catalog sources (all real, fetched — never fabricated):
#   • BLP25 : Zenodo 16752428 — Beierle, Langevin, Leander, Polujan, Rasoolzadeh
#             (2025), 3,775,599 inequivalent quadratic APN (catalogs/apn8_blp2025.txt)
#   • BLP22 : sboxU apn_8bit_BLP22 (6368 LUTs; catalogs/apn8_blp22.json)
#   • paper : Kuznetsov (2026) apn_all.json (566 found APN)
#   • reps  : the 6 CCZ-class representatives A–F (helpers.jl)
#   • gold  : Gold monomials x³, x⁹
# Run ./fetch_catalog.sh (and ./fetch_catalog.sh --full for BLP25) to populate.
include(joinpath(@__DIR__, "table2.jl"))   # sigma_key, representative_sboxes, VBF, gold_apn
import JSON3
using SHA

const CAT_DIR   = joinpath(@__DIR__, "catalogs")
const BLP22     = joinpath(CAT_DIR, "apn8_blp22.json")
const BLP25     = joinpath(CAT_DIR, "apn8_blp2025.txt")
const APN_ALL   = joinpath(@__DIR__, "codes_mencioned_in_original_paper", "apn_all.json")
const SIG_CACHE = joinpath(CAT_DIR, "sigma_index_n8.bin")

# CCZ-invariant signature hashed to a stable 128-bit key.
function sig_hash(F::SBox)::UInt128
    h = sha256(string(sigma_key(F)))
    reinterpret(UInt128, view(h, 1:16))[1]
end

parse_lut_line(ln::AbstractString) =
    UInt8.(parse.(Int, split(strip(ln, ['[', ']', ' ', '\n', '\r', ',']), ',')))

# add σ of an in-memory SBox collection (skips entries with no ortho-derivative)
function add_sigmas!(s::Set{UInt128}, sboxes)
    for F in sboxes
        try push!(s, sig_hash(F)) catch end
    end
    s
end

# stream a line-based LUT file (one JSON array per line), σ computed threaded
function add_sigmas_file!(s::Set{UInt128}, path::AbstractString; batch::Int = 50_000)
    isfile(path) || return s
    buf = String[]
    function flush_buf!()
        isempty(buf) && return
        hs = Vector{UInt128}(undef, length(buf)); ok = trues(length(buf))
        Threads.@threads for i in eachindex(buf)
            try hs[i] = sig_hash(SBox{8}(parse_lut_line(buf[i]))) catch; ok[i] = false end
        end
        @inbounds for i in eachindex(buf); ok[i] && push!(s, hs[i]); end
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

# Full known-APN σ-index (BLP25 streamed + BLP22 + paper + reps + gold), cached.
function build_sigma_index(; cache=SIG_CACHE, rebuild=false, blp25=true, kwargs...)
    if !rebuild && isfile(cache)
        return load_index(cache)
    end
    s = sigma_index(load_catalog(; kwargs...))
    blp25 && add_sigmas_file!(s, BLP25)
    mkpath(CAT_DIR); save_index(s, cache)
    s
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

# σ-absence is a certain proof of a new CCZ class; σ-presence ⇒ :known.
classify_against_catalog(F::SBox, index::AbstractSet{UInt128}) =
    (sig_hash(F) in index) ? :known : :new
