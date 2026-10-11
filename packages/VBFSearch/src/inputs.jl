"""Reuse the established TSV decoder/sampler and bind prior verification artifacts to frozen inputs."""
module DiscoveryInputs
using SHA,TOML,VBF,VBFCatalog,Random,SQLite,DBInterface
using ..DiscoveryEvidence
const ROOT=normpath(joinpath(@__DIR__,"../../.."))
const DEFAULT_REFERENCE=VBFCatalog.catalog_data_dir()
const DEFAULT_SUPPLEMENT=""
export ROOT, DEFAULT_REFERENCE, DEFAULT_SUPPLEMENT, candidate_lut, catalog_seeds,
       load_study, each_candidate, validated_study, source_fingerprint, implementation_fingerprint

"""Materialize catalog seeds with exact LUT identity and VBF verification."""
function catalog_seeds(path;corpora=String[],parents=1000,seed=82026)
    catalogpath=VBFCatalog.catalog_path()
    db=SQLite.DB("file:"*abspath(catalogpath)*"?mode=ro")
    seen=Set{String}();count=0
    digest=filehash(catalogpath)
    try
        foreach(_->nothing,DBInterface.execute(db,"BEGIN"))
        open(path,"w") do io
            println(io,"sigma_hash\tlut_hex\tcatalog_id\tcatalog_sha256")
            function save(F,origin)
                id=lut_id(F.lut);id in seen && return
                p=properties(F.lut)
                p["apn"] && p["quadratic"] || error("invalid catalog seed $origin")
                println(io,join((p["sigma_hash"],p["lut_hex"],origin,digest),'\t'))
                push!(seen,id);count+=1
            end
            if isempty(corpora)
                for row in VBFCatalog.list_functions(db;n=8,is_apn=true)
                    row.algebraic_degree==2 || continue
                    save(VBFCatalog.load_sbox(db,row.id),"functions:"*string(row.id))
                end
            else
                rng=Xoshiro(seed)
                tables=Dict{Int,Vector{Vector{Int}}}()
                for name in corpora
                    info=VBFCatalog.corpus_info(db,name)
                    info!==nothing && info.n==info.m==8 && info.degree==2 || error("expected a quadratic (8,8)-APN corpus: $name")
                    k=min(info.member_count,cld(parents,length(corpora)))
                    selected=sort!(randperm(rng,info.member_count)[1:k])
                    tab=get!(()->monomial_power_table(8,info.modulus),tables,info.modulus)
                    for member in selected
                        save(VBFCatalog.corpus_function(db,name,member;powtab=tab),name*":"*string(member))
                    end
                end
            end
        end
        filehash(catalogpath)==digest || error("catalog changed during seed extraction")
        foreach(_->nothing,DBInterface.execute(db,"COMMIT"))
    finally
        SQLite.close(db)
    end
    count>0 || error("catalog has no quadratic eight-bit APN seeds")
    count
end

"""Deterministic reservoir sampling; explicit inputs select seeds regardless of old labels."""
function load_study(paths,per_source,rng)
    seen=Set{String}();seeds=Tuple{String,String}[]
    for path in paths
        pool=Tuple{String,String}[];eligible=0
        each_candidate(path) do row
            length(row.hash)==64 || error("invalid signature at $path:$(row.line)")
            push!(seen,row.hash);eligible+=1
            j=eligible<=per_source ? eligible : rand(rng,1:eligible)
            if j<=per_source
                item=(row.hash,row.payload)
                eligible<=per_source ? push!(pool,item) : (pool[j]=item)
            end
        end
        append!(seeds,pool)
    end
    unique!(seeds)
    seen,seeds
end

source_fingerprint(paths)=Dict(string(i)*":"*basename(p)=>filehash(p) for (i,p) in enumerate(paths))

"""Validate each supplied LUT and signature using VBF, binding the result to its file digest."""
function validated_study(paths)
    known=Set{String}();proofs=Dict{String,Any}[]
    powtab=monomial_power_table(8,conway_polynomial(8))
    for path in paths
        digest=filehash(path);records=0
        each_candidate(path) do row
            p=properties(candidate_lut(row.payload;powtab))
            p["apn"] && p["quadratic"] || error("invalid quadratic-APN study input $path:$(row.line)")
            p["sigma_hash"]==row.hash || error("stored signature mismatch $path:$(row.line)")
            push!(known,row.hash);records+=1
        end
        filehash(path)==digest || error("study input changed during validation: $path")
        push!(proofs,Dict("path"=>abspath(path),"sha256"=>digest,"records"=>records,"verification"=>"VBF properties and sigma hash"))
    end
    known,Dict("sources"=>proofs,"distinct_signatures"=>length(known))
end

include("provenance.jl")
implementation_fingerprint()=source_fingerprint_impl(ROOT)

end
