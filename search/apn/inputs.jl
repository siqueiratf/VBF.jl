"""Reuse the established TSV decoder/sampler and bind prior verification artifacts to frozen inputs."""
module DiscoveryInputs
using SHA,TOML,VBF,VBFCatalog,Random
using ..DiscoveryEvidence
const ROOT=normpath(joinpath(@__DIR__,"../.."))
const DEFAULT_REFERENCE=get(ENV,"VBF_APN_REFERENCE",joinpath(ROOT,"data/apn/reference"))
const DEFAULT_SUPPLEMENT=get(ENV,"VBF_APN_SUPPLEMENT",joinpath(ROOT,"data/apn/supplement.tsv"))
export ROOT, DEFAULT_REFERENCE, DEFAULT_SUPPLEMENT, candidate_lut, catalog_seeds,
       load_study, each_candidate, validated_study, source_fingerprint, implementation_fingerprint

"""Decode a 256-byte LUT, 28-byte Boolean quadratic ANF, or catalog encoding."""
function candidate_lut(encoded)
    bytes=hex2bytes(encoded)
    length(bytes)==256 && return bytes
    length(bytes)==37 && return UInt8.(decode_quadratic_lut(bytes,8,conway_polynomial(8)))
    length(bytes)==28 || error("expected 28/37 coefficient bytes or 256 LUT bytes")
    lut=zeros(UInt8,256);t=0
    for a in 0:7,b in a+1:7
        t+=1
        for x in 0:255
            ((x>>a)&(x>>b)&1)==0 || (lut[x+1] ⊻= bytes[t])
        end
    end
    lut
end

"""Materialize catalog seeds with exact LUT identity and independent verification."""
function catalog_seeds(path)
    catalogpath=VBFCatalog.catalog_path()
    db=VBFCatalog.SQLite.DB("file:"*abspath(catalogpath)*"?mode=ro")
    seen=Set{String}();count=0
    digest=filehash(catalogpath)
    try
        foreach(_->nothing,VBFCatalog.DBInterface.execute(db,"BEGIN"))
        open(path,"w") do io
            println(io,"sigma_hash\tlut_hex\tcatalog_id\tcatalog_sha256")
            for row in VBFCatalog.list_functions(db;n=8,is_apn=true)
                row.algebraic_degree==2 || continue
                F=VBFCatalog.load_sbox(db,row.id)
                id=lut_id(F.lut);id in seen && continue
                p=properties(F.lut)
                p["apn"] && p["quadratic"] || error("invalid catalog seed $(row.id)")
                println(io,join((p["sigma_hash"],p["lut_hex"],row.id,digest),'\t'))
                push!(seen,id);count+=1
            end
        end
        filehash(catalogpath)==digest || error("catalog changed during seed extraction")
        foreach(_->nothing,VBFCatalog.DBInterface.execute(db,"COMMIT"))
    finally
        VBFCatalog.SQLite.close(db)
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

function each_candidate(f,path)
    payloadcol,statuscol=2,nothing
    names=String[]
    for (number,line) in enumerate(eachline(path))
        isempty(strip(line)) && continue
        cols=split(line,'\t')
        if number==1 && cols[1] in ("sigma","sigma_hash")
            names=String.(cols)
            payloadcol=something(findfirst(c->c in ("coeffs","lut_hex","lut"),cols))
            statuscol=findfirst(==("status"),cols)
            continue
        end
        col=length(cols)>=3 && length(cols[3])==512 ? 3 : payloadcol
        f((hash=String(cols[1]),payload=String(cols[col]),
            status=statuscol===nothing ? "unlabelled" : String(cols[statuscol]),line=number,
            fields=isempty(names) ? Dict("original_row"=>String(line)) : Dict(k=>String(v) for (k,v) in zip(names,cols))))
    end
end

source_fingerprint(paths)=Dict(string(i)*":"*basename(p)=>filehash(p) for (i,p) in enumerate(paths))

"""Reuse only a completed, digest-matching independent report; verify every other supplied record."""
function validated_study(paths,baseline; reuse=true)
    reportpath=joinpath(baseline,"candidate_comparison.toml")
    trusted=Set{String}()
    if reuse && isfile(reportpath)
        report=TOML.parsefile(reportpath)
        report["signature_mismatches"]==0 || error("prior verification report contains signature mismatches")
        report["fresh_union_sha256"]==filehash(joinpath(baseline,"fresh_union.sqlite")) || error("prior candidate report reference changed")
        union!(trusted,values(report["candidate_sha256"]))
    end
    known=Set{String}()
    proofs=Dict{String,Any}[]
    for path in paths
        digest=filehash(path)
        reused=digest in trusted
        records=0
        each_candidate(path) do row
            hash=row.hash
            if !reused
                p=properties(candidate_lut(row.payload))
                p["apn"] && p["quadratic"] || error("invalid quadratic-APN study input $path:$(row.line)")
                p["sigma_hash"]==hash || error("stored signature mismatch $path:$(row.line)")
            end
            push!(known,hash);records+=1
        end
        filehash(path)==digest || error("study input changed during verification: $path")
        push!(proofs,Dict("path"=>abspath(path),"sha256"=>digest,"records"=>records,
            "verification"=>reused ? "digest-bound independent candidate report" : "independent full DDT, degree and polar/signature recheck"))
    end
    known,Dict("sources"=>proofs,"prior_report_sha256"=>isfile(reportpath) ? filehash(reportpath) : "none",
        "distinct_signatures"=>length(known))
end

include("provenance.jl")
implementation_fingerprint()=source_fingerprint_impl(ROOT)

end
