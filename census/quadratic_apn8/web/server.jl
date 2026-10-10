# Implements a local web page that classifies one (8,8)-function against the known
# quadratic APN CCZ classes and the census list of 553 new classes.
# Study: census of quadratic APN functions on F_2^8 (census/quadratic_apn8)
#
# Pseudocode:
#   1. At start: open the sigma index (read only), open the catalog, read the census list.
#   2. Per request: parse the input (LUT, coefficient string or polynomial).
#   3. Calculate differential uniformity and algebraic degree.
#   4. Quadratic APN only: calculate sigma; look it up in the index, then in the census list.
#   5. Optional: run the exact EA test against the matched function in a background task.
# VBF API used: SBox, differential_uniformity, algebraic_degree, polynomial_to_lut,
#   ea_mappings_from_ortho_derivative
# VBFCatalog API used: sigma_hash, classify_ccz, sigma_index_path, load_catalog,
#   corpus_function, load_sbox
#
# Run: julia --threads=1,1 --project=. server.jl [--port 8088] [--host 127.0.0.1]

module APN8Web

using DBInterface
using HTTP
using JSON3
using SQLite
using VBF
using VBFCatalog
using SHA,TOML,Dates
include("../discovery/evidence.jl")
using .DiscoveryEvidence

const WEB_DIR = @__DIR__
const STUDY_DIR = dirname(WEB_DIR)
const CENSUS_TSV = joinpath(STUDY_DIR, "new_classes_553.tsv")
# Other lists of classes that are absent from the index:
# (file, label, novelty, data column, data kind). `:new` = found in this study;
# `:public` = in a public raw file of the authors, but not in the index.
const OTHER_LISTS = [
    ("new_classes_extra.tsv", "theory experiment (extra class)", :new, 2, :coeffs),
    ("search_b52/new_classes_trial_773.tsv", "B6 = 52 search, trial run", :new, 5, :coeffs),
    ("theory/hyperplane_scan/new_classes_hyperplane.tsv", "hyperplane scan", :new, 2, :coeffs),
    ("crosscheck_raw/raw_only_546.tsv", "authors' raw file of May 2025 (langevin.univ-tln.fr)", :public, 3, :lut),
    # Read after raw_only_546.tsv: its 61 raw546_public rows keep the public verdict.
    ("search_b52/framework_20261009_new.tsv.gz", "B6 = 52 search, Framework run 2026-10-09", :new, 5, :coeffs),
]

"Lines of a list file; `.gz` files are read through `gzip -dc`."
list_lines(path) = endswith(path, ".gz") ? eachline(`gzip -dc $path`) : eachline(path)
const N = 8
const NPAIRS = N * (N - 1) ÷ 2
const DEFAULT_MODULUS = 0x11B
# Distinct sigma values over all indexed n = 8 sources (reports/verification/REPORT.md,
# equal to Beierle et al. 2025, Theorem 5.1).
const KNOWN_CLASSES = 3_808_491

# --- state -----------------------------------------------------------------------------

mutable struct State
    index::SQLite.DB
    catalog::SQLite.DB
    census::Dict{String,Tuple{Int,String}}   # sigma hash -> (line number, coeffs)
    rows::Int                                 # rows in the index (n = 8)
    dblock::ReentrantLock                     # SQLite connections are not thread safe
    others::Dict{String,NamedTuple}           # sigma hash -> entry of OTHER_LISTS
    reference::DiscoveryEvidence.Reference
end

"""Read the lists of OTHER_LISTS. A header line (first field `sigma_hash` or `sigma`) is skipped;
line numbers are file line numbers."""
function read_others()
    d = Dict{String,NamedTuple}()
    for (file, label, novelty, col, kind) in OTHER_LISTS
        path = joinpath(STUDY_DIR, file)
        isfile(path) || continue
        for (k, line) in enumerate(list_lines(path))
            f = split(line, '\t')
            (isempty(strip(line)) || f[1] in ("sigma_hash", "sigma")) && continue
            haskey(d, f[1]) && continue
            d[String(f[1])] = (file = file, label = label, novelty = novelty, line = k,
                               kind = kind, data = String(f[col]))
        end
    end
    d
end

"LUT of an entry of OTHER_LISTS."
other_lut(e) = e.kind === :coeffs ? coeffs_to_lut(e.data) :
    [parse(Int, e.data[2k - 1:2k]; base = 16) for k in 1:(1 << N)]

