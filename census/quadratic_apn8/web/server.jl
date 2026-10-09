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

const WEB_DIR = @__DIR__
const STUDY_DIR = dirname(WEB_DIR)
const CENSUS_TSV = joinpath(STUDY_DIR, "new_classes_553.tsv")
# Other lists of classes that are absent from the index:
# (file, label, novelty, data column, data kind). `:new` = found in this study;
# `:public` = in a public raw file of the authors, but not in the index.
const OTHER_LISTS = [
    ("new_classes_extra.tsv", "theory experiment (extra class)", :new, 2, :coeffs),
    ("search_b52/new_classes_trial_773.tsv", "B6 = 52 search, trial run", :new, 5, :coeffs),
    ("crosscheck_raw/raw_only_546.tsv", "authors' raw file of May 2025 (langevin.univ-tln.fr)", :public, 3, :lut),
]
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
end

"""Read the lists of OTHER_LISTS. A header line (first field `sigma_hash` or `sigma`) is skipped;
line numbers are file line numbers."""
function read_others()
    d = Dict{String,NamedTuple}()
    for (file, label, novelty, col, kind) in OTHER_LISTS
        path = joinpath(STUDY_DIR, file)
        isfile(path) || continue
        for (k, line) in enumerate(eachline(path))
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
    st = State(idx, cat, read_census(), rows, ReentrantLock(), read_others())
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
`apn_not_quadratic`, `known`, `census`, `new`.
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
    du = Int(differential_uniformity(F))
    deg = Int(algebraic_degree(F))
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
    h = sigma_hash(F)
    res["sigma"] = h
    status, source, member = lock(st.dblock) do
        classify_ccz(F; index = st.index, catalog = st.catalog)
    end
    if status === :sigma_match
        matches, total = index_matches(st, h)
        res["status"] = "known"
        res["source"] = source
        res["member"] = member
        res["index_rows"] = total
        res["matches"] = [Dict("source" => s, "member" => i) for (s, i) in matches]
        res["verdict"] = "KNOWN (sigma matches $source member $member)."
        res["caveat"] = "A sigma match is necessary but not sufficient for CCZ-equivalence. " *
                        "The exact EA test settles it (about 10 minutes when the functions " *
                        "are equivalent, seconds when they are not)."
        res["ea_available"] = true
    elseif haskey(st.census, h)
        line, coeffs = st.census[h]
        res["status"] = "census"
        res["census_line"] = line
        res["census_coeffs"] = coeffs
        res["verdict"] = "NEW, in the census list (one of the 553): line $line of new_classes_553.tsv."
        res["caveat"] = "The sigma is absent from the index of $(fmtint(KNOWN_CLASSES)) known " *
                        "classes. Thus the function is CCZ-inequivalent to all indexed " *
                        "functions (rigorous). The sigma is equal to that of census line $line; " *
                        "this is necessary but not sufficient for equivalence to that line."
        res["ea_available"] = true
    elseif haskey(st.others, h)
        e = st.others[h]
        res["status"] = e.novelty === :new ? "listed_new" : "raw_public"
        res["list_file"] = e.file
        res["list_line"] = e.line
        res["list_data"] = e.data
        res["list_kind"] = String(e.kind)
        res["verdict"] = e.novelty === :new ?
            "NEW, found in this study: $(e.label), line $(e.line) of $(e.file)." :
            "Not in the catalog index, but PUBLIC: $(e.label), line $(e.line) of $(e.file)."
        res["caveat"] = "The sigma is absent from the index of $(fmtint(KNOWN_CLASSES)) known " *
                        "classes, so the function is CCZ-inequivalent to all indexed functions " *
                        "(rigorous). The sigma is equal to that of the listed entry; this is " *
                        "necessary but not sufficient for equivalence to that entry."
        res["ea_available"] = true
    else
        res["status"] = "new"
        res["verdict"] = "NEW: sigma absent from the index of $(fmtint(KNOWN_CLASSES)) known " *
                         "classes and from the census list."
        res["caveat"] = "This is a rigorous CCZ-inequivalence certificate against all indexed " *
                        "sources ($(fmtint(st.rows)) index rows, n = 8). sigma is a CCZ invariant " *
                        "of quadratic APN functions, so a mismatch cannot be an artefact."
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
end

