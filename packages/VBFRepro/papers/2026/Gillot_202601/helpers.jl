# Implements 2 — Preliminaries and paper-specific input conventions.
# Paper: Gillot and Langevin (2026), "Observation of known APNs", arXiv:2601.11247v1
# Section: 2 — Preliminaries and paper-specific input conventions
#
# Pseudocode:
#   1. Parse the primary letter ANFs; apply the library Möbius transform.
#   2. Compute exact normalized fourth moments and preserve evidence provenance.
# VBF API used: mobius!, walsh_hadamard, rank_f2, print_banner
using VBF, TOML, SHA, Dates, Random

const GL_SOURCE_CAPTURE = let
    root = normpath(joinpath(@__DIR__,"..","..","..","..",".."))
    paths = String[]
    for (directory,_,names) in walkdir(joinpath(root,"packages","VBF","src"))
        append!(paths,[joinpath(directory,n) for n in names if endswith(n,".jl")])
    end
    append!(paths,[joinpath(@__DIR__,n) for n in readdir(@__DIR__) if endswith(n,".jl")])
    hashes=Dict(relpath(path,root)=>bytes2hex(sha256(read(path))) for path in sort!(paths))
    sources=Dict{String,Any}()
    for (name,relative) in (("pdf","input/paper.pdf"),("tex","input/tex_source/knownapn.tex"))
        path=joinpath(@__DIR__,relative)
        sources[name]=Dict("available"=>isfile(path),"path"=>relative,
            "sha256"=>isfile(path) ? bytes2hex(sha256(read(path))) : "unavailable")
    end
    (;hashes,sources,captured_at_utc=string(Dates.now(Dates.UTC)))
end

"""Evaluate the author’s letter-encoded Boolean ANF (Gillot–Langevin, Section 2)."""
function gl_boolean_anf(expression::AbstractString,n::Int=6)
    coefficients = zeros(UInt8,1<<n)
    isempty(strip(expression)) && return VBFTable{n,1}(coefficients)
    for term in split(strip(expression),'+')
        mask = 0
        if term != "1"
            isempty(term) && throw(ArgumentError("empty ANF monomial"))
            for c in term
                position = Int(c)-Int('a')
                0 <= position < n || throw(ArgumentError("invalid ANF variable"))
                mask |= 1<<position
            end
        end
        coefficients[mask+1] ⊻= 1
    end
    return VBFTable{n,1}(mobius!(coefficients))
end

"""Load primary author ANFs without interpreting their stabilizer conventions (Section 2)."""
function gl_author_boolean_classes(path=joinpath(@__DIR__,"input","author_data","class-2-6.txt");
    limit::Integer=typemax(Int),n::Int=6,timeout_seconds::Real=Inf)
    limit >= 0 && timeout_seconds>=0 || throw(ArgumentError("invalid artifact bounds"))
    started=time_ns()
    functions = VBFTable{n,1,UInt8}[]
    expressions = String[]
    open(path) do io
        for line in eachline(io)
            (time_ns()-started)*1e-9>=timeout_seconds && break
            startswith(line,"anf=") || continue
            length(functions) >= limit && break
            expression = strip(line[5:end])
            push!(functions,gl_boolean_anf(expression,n))
            push!(expressions,expression)
        end
    end
    return (;functions,expressions,path=abspath(path),sha256=bytes2hex(sha256(read(path))),
        elapsed_seconds=(time_ns()-started)*1e-9)
end

"""Compute exact normalized fourth moment κ(f), Gillot–Langevin, Section 2."""
function gl_kappa(f::VBFTable{N,1}) where {N}
    W = walsh_hadamard([iszero(v) ? 1 : -1 for v in f.lut])
    return sum(Int128(w)^4 for w in W)//Int128(length(f))^3
end

"""Extract one zero-based nonzero output component (Gillot–Langevin, Section 2)."""
function gl_component(F::VBF.AbstractTruthTable{N,M},b::Integer) where {N,M}
    0 < b < 1<<M || throw(ArgumentError("component mask is outside nonzero range"))
    return VBFTable{N,1}(UInt8[parity(Int(v)&b) for v in F.lut])
end

"""Check a recovered graph mapping independently (GL classifications; KS native backend)."""
function gl_verify_graph_map(F::VBF.AbstractTruthTable{N,M},G::VBF.AbstractTruthTable{N,M},A;
    relation=:ea) where {N,M}
    inputbits(A)==N+M || return false
    rank_f2(UInt32.(A.linear.cols);nbits=N+M)==N+M || return false
    relation===:ea && !all(j->UInt32(A.linear(UInt32(1)<<j))>>M==0,0:M-1) && return false
    image = sort!(UInt32[A((UInt32(x)<<M)|UInt32(F.lut[x+1])) for x in 0:length(F)-1])
    target = sort!(UInt32[(UInt32(x)<<M)|UInt32(G.lut[x+1]) for x in 0:length(G)-1])
    return image==target