const STATE = Ref{Union{Nothing,State}}(nothing)

"Read the census list: `sigma_hash<TAB>coeffs` per line."
function read_census(path::AbstractString = CENSUS_TSV)
    d = Dict{String,Tuple{Int,String}}()
    for (k, line) in enumerate(eachline(path))
        isempty(strip(line)) && continue
        h, c = split(line, '\t')
        d[String(h)] = (k, String(c))
    end
    d
end

"""
    init!() -> State

Open the sigma index and the catalog once. The connections are read only
(`PRAGMA query_only`). The first lookup also checks that the index covers n = 8.
"""
function init!()
    STATE[] === nothing || return STATE[]
    idx = SQLite.DB(sigma_index_path())
    DBInterface.execute(idx, "PRAGMA query_only = ON")
    cat = load_catalog()
    DBInterface.execute(cat, "PRAGMA query_only = ON")
    rows = 0
    for r in DBInterface.execute(idx, "SELECT COUNT(*) c FROM ccz_sigma_index WHERE n = $N")
        rows = Int(r.c)
    end
    reference=DiscoveryEvidence.open_reference(joinpath(STUDY_DIR,"results","signature_rebuild"))
    st = State(idx, cat, read_census(), rows, ReentrantLock(), read_others(),reference)
    # A coverage gap makes classify_ccz throw. Fail at start, not at the first request.
    classify_ccz(SBox{N}(gf_monomial_lut(N, 3; modulus = DEFAULT_MODULUS));
                 index = idx, catalog = cat)
    STATE[] = st
end

# --- input parsing ---------------------------------------------------------------------

struct InputError <: Exception
    msg::String
end
Base.showerror(io::IO, e::InputError) = print(io, e.msg)

"LUT of the pure quadratic function `F(x) = XOR_{i<j} x_i x_j c_ij` (x_1 = least significant bit)."
function coeffs_to_lut(c::AbstractVector{<:Integer})
    length(c) == NPAIRS || throw(InputError("expected $NPAIRS coefficients"))
    lut = zeros(Int, 1 << N)
    for x in 0:(1 << N) - 1
        v = 0
        t = 0
        for i in 1:N, j in i + 1:N
            t += 1
            ((x >> (i - 1)) & (x >> (j - 1)) & 1) == 1 && (v ⊻= c[t])
        end
        lut[x + 1] = v
    end
    lut
end

coeffs_to_lut(s::AbstractString) =
    coeffs_to_lut([parse(Int, s[2k - 1:2k]; base = 16) for k in 1:NPAIRS])

const RE_MODULUS = r"\bmod(?:ulus)?\s*[=:]?\s*(0x[0-9a-fA-F]+|\d+)"i

"""
    parse_input(text) -> (lut, format, note)

Detect the format and return the LUT. Throws `InputError` with a readable message.
"""
function parse_input(text::AbstractString)
    s = strip(text)
    isempty(s) && throw(InputError("The input is empty. Paste a LUT, a coefficient string or a polynomial."))
    compact = replace(s, r"\s+" => "")
    # (2) coefficient string: 56 hex digits, optional 0x prefix
    m = match(r"^(?:0x)?([0-9a-fA-F]{56})$", compact)
    if m !== nothing
        return coeffs_to_lut(m.captures[1]), "coefficients",
               "56 hex digits read as c_ij for 1 <= i < j <= 8 (i outer, j inner), x_1 = least significant bit."
    end
    # (1) LUT: integers separated by spaces, commas, semicolons or newlines; optional brackets
    toks = split(s, r"[\s,;\[\]\(\){}]+"; keepempty = false)
    if !isempty(toks) && all(t -> occursin(r"^(\d+|0x[0-9a-fA-F]+)$"i, t), toks)
        length(toks) == 1 << N || throw(InputError(
            "LUT: expected 256 integers, found $(length(toks)). " *
            (length(compact) == 2NPAIRS ? "" :
             "A coefficient string must have exactly 56 hex digits.")))
        vals = Int[]
        for (i, t) in enumerate(toks)
            v = startswith(lowercase(t), "0x") ? parse(Int, t[3:end]; base = 16) : parse(Int, t)
            0 <= v <= 255 || throw(InputError("LUT: value $t at position $(i - 1) is outside 0..255."))
            push!(vals, v)
        end
        return vals, "lut", "256 integers read as F(0), F(1), ..., F(255)."
    end
    # (3) univariate polynomial over GF(2^8)
    if occursin(r"[xX]", s)
        modulus = Int(DEFAULT_MODULUS)
        mm = match(RE_MODULUS, s)
        expr = s
        if mm !== nothing
            t = mm.captures[1]
            modulus = startswith(lowercase(t), "0x") ? parse(Int, t[3:end]; base = 16) : parse(Int, t)
            0x100 <= modulus < 0x200 || throw(InputError(
                "Polynomial: the modulus must have degree 8 (0x100 .. 0x1FF), found $t."))
            expr = replace(s, RE_MODULUS => "")
        end
        expr = strip(replace(expr, r"[,;]\s*$" => ""))
        lut = try
            polynomial_to_lut(expr, N, modulus)
        catch e
            throw(InputError("Polynomial: cannot parse ($(sprint(showerror, e)))."))
        end
        return lut, "polynomial",
               "Univariate polynomial over GF(2^8) mod 0x$(string(modulus, base = 16, pad = 3)); " *
               "a, g and ksi are the class of X (the element 0x02)."
    end
    throw(InputError("Cannot detect the format. Use 256 integers 0..255, 56 hex digits, " *
                     "or a polynomial in x."))