const JOBS = Dict{Int,EAJob}()
const JOB_BY_KEY = Dict{String,Int}()
const JOBLOCK = ReentrantLock()
const EA_SEM = Base.Semaphore(1)     # one exact test at a time (2 threads in total)
const NEXT_JOB = Ref(0)

"The matched function as an SBox (re-derived on the server, not taken from the client)."
function target_sbox(st::State, res::Dict)
    if res["status"] == "known"
        src, m = res["source"], res["member"]
        G = lock(st.dblock) do
            src == "functions" ? load_sbox(st.catalog, m) : corpus_function(st.catalog, src, m)
        end
        return G, "$src member $m"
    elseif res["status"] in ("listed_new", "raw_public")
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
        j = EAJob(NEXT_JOB[], label, "queued", nothing, "", time(), 0.0)
        JOBS[j.id] = j
        JOB_BY_KEY[key] = j.id
        Threads.@spawn :default run_ea!(j, F, G)
        j
    end
    job, res
end

function run_ea!(j::EAJob, F, G)
    Base.acquire(EA_SEM)
    try
        j.state = "running"
        j.started = time()
        eq = F.lut == G.lut || !isempty(ea_mappings_from_ortho_derivative(F, G))
        j.result = eq
        j.message = eq ? "EA-EQUIVALENT to $(j.target) (hence CCZ-equivalent): the class is confirmed." :
                         "NOT EA-equivalent to $(j.target): the sigma match was a collision. " *
                         "The input is a different CCZ class than this member."
        j.state = "done"
    catch e
        j.state = "failed"
        j.message = "EA test failed: " * sprint(showerror, e)
    finally
        j.finished = time()
        Base.release(EA_SEM)
    end
end

job_dict(j::EAJob) = Dict("id" => j.id, "target" => j.target, "state" => j.state,
                          "equivalent" => j.result, "message" => j.message,
                          "seconds" => round((j.finished > 0 ? j.finished : time()) - j.started; digits = 1))

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
                           "(status known or census). Status: $(res["status"]).",
                "classify" => res))
            return json_response(200, job_dict(job))
        elseif req.method == "GET" && startswith(path, "/api/ea/")
            id = tryparse(Int, path[length("/api/ea/") + 1:end])
            j = id === nothing ? nothing : lock(() -> get(JOBS, id, nothing), JOBLOCK)
            j === nothing && return json_response(404, Dict("error" => "unknown job"))
            return json_response(200, job_dict(j))
        elseif req.method == "GET" && path == "/api/health"
            st = init!()
            return json_response(200, Dict("ok" => true, "index_rows" => st.rows,
                                            "census" => length(st.census)))
        end
        return json_response(404, Dict("error" => "not found: $(req.method) $path"))
    catch e
        @error "request failed" exception = (e, catch_backtrace())
        return json_response(500, Dict("ok" => false, "status" => "error",
                                       "error" => "internal error: " * sprint(showerror, e)))
    end
end