end

"""Consume portable six-bit closure evidence without including another paper’s scripts."""
function gl_load_known_representatives(path::AbstractString;require_complete=true)
    data = TOML.parsefile(path)
    witnesses = get(data,"witnesses",Any[])
    dataset=get(data,"dataset",Any[])
    source_rows=Dict{String,Any}()
    for row in dataset
        label=row["label"]
        haskey(source_rows,label) && throw(ArgumentError("duplicate census dataset label"))
        source_rows[label]=row
    end
    orbit_rows=Dict{String,Any}()
    for row in get(data,"rows",Any[])
        label=row["label"]
        haskey(orbit_rows,label) && throw(ArgumentError("duplicate census orbit row"))
        orbit_rows[label]=row
    end
    representatives = SBox{6,UInt8}[]
    root_labels = String[]
    roots=Dict{String,SBox{6,UInt8}}()
    seen_targets=Set{Tuple}()
    seen_indices=Set{Tuple{String,Int}}()
    for w in witnesses
        get(w,"kind","")=="orbit_representative" || continue
        get(w,"dimension",0)==6 || throw(ArgumentError("closure dimension is not six"))
        F,G = SBox{6}(w["source_lut"]),SBox{6}(w["target_lut"])
        label=get(w,"source_label","unknown")
        haskey(source_rows,label) && haskey(orbit_rows,label) ||
            throw(ArgumentError("closure witness is not bound to a dataset/orbit row"))
        F.lut==UInt8.(source_rows[label]["lut"]) ||
            throw(ArgumentError("closure witness source does not match its dataset row"))
        target=Tuple(G.lut)
        target in seen_targets && throw(ArgumentError("duplicate closure target LUT"))
        push!(seen_targets,target)
        identifier=(label,Int(w["target_index"]))
        identifier in seen_indices && throw(ArgumentError("duplicate closure orbit index"))
        push!(seen_indices,identifier)
        A = F2AffineMap{12,UInt32}(w["linear_columns"],w["constant"])
        gl_verify_graph_map(F,G,A;relation=:ccz) || error("invalid loaded closure certificate")
        differential_uniformity(G)==2 || error("loaded representative is not APN")
        push!(representatives,G)
        push!(root_labels,label)
        roots[label]=F
    end
    row_consistency=all(get(row,"complete",false) &&
        get(row,"classes",-1)==count(==(label),root_labels) &&
        all(get(get(row,"degrees",Dict()),string(d),0)==count(
            F->algebraic_degree(F)==d,[F for (F,l) in zip(representatives,root_labels) if l==label])
            for d in 2:4) for (label,row) in orbit_rows)
    complete = get(data,"census_complete",false) && get(data,"roots_distinct",false) &&
        length(representatives)==716 && length(roots)==14 && length(source_rows)==14 &&
        length(orbit_rows)==14 && length(Set(Tuple(F.lut) for F in values(roots)))==14 && row_consistency
    require_complete && !complete && throw(ArgumentError("input does not certify the full 716-class census"))
    return (;representatives,root_labels,roots,root_order=[row["label"] for row in dataset],complete,path=abspath(path),
        sha256=bytes2hex(sha256(read(path))),provenance="loaded independently verified graph certificates")
end

"""Convert exact counters and optional values to portable GL evidence."""
gl_serial(value::Symbol)=string(value)
gl_serial(value::Rational)=Dict("numerator"=>string(numerator(value)),"denominator"=>string(denominator(value)))
gl_serial(value::BigInt)=string(value)
gl_serial(::Nothing)="unavailable"
gl_serial(value::NamedTuple)=Dict(string(k)=>gl_serial(v) for (k,v) in pairs(value))
gl_serial(value::AbstractDict)=Dict(string(k)=>gl_serial(v) for (k,v) in pairs(value))
gl_serial(value::AbstractVector)=map(gl_serial,value)
gl_serial(value::Tuple)=map(gl_serial,collect(value))
gl_serial(value)=value

"""Normalize affine additions in a Boolean component, GL’s quotient convention."""
function gl_normalize_boolean(f::VBFTable{N,1}) where {N}
    coefficients=anf(f)
    coefficients[1]=0
    for i in 0:N-1
        coefficients[(1<<i)+1]=0
    end
    return VBFTable{N,1}(mobius!(coefficients))
