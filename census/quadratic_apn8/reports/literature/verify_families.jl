"""Standard-library-only replay of APN/signature evidence and finite parameter counts.

Usage: julia --startup-file=no verify_families.jl OUTPUT_DIR
This verifies stored LUTs and parameter accounting. Formula/source review and
reference-database membership are separate steps; it proves neither from hashes.
"""
module VerifyFamilies
using SHA,TOML
include("../../rebuild_corpus/signature.jl")
using .IndependentSignature
sha(path)=bytes2hex(open(SHA.sha256,path))

"""Check the APN definition for all nonzero input differences."""
function apn(lut)
    counts=zeros(Int,256)
    for a in 1:255
        fill!(counts,0)
        for x in 0:255
            b=Int(lut[x+1] ⊻ lut[(x⊻a)+1])
            counts[b+1]+=1
            counts[b+1]<=2 || return false
        end
    end
    true
end

"""Replay every accepted LUT and every rejection witness, including accounting crosschecks."""
function verify(outdir)
    report=TOML.parsefile(joinpath(outdir,"report.toml"))
    report["completed"] || error("incomplete run")
    for filename in ("parameters","luts")
        sha(joinpath(outdir,filename*".tsv"))==report[filename*"_sha256"] || error("modified $filename")
    end
    luts=Dict{String,NamedTuple}();w=Workspace();accepted=0
    for line in Iterators.drop(eachline(joinpath(outdir,"luts.tsv")),1)
        id,hex,flag,degree,sigma,hit,witness=split(line,'\t';keepempty=true)
        f=hex2bytes(hex)
        length(f)==256 && bytes2hex(sha256(f))==id || error("invalid LUT")
        haskey(luts,id) && error("duplicate exact LUT evidence")
        if flag=="true"
            apn(f) || error("false APN claim")
            anf=copy(f)
            for bit in 0:7,x in 0:255
                x&(1<<bit)==0 || (anf[x+1] ⊻= anf[(x⊻(1<<bit))+1])
            end
            deg=maximum(count_ones(x) for x in 0:255 if anf[x+1]!=0)
            parse(Int,degree)==deg || error("false degree")
            if deg==2
                bytes2hex(signature(w,f))==sigma || error("false sigma")
            else
                isempty(sigma) || error("nonquadratic signature comparison")
            end
            isempty(witness) || error("contradictory rejection")
            accepted+=1
        elseif flag=="false"
            a,b,xs...=parse.(Int,split(witness,','))
            1<=a<=255 && 0<=b<=255 && length(xs)==4 && length(unique(xs))==4 || error("invalid rejection witness")
            all(x->0<=x<=255 && f[x+1] ⊻ f[(x⊻a)+1]==b,xs) || error("false rejection")
            isempty(degree) && isempty(sigma) && isempty(hit) || error("unsupported rejected-LUT claims")
        else
            error("invalid APN flag")
        end
        luts[id]=(apn=flag,sigma=String(sigma),hit=String(hit))
    end
    length(luts)==report["unique_exact_luts"] || error("LUT count mismatch")
    totals=Dict(k=>Dict("parameters"=>0,"apn"=>0,"quadratic_apn"=>0,"absent"=>0) for k in keys(report["families"]))
    sigmas=Dict(k=>Set{String}() for k in keys(totals));seen=Set{Tuple{String,String}}()
    for line in Iterators.drop(eachline(joinpath(outdir,"parameters.tsv")),1)
        family,params,id,flag,quad,sigma,hit=split(line,'\t';keepempty=true)
        (String(family),String(params)) in seen && error("repeated parameters")
        push!(seen,(family,params));p=luts[id]
        (flag,sigma,hit)==(p.apn,p.sigma,p.hit) || error("parameter/evidence mismatch")
        (quad=="true")==!isempty(sigma) || error("incorrect quadratic APN flag")
        t=totals[family];t["parameters"]+=1;t["apn"]+=flag=="true";t["quadratic_apn"]+=quad=="true"
        if !isempty(sigma)
            push!(sigmas[family],sigma);t["absent"]+=hit=="false"
        end
    end
    totals==report["families"] || error("family count mismatch")
    length(seen)==report["parameters"] || error("parameter count mismatch")
    all(sort(collect(s))==report["family_signatures"][name] for (name,s) in sigmas) || error("family signature mismatch")
    absent=Set(s for p in values(luts) for s in (p.sigma,) if !isempty(s) && p.hit=="false")
    absent==Set(keys(report["missing_luts"])) && length(absent)==report["distinct_absent_signatures"] || error("absence accounting mismatch")
    println("Verified $(length(seen)) parameter rows, $(length(luts)) exact LUTs, $accepted APN LUTs; all rejection witnesses and quadratic signatures replayed.")
    true
end
end
if abspath(PROGRAM_FILE)==@__FILE__
    length(ARGS)==1 || error("expected OUTPUT_DIR")
    VerifyFamilies.verify(abspath(ARGS[1]))
end