const PAGE = """
<!doctype html>
<html lang="en"><head><meta charset="utf-8">
<title>APN8 class check</title>
<meta name="viewport" content="width=device-width, initial-scale=1">
<style>
body{font-family:sans-serif;max-width:60rem;margin:1rem auto;padding:0 1rem;line-height:1.4}
textarea{width:100%;height:12rem;font-family:monospace}
table{border-collapse:collapse}td{padding:.2rem .6rem;border-bottom:1px solid #ccc;vertical-align:top}
td:first-child{font-weight:bold;white-space:nowrap}
.v{font-size:1.15rem;font-weight:bold;margin:.8rem 0}
.known{color:#06c}.new{color:#080}.census{color:#080}.listed_new{color:#080}.raw_public{color:#06c}.not_apn,.error{color:#b00}.apn_not_quadratic{color:#a60}
code{word-break:break-all}
</style></head><body>
<h1>Quadratic APN on F<sub>2</sub><sup>8</sup>: known or new CCZ class?</h1>
<p>Paste one (8,8)-function. The server finds the format.</p>
<ol>
<li><b>LUT</b>: 256 integers 0..255, F(0) first. Separate them with spaces, commas or newlines. Brackets are optional. Hex values need the prefix 0x.</li>
<li><b>Coefficient string</b>: 56 hex digits = 28 bytes c<sub>ij</sub> for 1 &le; i &lt; j &le; 8 (i outer, j inner).
F(x) = XOR<sub>i&lt;j</sub> x<sub>i</sub>x<sub>j</sub>c<sub>ij</sub>, x<sub>1</sub> = least significant bit (format of new_classes_553.tsv).</li>
<li><b>Univariate polynomial</b> over GF(2<sup>8</sup>), for example <code>x^3 + a*x^9</code>. Modulus 0x11B by default; add <code>mod=0x11D</code> to change it.
<code>a</code>, <code>g</code> and <code>ksi</code> are the class of X (the element 0x02). Integer constants are read mod 2.</li>
</ol>
<textarea id="in" placeholder="x^3"></textarea><br>
<button id="go">Classify</button>
<div id="out"></div>
<h2>Verdicts</h2>
<ul>
<li><b>KNOWN</b>: sigma is in the index of 3,808,491 known classes. A sigma match is necessary but not sufficient for equivalence. The button "exact EA check" runs the complete test (about 10 minutes when equivalent).</li>
<li><b>NEW, in the census list</b>: sigma is absent from the index (rigorous inequivalence to all indexed functions) and equal to the sigma of one of the 553 census functions.</li>
<li><b>NEW</b>: sigma is absent from the index and from the census list. This is a rigorous CCZ-inequivalence certificate against all indexed sources.</li>
<li><b>APN, not quadratic</b>: the sigma oracle needs a quadratic function. Only the basic properties are given.</li>
<li><b>NOT APN</b>: the differential uniformity is larger than 2.</li>
</ul>
<script>
const \$ = id => document.getElementById(id);
function esc(s){return String(s).replace(/[&<>"]/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'}[c]))}
function row(k,v){return v===undefined?'':'<tr><td>'+esc(k)+'</td><td>'+v+'</td></tr>'}
async function classify(){
  \$('out').innerHTML='Working...';
  const r = await fetch('/api/classify',{method:'POST',headers:{'Content-Type':'text/plain'},body:\$('in').value});
  const j = await r.json();
  if(j.status==='error'){\$('out').innerHTML='<p class="v error">Parse error: '+esc(j.error)+'</p>';return;}
  let h='<p class="v '+j.status+'">'+esc(j.verdict)+'</p>';
  if(j.caveat) h+='<p>'+esc(j.caveat)+'</p>';
  h+='<table>'+row('Parsed','OK ('+esc(j.format)+'). '+esc(j.format_note))
    +row('Differential uniformity',j.differential_uniformity)+row('APN',j.apn)
    +row('Algebraic degree',j.algebraic_degree)
    +(j.sigma?row('sigma hash','<code>'+j.sigma+'</code>'):'')
    +(j.index_rows?row('Index rows with this sigma',j.index_rows):'')
    +(j.census_coeffs?row('Census coefficients','<code>'+j.census_coeffs+'</code>'):'')
    +(j.list_file?row('Listed in',esc(j.list_file)+', line '+j.list_line):'')
    +'</table>';
  if(j.ea_available){
    h+='<p><button id="ea">Exact EA check</button> Warning: this takes about 10 minutes when the functions are equivalent. One test runs at a time.</p><div id="eaout"></div>';
  }
  \$('out').innerHTML=h;
  if(j.ea_available) \$('ea').onclick=startEA;
}
async function startEA(){
  \$('ea').disabled=true;
  const r = await fetch('/api/ea',{method:'POST',headers:{'Content-Type':'text/plain'},body:\$('in').value});
  const j = await r.json();
  if(!r.ok){\$('eaout').textContent=j.error;return;}
  poll(j.id);
}
async function poll(id){
  const r = await fetch('/api/ea/'+id); const j = await r.json();
  \$('eaout').textContent = j.state==='done'||j.state==='failed' ? j.message+' ('+j.seconds+' s)'
      : 'EA test against '+j.target+': '+j.state+', '+j.seconds+' s ...';
  if(j.state==='queued'||j.state==='running') setTimeout(()=>poll(id),5000);
}
\$('go').onclick=classify;
</script>
</body></html>
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
        elseif a == "--host"
            host = args[i + 1]; i += 2
        else
            error("unknown argument $a (use --port P, --host H)")
        end
    end
    serve(; host = host, port = port)
end

end # module

if abspath(PROGRAM_FILE) == @__FILE__
    APN8Web.main()
end