end

# --- classification --------------------------------------------------------------------

hexlut(lut) = join(string.(lut; base = 16, pad = 2))

"Up to `limit` index rows (source, member) with sigma hash `h`, and the total row count."
function index_matches(st::State, h::String; limit::Int = 5)
    out = Tuple{String,Int}[]
    total = 0
    lock(st.dblock) do
        for r in DBInterface.execute(st.index,
                "SELECT COUNT(*) c FROM ccz_sigma_index WHERE sigma_hash = '$h'")
            total = Int(r.c)
        end
        for r in DBInterface.execute(st.index,
                "SELECT source, member_idx FROM ccz_sigma_index WHERE sigma_hash = '$h' LIMIT $limit")
            push!(out, (String(r.source), Int(r.member_idx)))
        end
    end
    out, total
end

"""
    analyze(text) -> Dict

Parse and classify one input. The `status` field is one of `error`, `not_apn`,
`apn_not_quadratic`, `reference_match`, `study_match`, `corpus_absent`.
"""
function analyze(text::AbstractString)
    st = init!()
    res = Dict{String,Any}("ok" => false)
    lut, fmt, note = try
        parse_input(text)
    catch e
        e isa InputError || rethrow()
        res["status"] = "error"
        res["error"] = e.msg
        return res
    end
    res["ok"] = true
    res["format"] = fmt
    res["format_note"] = note
    F = SBox{N}(lut)
    evidence=lock(st.dblock) do
        DiscoveryEvidence.classify(F.lut,st.reference;detailed=true)
    end
    merge!(res,evidence)
    du = evidence["differential_uniformity"]
    deg = evidence["algebraic_degree"]
    res["differential_uniformity"] = du
    res["apn"] = du == 2
    res["algebraic_degree"] = deg
    res["quadratic"] = deg == 2
    res["lut_hex"] = hexlut(lut)
    if du != 2
        res["status"] = "not_apn"
        res["verdict"] = "NOT APN: the differential uniformity is $du. The class oracle " *
                         "applies only to quadratic APN functions."
        return res
    end
    if deg != 2
        res["status"] = "apn_not_quadratic"
        res["verdict"] = "APN, but the algebraic degree is $deg. The sigma oracle needs a " *
                         "quadratic function (sigma is a CCZ invariant only for quadratic APN " *
                         "functions). Only the basic properties are given."
        return res
    end
    h = evidence["sigma_hash"]
    res["sigma"] = h
    status, source, member = lock(st.dblock) do
        classify_ccz(F; index = st.index, catalog = st.catalog)
    end
    if status === :sigma_match
        matches, total = index_matches(st, h)
        res["status"] = "reference_match"
        res["source"] = source
        res["member"] = member
        res["index_rows"] = total
        res["matches"] = [Dict("source" => s, "member" => i) for (s, i) in matches]
        res["verdict"] = "Reference invariant match ($source member $member); equivalence unresolved."
        res["caveat"] = "A sigma match is necessary but not sufficient for CCZ-equivalence. " *
                        "A bounded exact test can find a verified graph map, exhaust its search, or remain inconclusive."
        res["ea_available"] = true
    elseif haskey(st.reference.supplement,h)
        res["status"]="reference_match"
        res["target_lut_hex"]=bytes2hex(st.reference.supplement[h])
        res["verdict"]=evidence["evidence_level"]=="exact_public_lut_match" ?
            "Identical to a verified public supplement function." : "Public supplement invariant match; equivalence unresolved."
        res["ea_available"]=true
    elseif get(evidence,"reference_signature_match",false)
        res["status"]="reference_match"
        res["verdict"]="Invariant match in the rebuilt public corpus; equivalence unresolved."
        res["ea_available"]=haskey(st.others,h)
        haskey(st.others,h) && (res["target_lut_hex"]=hexlut(other_lut(st.others[h])))
    elseif haskey(st.census, h)
        line, coeffs = st.census[h]
        res["status"] = "study_match"
        res["census_line"] = line
        res["census_coeffs"] = coeffs
        res["verdict"] = "Study invariant match: census line $line; equivalence unresolved."
        res["caveat"] = "Absent from the source-rebuilt quadratic corpus. Literature-wide novelty remains unresolved; a study signature match is not an equivalence certificate."
        res["ea_available"] = true
    elseif haskey(st.others, h)
        e = st.others[h]
        res["status"] = "study_match"
        res["list_file"] = e.file
        res["list_line"] = e.line
        res["list_data"] = e.data
        res["list_kind"] = String(e.kind)
        res["verdict"] = "Study invariant match: $(e.label), line $(e.line); equivalence unresolved."
        res["caveat"] = "Corpus absence separates the documented quadratic references. Literature-wide novelty and equivalence to this study entry are unresolved."
        res["ea_available"] = true
    else
        res["status"] = "corpus_absent"
        res["verdict"] = "CCZ-inequivalent to the documented quadratic corpus; potential novelty."
        res["caveat"] = "All APN power functions are excluded by the documented Gold checks and Yoshiara 2016. Missing non-power datasets and arbitrary nonquadratic classes remain outside the comparison. Literature-wide novelty remains unresolved."
        res["ea_available"] = false
    end
    res
