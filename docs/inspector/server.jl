# Implements a local web page that classifies one (8,8)-function against the known
# quadratic APN CCZ classes and the census list of 553 new classes.
# Study: census of quadratic APN functions on F_2^8 (packages/VBFCatalog/data/research/archive/census)
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
import VBFSearch
using VBFSearch: candidate_properties, open_reference, close_reference, classify, compare, verify_comparison
const properties = candidate_properties

const WEB_DIR = @__DIR__
const REPO_ROOT = normpath(joinpath(WEB_DIR,"../.."))
const STUDY_DIR = joinpath(REPO_ROOT,"packages/VBFCatalog/data/research/archive/census")
const CENSUS_TSV = joinpath(STUDY_DIR, "new_classes_553.tsv")
const PUBLIC_TSV = joinpath(VBFCatalog.catalog_source_dir(),"luts","langevin_may2025_extra.tsv")
# Other lists of classes that are absent from the index:
# (file, label, novelty, data column, data kind). `:new` = found in this study;
# `:public` = in a public raw file of the authors, but not in the index.
const OTHER_LISTS = [
    ("new_classes_extra.tsv", "theory experiment (extra class)", :new, 2, :coeffs),
    ("search_b52/new_classes_trial_773.tsv", "B6 = 52 search, trial run", :new, 5, :coeffs),
    ("theory/hyperplane_scan/new_classes_hyperplane.tsv", "hyperplane scan", :new, 2, :coeffs),
    (PUBLIC_TSV, "authors' raw file of May 2025 (langevin.univ-tln.fr)", :public, 3, :lut),
    # Read after raw_only_546.tsv: its 61 raw546_public rows keep the public verdict.
    ("search_b52/framework_20261009_new.tsv.gz", "B6 = 52 search, Framework run 2026-10-09", :new, 5, :coeffs),
]

"Lines of a list file; `.gz` files are read through `gzip -dc`."
list_lines(path) = endswith(path, ".gz") ? eachline(`gzip -dc $path`) : eachline(path)
const N = 8
const NPAIRS = N * (N - 1) ÷ 2
const DEFAULT_MODULUS = 0x11B
# --- state -----------------------------------------------------------------------------

mutable struct State
    index::SQLite.DB
    catalog::SQLite.DB
    census::Dict{String,Tuple{Int,String}}   # sigma hash -> (line number, coeffs)
    rows::Int                                 # rows in the index (n = 8)
    dblock::ReentrantLock                     # SQLite connections are not thread safe
    others::Dict{String,NamedTuple}           # sigma hash -> entry of OTHER_LISTS
    reference::VBFCatalog.AuditedAPNReference
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
    reference=VBFSearch.open_reference(get(ENV,"VBF_APN_REFERENCE",VBFCatalog.catalog_data_dir()))
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
    all(x->0<=x<=255,c) || throw(InputError("expected byte-valued coefficients"))
    C=VBF.QuadraticAPNTree.decode_coeffs(bytes2hex(UInt8.(c)),N)
    Int.(VBF.QuadraticAPNTree.lut(C,N))
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
        VBFSearch.classify(F.lut,st.reference;detailed=true)
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
        proof=VBFSearch.compare(F.lut,G.lut;relation,timeout_seconds,max_nodes)
        proof["created_utc"]=string(Dates.now(Dates.UTC))
        proof["algorithm_sha256"]=proof["source_sha256"]
        dir=joinpath(REPO_ROOT,"packages/VBFCatalog/data/research/runs/web")
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

const DOCS_DIRECTORY = Ref("")
const CONTENT_TYPES = Dict(
    ".html" => "text/html; charset=utf-8", ".css" => "text/css; charset=utf-8",
    ".js" => "text/javascript; charset=utf-8", ".svg" => "image/svg+xml",
    ".png" => "image/png", ".jpg" => "image/jpeg", ".ico" => "image/x-icon",
    ".woff" => "font/woff", ".woff2" => "font/woff2", ".json" => "application/json",
)

"Serve only files inside the configured Documenter build, including pretty-URL indexes."
function docs_response(path)
    isempty(DOCS_DIRECTORY[]) && return json_response(404, Dict("error" => "documentation not configured"))
    path == "/docs" && return HTTP.Response(302, ["Location" => "/docs/"])
    relative = HTTP.unescapeuri(path[length("/docs/")+1:end])
    parts = split(relative, '/'; keepempty=false)
    any(p -> p in (".", "..") || occursin('\\', p) || occursin('\0', p), parts) &&
        return json_response(400, Dict("error" => "invalid documentation path"))
    file = joinpath(DOCS_DIRECTORY[], parts...)
    if isdir(file)
        endswith(path, '/') || return HTTP.Response(302, ["Location" => path * "/"])
        file = joinpath(file, "index.html")
    end
    isfile(file) || return json_response(404, Dict("error" => "documentation file not found"))
    # Symlinks must not escape the build directory either.
    resolved = relpath(realpath(file), realpath(DOCS_DIRECTORY[]))
    (resolved == ".." || startswith(resolved, "../")) &&
        return json_response(400, Dict("error" => "invalid documentation path"))
    return HTTP.Response(200, ["Content-Type" => get(CONTENT_TYPES, lowercase(splitext(file)[2]),
                                                   "application/octet-stream")], read(file))
end

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
        if req.method == "GET" && (path == "/docs" || startswith(path, "/docs/"))
            return docs_response(path)
        elseif req.method == "GET" && (path == "/" || path == "/index.html" || path == "/inspector/")
            if path != "/inspector/" && !isempty(DOCS_DIRECTORY[])
                return HTTP.Response(302, ["Location" => "/docs/"])
            end
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
const PAGE = read(joinpath(REPO_ROOT,"docs","src","assets","apn-inspector.html"), String)

function serve(; host::AbstractString = "127.0.0.1", port::Integer = 8088, docs::AbstractString = "")
    if !isempty(docs)
        isfile(joinpath(docs, "index.html")) || error("missing built documentation: run make -C docs build")
        DOCS_DIRECTORY[] = realpath(docs)
    else
        DOCS_DIRECTORY[] = ""
    end
    st = init!()
    @info "APN8 evidence inspector ready" url = "http://$host:$port/" index_rows = st.rows census = length(st.census) threads = (Threads.nthreads(:default), Threads.nthreads(:interactive))
    HTTP.serve(handle, host, port)
end

function main(args = ARGS)
    host = "127.0.0.1"
    port = 8088
    docs = ""
    i = 1
    while i <= length(args)
        a = args[i]
        if a == "--port"
            port = parse(Int, args[i + 1]); i += 2
        elseif a == "--run"
            RUN_DIRECTORY[]=abspath(args[i+1]);isfile(joinpath(RUN_DIRECTORY[],"run.sqlite")) || error("missing run.sqlite");i+=2
        elseif a == "--host"
            host = args[i + 1]; i += 2
        elseif a == "--docs"
            docs = abspath(args[i + 1]); i += 2
        else
            error("unknown argument $a (use --port P, --host H, --run PATH, --docs PATH)")
        end
    end
    serve(; host, port, docs)
end

end # module

if abspath(PROGRAM_FILE) == (@__FILE__)
    APN8Web.main()
end
