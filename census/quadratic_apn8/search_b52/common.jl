# Implements shared paths, the novelty oracle and function helpers of the B6 = 52 search
# Study: B6 = 52 extension search (census/quadratic_apn8/search_b52)
#
# Math:
#   sigma (ortho-derivative signature, VBFCatalog.sigma_hash) is a CCZ invariant of
#   quadratic APN functions. A sigma that is absent from ccz_sigma_index certifies a class
#   that is absent from the indexed corpora. Equal sigma does not prove equivalence, so a
#   "known" verdict can (rarely) hide a new class; the counts of new classes are therefore
#   lower bounds.
#
# Pseudocode:
#   index_set(): read all n = 8 sigma hashes of ccz_sigma_index once (refuse when the
#     coverage table has gaps at n = 8), store them as a sorted Vector{NTuple{2,UInt128}}
#     in results/index/sigma_n8.bin, and reuse that cache when it is newer than the store.
#   census_new_set(): the 553 sigma of ../new_classes_553.tsv.
#   function_of(G, S): coefficients, LUT and SBox of the function with component space S
#     (basis = the RREF rows of S, in order).
# VBF API used: SBox, differential_uniformity
# VBFCatalog API used: sigma_hash, sigma_index_path, _open_sigma_index, _sigma_gaps

using VBF, VBFCatalog, Printf, Dates
isdefined(@__MODULE__, :Ext) || include(joinpath(@__DIR__, "extlib.jl"))
using .Ext

const STUDY_DIR = @__DIR__
const CENSUS_DIR = normpath(joinpath(@__DIR__, ".."))
const RESULTS_DIR = joinpath(@__DIR__, "results")
const HIT_PROPERTIES = joinpath(CENSUS_DIR, "reports", "properties", "hit_properties.tsv")
const NEW553 = joinpath(CENSUS_DIR, "new_classes_553.tsv")
const INDEX_CACHE = joinpath(RESULTS_DIR, "index", "sigma_n8.bin")
const DBI = VBFCatalog.DBInterface

const SigmaBits = NTuple{2,UInt128}
sigma_bits(h::AbstractString) = (parse(UInt128, h[1:32], base = 16), parse(UInt128, h[33:64], base = 16))
sigma_hex(b::SigmaBits) = string(b[1], base = 16, pad = 32) * string(b[2], base = 16, pad = 32)

"Sorted sigma set (binary search) with membership by `in`."
struct SortedSigma
    v::Vector{SigmaBits}
end
Base.in(x::SigmaBits, s::SortedSigma) = (i = searchsortedfirst(s.v, x); i <= length(s.v) && s.v[i] == x)
Base.length(s::SortedSigma) = length(s.v)

"""
    index_set(; rebuild=false, io=stdout) -> SortedSigma

All n = 8 sigma hashes of the VBFCatalog side store `ccz_sigma_index.sqlite`. Uses the
binary cache results/index/sigma_n8.bin when it is newer than the store.
"""
function index_set(; rebuild::Bool = false, io::IO = stdout)
    store = VBFCatalog.sigma_index_path()
    isfile(store) || error("sigma index not found at $store (see README: data files)")
    if !rebuild && isfile(INDEX_CACHE) && mtime(INDEX_CACHE) > mtime(store)
        n = filesize(INDEX_CACHE) ÷ 32
        v = Vector{SigmaBits}(undef, n)
        open(io_ -> read!(io_, v), INDEX_CACHE)
        println(io, "sigma index: $(n) distinct n=8 hashes (cache $(INDEX_CACHE))")
        return SortedSigma(v)
    end
    idx = VBFCatalog._open_sigma_index()
    gaps = VBFCatalog._sigma_gaps(idx, 8)
    isempty(gaps) || error("sigma index has coverage gaps at n=8: $gaps; 'new' would not be certified")
    t = @elapsed begin
        v = SigmaBits[]
        sizehint!(v, 4_100_000)
        for r in DBI.execute(idx, "SELECT sigma_hash FROM ccz_sigma_index WHERE n = 8")
            push!(v, sigma_bits(String(r.sigma_hash)))
        end
        sort!(v); unique!(v)
    end
    close(idx)
    mkpath(dirname(INDEX_CACHE))
    tmp = INDEX_CACHE * ".tmp"
    open(io_ -> write(io_, v), tmp, "w"); mv(tmp, INDEX_CACHE; force = true)
    println(io, @sprintf("sigma index: %d distinct n=8 hashes read from %s in %.1f s (cached)", length(v), store, t))
    SortedSigma(v)
end

"The 553 sigma of the census (new_classes_553.tsv: sigma<TAB>coeffs)."
census_new_set() = Set(sigma_bits(split(l, '\t')[1]) for l in eachline(NEW553) if !isempty(l))

"Function with component space S (basis = RREF rows of S): (coeffs, SBox{n})."
function function_of(G::Geometry, S::AbstractVector{UInt32})
    c = forms_to_coeffs(S, G.N)
    lut = lut_from_coeffs(G, c)
    c, SBox{G.n}(UInt8.(lut))
end

"Maximum number of bent elements of a k-dim subspace of Comp(F) (and how many reach it)."
function max_bent_dim(comp::Vector{UInt32}, bent::BitVector, k::Int)
    best = Ref(0); nbest = Ref(0)
    subspaces_of_comp(comp, bent, k; keep = nb -> begin
        nb > best[] ? (best[] = nb; nbest[] = 1) : (nb == best[] && (nbest[] += 1)); false
    end)
    best[], nbest[]
end

"Seeds of the B6 = 52 branch from hit_properties.tsv: new hits first, then known hits."
function seed_rows(; b6::Int = 52)
    rows = [split(l, '\t') for l in eachline(HIT_PROPERTIES)]
    hdr = rows[1]; rows = rows[2:end]
    col(name) = findfirst(==(name), hdr)
    ip = col("P6_bminK"); is = col("status"); ih = col("sigma_hash"); ic = col("coeffs")
    sel = filter(p -> parse(Int, match(r"\((\d+),\d+\)\]$", p[ip])[1]) == b6, rows)
    newfirst = vcat(filter(p -> p[is] == "new", sel), filter(p -> p[is] != "new", sel))
    [(sigma = String(p[ih]), status = String(p[is]), profile = String(p[ip]), coeffs = String(p[ic]))
     for p in newfirst]
end

now_str() = Dates.format(now(), "yyyy-mm-dd HH:MM:SS")