end

fmtint(x::Integer) = replace(string(x), r"(?<=\d)(?=(\d{3})+$)" => ",")

# --- exact EA check (background) -------------------------------------------------------

mutable struct EAJob
    id::Int
    target::String
    state::String          # queued, running, done, failed
    result::Union{Nothing,Bool}
    message::String
    started::Float64
    finished::Float64
    evidence::Dict{String,Any}
end

const JOBS = Dict{Int,EAJob}()
const JOB_BY_KEY = Dict{String,Int}()
const JOBLOCK = ReentrantLock()
const EA_SEM = Base.Semaphore(1)     # one exact test at a time (2 threads in total)
const NEXT_JOB = Ref(0)

"The matched function as an SBox (re-derived on the server, not taken from the client)."
function target_sbox(st::State, res::Dict)
    if haskey(res,"target_lut_hex")
        return SBox{N}(hex2bytes(res["target_lut_hex"])),"public reference"
    elseif haskey(res,"source")
        src, m = res["source"], res["member"]
        G = lock(st.dblock) do
            src == "functions" ? load_sbox(st.catalog, m) : corpus_function(st.catalog, src, m)
        end
        return G, "$src member $m"
    elseif haskey(res,"list_file")
        e = st.others[res["sigma"]]
        return SBox{N}(other_lut(e)), "$(e.file) line $(e.line)"
    else
        line = res["census_line"]
        return SBox{N}(coeffs_to_lut(res["census_coeffs"])), "census line $line"
    end
end

function start_ea(text::AbstractString)
    st = init!()
    res = analyze(text)
    get(res, "ea_available", false) || return nothing, res
    G, label = target_sbox(st, res)
    F = SBox{N}(parse_input(text)[1])
    key = res["lut_hex"] * "|" * label
    job = lock(JOBLOCK) do
        if haskey(JOB_BY_KEY, key)
            j = JOBS[JOB_BY_KEY[key]]
            j.state != "failed" && return j
        end
        NEXT_JOB[] += 1
        j = EAJob(NEXT_JOB[], label, "queued", nothing, "", time(), 0.0,Dict{String,Any}())
        JOBS[j.id] = j
        JOB_BY_KEY[key] = j.id
        Threads.@spawn :default run_ea!(j, F, G)
        j
    end
    job, res
