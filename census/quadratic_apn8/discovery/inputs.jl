"""Reuse the established TSV decoder/sampler and bind prior verification artifacts to frozen inputs."""
module DiscoveryInputs
using SHA,TOML,VBF
using ..DiscoveryEvidence
module Existing
include("../fast_switching/search.jl")
end
export Existing, each_candidate, validated_study, source_fingerprint, implementation_fingerprint

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
                p=properties(Existing.candidate_lut(row.payload))
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
implementation_fingerprint()=source_fingerprint_impl(Existing.REPO)

end