end

"""Use a valid Boolean EA rejection signature before certified comparison (GL Section 5)."""
function gl_boolean_signature(f::VBFTable)
    W=walsh_hadamard([iszero(v) ? 1 : -1 for v in f.lut])
    return (algebraic_degree(f),Tuple(sort!(abs.(W))))
end

"""Preserve a verified EA/CCZ graph mapping in GL evidence."""
function gl_witness(F,G,A;relation=:ea)
    gl_verify_graph_map(F,G,A;relation) || error("invalid independent graph certificate")
    return (;input_dimension=inputbits(F),output_dimension=outputbits(F),relation,
        source_lut=Int.(F.lut),target_lut=Int.(G.lut),linear_columns=Int.(A.linear.cols),
        constant=Int(A.constant),independently_verified=true)
end

"""Match a completion to known CCZ roots with verified native witnesses, GL Facts 3–6."""
function gl_classify_ccz(F::SBox,roots;max_nodes=100000,max_comparisons=100,
    timeout_seconds=60,seed=940)
    started=time_ns()
    signature=absolute_walsh_spectrum(F)
    checks=NamedTuple[]
    uncertain=false
    for (label,G) in roots
        absolute_walsh_spectrum(G)==signature || continue
        remaining=timeout_seconds-(time_ns()-started)*1e-9
        if remaining<=0 || length(checks)>=max_comparisons
            uncertain=true
            break
        end
        outcome=partition_refinement_equivalence(F,G;relation=:ccz,max_nodes,
            timeout_seconds=remaining,rng=Xoshiro(seed+length(checks)))
        push!(checks,(;label,outcome=outcome_tag(outcome),nodes=nodes_visited(outcome)))
        if !isempty(search_solutions(outcome))
            return (;status=:matched,label,checks,witness=gl_witness(F,G,
                first(search_solutions(outcome));relation=:ccz))
        end
        outcome isa BudgetHit && (uncertain=true)
    end
    return (;status=uncertain ? :inconclusive : :outside_given_roots,label="unresolved",
        checks,witness=nothing)
end

"""Hash the complete ordered finite GL input dataset, including dimensions."""
function gl_dataset_hash(functions)
    io=IOBuffer()
    for F in functions
        print(io,inputbits(F),'/',outputbits(F),':',join(Int.(F.lut),','),';')
    end
    return bytes2hex(sha256(take!(io)))
end

"""Optionally save GL evidence with source hashes, measured time and explicit coverage."""
function gl_save(name,data;save_results=false)
    save_results || return nothing
    metadata = Dict("schema"=>"vbf-gillot-202601-v1","paper"=>"Valérie Gillot and Philippe Langevin, Observation of known APNs",
        "paper_url"=>"https://arxiv.org/abs/2601.11247v1","source_hashes"=>GL_SOURCE_CAPTURE.hashes,
        "paper_sources"=>GL_SOURCE_CAPTURE.sources,"source_capture_utc"=>GL_SOURCE_CAPTURE.captured_at_utc,
        "source_capture"=>"once_when_helpers_loaded",
        "equivalence_algorithm"=>"Nikolay Kaleyski and Joakim Sunde, Efficiently deciding and recovering CCZ and EA equivalence for arbitrary vectorial Boolean functions using the partition refinement framework, ePrint 2026/940",
        "equivalence_algorithm_url"=>"https://eprint.iacr.org/2026/940",
        "julia_version"=>string(VERSION),"utc"=>string(Dates.now(Dates.UTC)),"global_conjecture_proved"=>false)
    merge!(metadata,gl_serial(data))
    mkpath(joinpath(@__DIR__,"results"))
    path = joinpath(@__DIR__,"results",name*".toml")
    open(path,"w") do io
        TOML.print(io,metadata;sorted=true)
    end
    return path
end

"""Print the GL paper scope using library report primitives."""
paper_header(io::IO=stdout)=print_banner(io,"Gillot and Langevin (2026), Observation of known APNs",
    "arXiv:2601.11247v1; finite exact checks and bounded extension searches",
    "Native Julia; global completeness and degree conjectures remain unproved")

"""Print a GL measured table/experiment coverage record."""
function gl_report(name,r,io::IO=stdout)
    print_section(io,name)
    for k in (:complete,:processed,:elapsed_seconds,:stop_reason)
        hasproperty(r,k) && print_kv(io,string(k),getproperty(r,k))
    end
    return r
end