end

function run_ea!(j::EAJob, F, G;relation=:ea,timeout_seconds=30,max_nodes=1_000_000)
    Base.acquire(EA_SEM)
    try
        lock(JOBLOCK) do
            j.state = "running"
            j.started = time()
        end
        proof=DiscoveryEvidence.compare(F.lut,G.lut;relation,timeout_seconds,max_nodes)
        proof["created_utc"]=string(Dates.now(Dates.UTC))
        proof["algorithm_sha256"]=DiscoveryEvidence.filehash(joinpath(STUDY_DIR,"discovery","evidence.jl"))
        dir=joinpath(STUDY_DIR,"discovery","results","web")
        mkpath(dir)
        open(io->TOML.print(io,proof;sorted=true),joinpath(dir,"comparison_$(time_ns()).toml"),"w")
        if !isempty(RUN_DIRECTORY[])
            db=SQLite.DB(joinpath(RUN_DIRECTORY[],"run.sqlite"))
            try
                foreach(_->nothing,DBInterface.execute(db,"PRAGMA busy_timeout=10000"))
                foreach(_->nothing,DBInterface.execute(db,
                    "INSERT INTO comparisons(candidate_id,target_id,relation,evidence) VALUES(?,?,?,?)",
                    (proof["candidate_sha256"],proof["target_sha256"],proof["relation"],sprint(io->TOML.print(io,proof;sorted=true)))))
            finally
                SQLite.close(db)
            end
        end
        lock(JOBLOCK) do
        j.evidence=proof
        eq=proof["equivalent"]
        j.result=eq isa Bool ? eq : nothing
        j.message=proof["status"]=="inconclusive_budget" ? "Inconclusive: budget exhausted; no negative equivalence conclusion." :
            eq===true ? "Equivalent to $(j.target), with independently verified $(uppercase(string(relation))) graph witness." :
            "Inequivalent to this target: $(proof["status"]). This does not establish literature-wide novelty."
        j.state = "done"
        end
    catch e
        lock(JOBLOCK) do
        j.state = "failed"
        j.message = "EA test failed: " * sprint(showerror, e)
        end
    finally
        lock(JOBLOCK) do;j.finished = time();end
        Base.release(EA_SEM)
    end
end

job_dict(j::EAJob) = lock(JOBLOCK) do
    Dict("id" => j.id, "target" => j.target, "state" => j.state,
                          "equivalent" => j.result, "message" => j.message,
                          "evidence"=>j.evidence,
                          "seconds" => round((j.finished > 0 ? j.finished : time()) - j.started; digits = 1))
end

# --- HTTP ------------------------------------------------------------------------------

json_response(status::Int, x) =
    HTTP.Response(status, ["Content-Type" => "application/json; charset=utf-8"], JSON3.write(x))

body_text(req::HTTP.Request) = String(req.body)

