"""
    SearchConfig(; output, method=:v5, inputs=[], corpora=[], duration=28800, workers=1, ...)

Immutable experiment configuration. `parents`, `seed`, `target_b6`, `bent`,
`ea_representatives`, and `orbit_duration` define the frozen construction plan.
`corpora` selects catalog bulk sources; it is exclusive with explicit `inputs`.
Duration, worker count, slice budget and chunk size may change on resume.
`workers` requires Julia to start with at least that many threads.
"""
struct SearchConfig
    output::String
    method::Symbol
    inputs::Vector{String}
    corpora::Vector{String}
    reference::String
    supplement::String
    duration::Float64
    workers::Int
    slice::Float64
    evaluations::Int
    parents::Int
    seed::Int
    chunk_size::Int
    target_b6::Int
    bent::String
    ea_representatives::Int
    orbit_duration::Float64
    resume::Bool
    function SearchConfig(; output, method=:v5, inputs=String[],corpora=String[],
            reference=get(ENV,"VBF_APN_REFERENCE",VBFCatalog.catalog_data_dir()),
            supplement=get(ENV,"VBF_APN_SUPPLEMENT",DEFAULT_SUPPLEMENT),
            duration=28800.0, workers=1, slice=60.0, evaluations=10000,
            parents=1000, seed=82026, chunk_size=128, target_b6=52, bent="max",
            ea_representatives=0, orbit_duration=0.0, resume=false)
        Symbol(method) in (:v5,:switching) || throw(ArgumentError("method must be v5 or switching"))
        all(x->isfinite(x)&&x>0,(duration,slice)) || throw(ArgumentError("time budgets must be positive and finite"))
        all(>(0),(workers,evaluations,parents,chunk_size)) || throw(ArgumentError("enumeration limits must be positive"))
        seed>=0 && 0<=target_b6<=63 || throw(ArgumentError("invalid seed or target bent count"))
        ea_representatives>=0 && isfinite(orbit_duration) && orbit_duration>=0 &&
            (ea_representatives==0 || orbit_duration>0) || throw(ArgumentError("invalid orbit budget"))
        if bent!="max"
            counts=tryparse.(Int,split(bent,','))
            all(x->x!==nothing && 0<=x<=31,counts) || throw(ArgumentError("bent must be max or counts in 0:31"))
        end
        isempty(output) && throw(ArgumentError("output directory is required"))
        isempty(inputs) || isempty(corpora) || throw(ArgumentError("select corpus seeds or explicit inputs"))
        all(!isempty,corpora) || throw(ArgumentError("empty corpus name"))
        new(abspath(output),Symbol(method),abspath.(inputs),unique(String.(corpora)),abspath(reference),
            isempty(supplement) ? "" : abspath(supplement),Float64(duration),Int(workers),
            Float64(slice),Int(evaluations),Int(parents),Int(seed),Int(chunk_size),
            Int(target_b6),String(bent),Int(ea_representatives),Float64(orbit_duration),Bool(resume))
    end
end

# TOML is the boundary representation; construction validates it once.
config_dict(c::SearchConfig)=Dict(
    "outdir"=>c.output,"method"=>string(c.method),"input"=>copy(c.inputs),"corpus"=>copy(c.corpora),
    "baseline"=>c.reference,"supplement"=>c.supplement,
    "wall-seconds"=>string(c.duration),"workers"=>string(c.workers),
    "seconds"=>string(c.slice),"evaluations"=>string(c.evaluations),
    "limit"=>string(c.parents),"seed"=>string(c.seed),"chunk-x"=>string(c.chunk_size),
    "target-b6"=>string(c.target_b6),"v5-bent"=>c.bent,
    "ea-representatives"=>string(c.ea_representatives),
    "orbit-seconds"=>string(c.orbit_duration),"resume"=>string(c.resume))

function config_from_dict(d)
    SearchConfig(output=d["outdir"],method=Symbol(d["method"]),inputs=get(d,"input",String[]),corpora=get(d,"corpus",String[]),
        reference=d["baseline"],supplement=d["supplement"],
        duration=parse(Float64,d["wall-seconds"]),workers=parse(Int,d["workers"]),
        slice=parse(Float64,d["seconds"]),evaluations=parse(Int,d["evaluations"]),
        parents=parse(Int,d["limit"]),seed=parse(Int,d["seed"]),chunk_size=parse(Int,d["chunk-x"]),
        target_b6=parse(Int,d["target-b6"]),bent=d["v5-bent"],
        ea_representatives=parse(Int,d["ea-representatives"]),orbit_duration=parse(Float64,d["orbit-seconds"]),
        resume=d["resume"]=="true")
end

"""
    resume(directory; duration=28800, workers=1, slice=60, evaluations=10000, chunk_size=128)

Continue the frozen experiment. Semantic parameters and reference locations are
recovered from its manifest; source, input and reference identities are checked.
"""
function resume(directory; duration=28800.0,workers=1,slice=60.0,evaluations=10000,chunk_size=128)
    search(resume_config(directory;duration,workers,slice,evaluations,chunk_size))
end

function resume_config(directory;duration=28800.0,workers=1,slice=60.0,evaluations=10000,chunk_size=128)
    identity=TOML.parsefile(joinpath(directory,"manifest.toml"))["identity"]
    d=config_dict(SearchConfig(output=directory;duration,workers,slice,evaluations,chunk_size))
    merge!(d,identity["configuration"])
    locations=identity["reference_locations"]
    d["baseline"]=locations["baseline"];d["supplement"]=locations["supplement"];d["resume"]="true"
    config_from_dict(d)
end