"""
    handle(req::HTTP.Request) -> HTTP.Response

Routes:
  * `GET /`               the page
  * `POST /api/classify`  body = the function as text; JSON result
  * `POST /api/ea`        body = the function as text; starts the exact EA test; JSON job
  * `GET /api/ea/<id>`    JSON job state
"""
function handle(req::HTTP.Request)
    path = HTTP.URI(req.target).path
    try
        if req.method == "GET" && (path == "/" || path == "/index.html")
            return HTTP.Response(200, ["Content-Type" => "text/html; charset=utf-8"], PAGE)
        elseif req.method == "POST" && path == "/api/classify"
            res = analyze(body_text(req))
            return json_response(res["status"] == "error" ? 400 : 200, res)
        elseif req.method == "POST" && path == "/api/ea"
            job, res = start_ea(body_text(req))
            job === nothing && return json_response(400, Dict(
                "error" => "The exact EA test needs a quadratic APN input with a sigma match " *
                           "(reference or study invariant match). Status: $(res["status"]).",
                "classify" => res))
            return json_response(200, job_dict(job))
        elseif req.method == "POST" && path == "/api/compare"
            data=JSON3.read(body_text(req))
            relation=Symbol(get(data,:relation,"ccz"));relation in (:ea,:ccz) || return json_response(400,Dict("error"=>"invalid relation"))
            seconds=Float64(get(data,:timeout_seconds,30));nodes=Int(get(data,:max_nodes,1_000_000))
            0<seconds<=600 && 0<nodes<=10_000_000 || return json_response(400,Dict("error"=>"invalid comparison budget"))
            F=SBox{N}(parse_input(String(data.candidate))[1]);G=SBox{N}(parse_input(String(data.target))[1])
            job=lock(JOBLOCK) do
                NEXT_JOB[]+=1
                j=EAJob(NEXT_JOB[],"specified target","queued",nothing,"",time(),0.0,Dict{String,Any}())
                JOBS[j.id]=j
                Threads.@spawn :default run_ea!(j,F,G;relation,timeout_seconds=seconds,max_nodes=nodes)
                j
            end
            return json_response(200,job_dict(job))
        elseif req.method == "GET" && path == "/api/candidates"
            isempty(RUN_DIRECTORY[]) && return json_response(400,Dict("error"=>"configure --run PATH first"))
            params=HTTP.queryparams(HTTP.URI(req.target))
            limit=clamp(parse(Int,get(params,"limit","50")),1,200)
            offset=max(0,parse(Int,get(params,"offset","0")))
            where=get(params,"additional","false")=="true" ? " WHERE additional=1" : ""
            db=SQLite.DB("file:"*joinpath(RUN_DIRECTORY[],"run.sqlite")*"?mode=ro")
            try
                total=only([Int(r.c) for r in DBInterface.execute(db,"SELECT COUNT(*) c FROM candidates"*where)])
                records=[TOML.parse(String(r.evidence)) for r in DBInterface.execute(db,
                    "SELECT evidence FROM candidates"*where*" ORDER BY lut_id LIMIT ? OFFSET ?",(limit,offset))]
                return json_response(200,Dict("total"=>total,"candidates"=>records))
            finally
                SQLite.close(db)
            end
        elseif req.method == "GET" && path == "/api/relationships"
            isempty(RUN_DIRECTORY[]) && return json_response(400,Dict("error"=>"configure --run PATH first"))
            db=SQLite.DB("file:"*joinpath(RUN_DIRECTORY[],"run.sqlite")*"?mode=ro")
            try
                records=[TOML.parse(String(r.evidence)) for r in DBInterface.execute(db,"SELECT evidence FROM comparisons ORDER BY id DESC LIMIT 200")]
                return json_response(200,Dict("comparisons"=>records,"scope"=>"recorded pairwise checks; missing edges are unresolved"))
            finally
                SQLite.close(db)
            end
        elseif req.method == "GET" && path == "/api/classification"
            file=joinpath(RUN_DIRECTORY[],"classification.toml")
            if isempty(RUN_DIRECTORY[]) || !isfile(file)
                return json_response(404,Dict("error"=>"run classify.jl for this candidate snapshot first"))
            end
            return json_response(200,TOML.parsefile(file))
        elseif req.method == "GET" && endswith(path,"/certificate") && startswith(path,"/api/ea/")
            id=tryparse(Int,split(path,'/')[4]);j=id===nothing ? nothing : get(JOBS,id,nothing)
            j===nothing && return json_response(404,Dict("error"=>"unknown job"))
            return HTTP.Response(200,["Content-Type"=>"application/toml","Content-Disposition"=>"attachment; filename=comparison_$(id).toml"],sprint(io->TOML.print(io,j.evidence;sorted=true)))
        elseif req.method == "GET" && startswith(path, "/api/ea/")
            id = tryparse(Int, path[length("/api/ea/") + 1:end])
            j = id === nothing ? nothing : lock(() -> get(JOBS, id, nothing), JOBLOCK)
            j === nothing && return json_response(404, Dict("error" => "unknown job"))
            return json_response(200, job_dict(j))
        elseif req.method == "GET" && path == "/api/health"
            st = init!()
            return json_response(200, Dict("ok" => true, "index_rows" => st.rows,
                                            "census" => length(st.census),"reference"=>st.reference.metadata))
        end
        return json_response(404, Dict("error" => "not found: $(req.method) $path"))
    catch e
        e isa InputError && return json_response(400,Dict("error"=>e.msg))
        @error "request failed" exception = (e, catch_backtrace())
        return json_response(500, Dict("ok" => false, "status" => "error",
                                       "error" => "internal error: " * sprint(showerror, e)))
    end
end

const RUN_DIRECTORY=Ref("")
const PAGE = raw"""
<!doctype html><html lang="en"><head><meta charset="utf-8"><title>APN8 evidence inspector</title>
<meta name="viewport" content="width=device-width,initial-scale=1"><style>
body{font-family:system-ui;max-width:70rem;margin:2rem auto;padding:0 1rem;line-height:1.5}textarea{width:100%;height:9rem;font-family:monospace}table{border-collapse:collapse;width:100%}td,th{padding:.4rem;border-bottom:1px solid #ddd;text-align:left}code{overflow-wrap:anywhere}button{padding:.4rem;margin:.3rem}svg{max-width:100%;height:180px}pre{white-space:pre-wrap;overflow-wrap:anywhere}#verdict{font-weight:bold}details{margin:1rem 0}
</style></head><body><h1>APN8 evidence inspector</h1>
<p>Validate a function, inspect its invariants and compare its graph with a specified target. Corpus absence concerns the documented quadratic references; literature-wide novelty remains unresolved.</p>
<p>Input: 256 integers (0..255, F(0) first), 56 hexadecimal digits for the 28 quadratic ANF coefficients (i outer, j inner; least significant bit first), or a polynomial such as <code>x^3 mod=0x11D</code>. Polynomial modulus defaults to 0x11B. Field basis matters.</p>
<textarea id="input" placeholder="x^3"></textarea><button id="validate">Validate and compare with corpus</button><button id="download" disabled>Download validation evidence</button>
<div id="verdict"></div><div id="properties"></div><div id="reference"></div><div id="matched"></div><div id="walsh"></div><details><summary>Full validation evidence, ANF and ortho-derivative</summary><pre id="evidence"></pre></details>
<h2>Compare two functions</h2><p>Enter a target below. A positive result includes an independently verified affine graph map. Different signatures separate two verified quadratic APNs. A solver budget stop is inconclusive. EA inequivalence alone does not separate arbitrary CCZ classes.</p>
<textarea id="target" placeholder="Target LUT, coefficients or polynomial"></textarea>
<label>Relation <select id="relation"><option value="ccz">CCZ</option><option value="ea">EA</option></select></label>
<label>Seconds <input id="seconds" type="number" min="0.001" max="600" value="30"></label>
<label>Node limit <input id="nodes" type="number" min="1" max="10000000" value="1000000"></label><button id="compare">Compare</button><div id="comparison"></div>
<h2>Saved experiment</h2><p>Start the server with <code>--run PATH</code> to browse the transactional experiment database.</p><button id="browse">Load candidates</button><label><input id="additional" type="checkbox"> Additional signature buckets only</label><div id="candidates"></div>
<script>
const $=id=>document.getElementById(id);let last=null;
const esc=s=>String(s).replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
function save(name,data){const a=document.createElement('a');a.href=URL.createObjectURL(new Blob([JSON.stringify(data,null,2)],{type:'application/json'}));a.download=name;a.click();setTimeout(()=>URL.revokeObjectURL(a.href),1000)}
async function request(path,body){const r=await fetch(path,body===undefined?{}:{method:'POST',headers:{'Content-Type':'application/json'},body});const j=await r.json();if(!r.ok)throw Error(j.error||j.verdict||r.status);return j}
async function validate(){try{$('verdict').textContent='Checking every derivative...';const j=await request('/api/classify',$('input').value);last=j;$('download').disabled=false;$('verdict').textContent=j.verdict;$('reference').textContent=j.caveat||'';$('evidence').textContent=JSON.stringify(j,null,2);$('properties').innerHTML='<table>'+['apn','differential_uniformity','algebraic_degree','linearity','nonlinearity','sigma_hash','lut_sha256','evidence_level','apn_power_function_comparison','literature_novelty'].filter(k=>j[k]!==undefined).map(k=>'<tr><th>'+esc(k)+'</th><td><code>'+esc(j[k])+'</code></td></tr>').join('')+'</table>';if(j.reference)$('reference').textContent+=(" Reference SHA256: "+j.reference.sha256+"; "+j.reference.signatures+" signature buckets.");$('matched').innerHTML=j.ea_available?'<button id="matchedcheck">Compare with matched reference (30 s / 1M nodes)</button>':'';if(j.ea_available)$('matchedcheck').onclick=async()=>{try{const job=await request('/api/ea',$('input').value);poll(job.id)}catch(e){$('comparison').textContent=e.message}};const bins=j.absolute_walsh_spectrum||[],max=Math.max(1,...bins.map(x=>x.count));$('walsh').innerHTML=bins.length?'<p>Absolute Walsh spectrum (counts of all frequency pairs except (0,0))</p><svg viewBox="0 0 600 180" role="img" aria-label="Absolute Walsh spectrum">'+bins.map((b,i)=>{const w=580/bins.length,h=130*b.count/max,x=10+i*w;return '<rect x="'+x+'" y="'+(140-h)+'" width="'+(w-3)+'" height="'+h+'" fill="#246"><title>'+b.value+': '+b.count+'</title></rect><text x="'+x+'" y="165">'+b.value+'</text>'}).join('')+'</svg>':''}catch(e){$('verdict').textContent=e.message}}
async function poll(id){try{const j=await request('/api/ea/'+id);$('comparison').textContent=j.message||j.state;if(j.state==='queued'||j.state==='running')setTimeout(()=>poll(id),1000);else if(j.evidence&&Object.keys(j.evidence).length){const a=document.createElement('a');a.textContent=' Download comparison certificate';a.href='/api/ea/'+id+'/certificate';$('comparison').append(a)}}catch(e){$('comparison').textContent=e.message}}
$('validate').onclick=validate;$('download').onclick=()=>save('apn-validation-'+last.lut_sha256+'.json',last);
$('compare').onclick=async()=>{try{const j=await request('/api/compare',JSON.stringify({candidate:$('input').value,target:$('target').value,relation:$('relation').value,timeout_seconds:Number($('seconds').value),max_nodes:Number($('nodes').value)}));poll(j.id)}catch(e){$('comparison').textContent=e.message}};
$('browse').onclick=async()=>{try{const j=await request('/api/candidates?additional='+$('additional').checked);$('candidates').innerHTML='<p>'+esc(j.total)+' exact LUTs match this filter; showing first '+j.candidates.length+'. API supports offset and limit.</p><table><tr><th>LUT SHA256</th><th>Evidence</th><th>Inspect</th></tr>'+j.candidates.map((c,i)=>'<tr><td><code>'+esc(c.lut_sha256)+'</code></td><td>'+esc(c.evidence_level)+'</td><td><button data-i="'+i+'">Load</button></td></tr>').join('')+'</table>';try{const c=await request('/api/classification');const p=document.createElement('p');p.textContent='Classification snapshot '+c.created_utc+': '+c.snapshot_luts+' quadratic APN LUTs, '+c.proven_equivalence_components+' proven components, '+c.unresolved_component_pairs+' unresolved pairs; exact class count within that snapshot: '+c.exact_snapshot_class_count_established+'.';$('candidates').prepend(p)}catch(e){};$('candidates').querySelectorAll('button').forEach(b=>b.onclick=()=>{$('input').value=Array.from(j.candidates[Number(b.dataset.i)].lut_hex.matchAll(/../g),x=>parseInt(x[0],16)).join(' ');validate()})}catch(e){$('candidates').textContent=e.message}};
</script></body></html>
"""

function serve(; host::AbstractString = "127.0.0.1", port::Integer = 8088)
    st = init!()
    @info "APN8 class check ready" url = "http://$host:$port/" index_rows = st.rows census = length(st.census) threads = (Threads.nthreads(:default), Threads.nthreads(:interactive))
    HTTP.serve(handle, host, port)
end

function main(args = ARGS)
    host = "127.0.0.1"
    port = 8088
    i = 1
    while i <= length(args)
        a = args[i]
        if a == "--port"
            port = parse(Int, args[i + 1]); i += 2
        elseif a == "--run"
            RUN_DIRECTORY[]=abspath(args[i+1]);isfile(joinpath(RUN_DIRECTORY[],"run.sqlite")) || error("missing run.sqlite");i+=2
        elseif a == "--host"
            host = args[i + 1]; i += 2
        else
            error("unknown argument $a (use --port P, --host H)")
        end
    end
    serve(; host = host, port = port)
end

end # module

if abspath(PROGRAM_FILE) == (@__FILE__)
    APN8Web.main()
end
