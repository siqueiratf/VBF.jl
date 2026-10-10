"""Finite n=8 parameter coverage, with independent APN tests and separating invariants.

Run from the root project: julia --compiled-modules=no --startup-file=no --project=. \
    packages/VBFSearch/tools/literature/check_families.jl OUTPUT_DIR [BASELINE_DIR]
This does not classify equal signatures or change the reference database.
"""
module FamilyCoverage
using VBF, SHA, TOML, Dates
using VBFSearch: DiscoveryEvidence
using .DiscoveryEvidence
const ROOT = normpath(joinpath(@__DIR__, "../../../.."))
module Calderini
include("../../../../papers/2021/Calderini_202100/helpers.jl")
end
module Gologlu
include("../../../../papers/2022/Gologlu_202207/helpers.jl")
end
module Li
include("../../../../papers/2022/Li_202207/theorem2.jl")
end
module Shift
include("../../../../papers/2021/Budaghyan_202101/theorem3_1.jl")
end
module Sources
include("check_sources.jl")
end

"""Return four distinct solutions witnessing non-APN, or nothing after every DDT row."""
function non_apn_witness(lut)
    length(lut)==256 && all(x->x isa Integer && 0<=x<=255,lut) || error("expected 256 bytes")
    counts=zeros(Int,256)
    for a in 1:255
        fill!(counts,0)
        for x in 0:255
            b=Int(lut[x+1] ⊻ lut[(x⊻a)+1])
            counts[b+1]+=1
            if counts[b+1]>2
                xs=[y for y in 0:255 if lut[y+1] ⊻ lut[(y⊻a)+1]==b]
                return (a,b,xs[1:4]...)
            end
        end
    end
    nothing
end

"""Evaluate CLV (2023) F1/F2 as stated in arXiv:2204.07462; GF(16), modulus 0x13."""
function clv_lut(family,k,alpha)
    family in (1,2) || error("expected CLV family 1 or 2")
    family==2 && k!=1 && error("CLV F2 has fixed q=2")
    pow(x,e)=gf_pow(x,e,4;modulus=19)
    mul(x,y)=gf_mul(x,y,4;modulus=19)
    q=1<<k
    f(x,y)=family==1 ? pow(x,q+1) ⊻ mul(x,pow(y,q)) ⊻ mul(alpha,pow(y,q+1)) :
        pow(x,3) ⊻ mul(x,y) ⊻ mul(x,pow(y,2)) ⊻ mul(alpha,pow(y,3))
    g(x,y)=family==1 ? pow(x,q*q+1) ⊻ mul(alpha,mul(pow(x,q*q),y)) ⊻
        mul(pow(1⊻alpha,q),mul(x,pow(y,q*q))) ⊻ mul(alpha,pow(y,q*q+1)) :
        pow(x,5) ⊻ mul(x,y) ⊻ mul(alpha,mul(pow(x,2),pow(y,2))) ⊻
        mul(alpha,mul(pow(x,4),y)) ⊻ mul(pow(1⊻alpha,2),mul(x,pow(y,4))) ⊻ mul(alpha,pow(y,5))
    UInt8[f(x,y) | (g(x,y)<<4) for y in 0:15 for x in 0:15]
end

"""Visit the declared finite domains; failed APN criteria are tested, not silently filtered."""
function visit_parameters(visit)
    for d in 1:255
        visit("power", "d=$d", gf_monomial_lut(8,d;modulus=285))
    end
    for a in 1:255
        lut=UInt8[gf_pow(x,3,8;modulus=285) ⊻ gf_mul(gf_pow(a,254,8;modulus=285),
            gf_trace(gf_mul(gf_pow(a,3,8;modulus=285),gf_pow(x,9,8;modulus=285),8;modulus=285),8;modulus=285),8;modulus=285) for x in 0:255]
        visit("bcl_trace", "a=$a", lut)
    end
    for i in (1,3), j in 0:3, a in 1:15
        visit("zhou_pott", "i=$i,j=$j,alpha=$a", Calderini.zhou_pott_sbox(4,i,j,a;modulus=19).lut)
    end
    for i in (1,3), a in 0:15, b in 1:15
        visit("taniguchi", "i=$i,a=$a,b=$b", taniguchi_apn(4,i,a,b;modulus=19).lut)
    end
    for i in (1,3), beta in 0:15, gamma in 0:15, delta in 0:15
        visit("carlet", "i=$i,beta=$beta,gamma=$gamma,delta=$delta",
            Gologlu.biprojective_sbox(4,0,(0,0,1,0),i,(1,beta,gamma,delta);modulus=19).lut)
    end
    for i in (1,3)
        visit("gologlu_f1", "i=$i", Gologlu.biprojective_sbox(4,i,(1,0,1,1),2i,(1,1,0,1);modulus=19).lut)
    end
    for k in (1,3), alpha in 0:15
        visit("clv_f1", "k=$k,alpha=$alpha", clv_lut(1,k,alpha))
    end
    for alpha in 0:15
        visit("clv_f2", "alpha=$alpha", clv_lut(2,1,alpha))
    end
    visit("li_bivariate", "m=4", Li.theorem2_sbox(4;modulus=19).lut)
    for k in (1,3,5,7)
        visit("shi_peng_zheng", "k=$k", Sources.shi_lut(k))
    end
    for i in (1,3), b in 0:15, c in 0:15
        visit("calderini_theorem6_2", "i=$i,b=$b,c=$c", Calderini.theorem6_2_sbox(4,i,b,c;modulus=19).lut)
    end
    # The 2026 criteria paper also studies non-coprime exponent indices. Include
    # those indices here, without assuming that the older APN theorem applies.
    for i in 0:3, h in 0:3, k in 0:3, r in 0:3, b in 0:15, c in 1:15
        visit("calderini_f1", "i=$i,h=$h,k=$k,r=$r,b=$b,c=$c", Calderini.f1_sbox(4,i,h,k,r,b,c;modulus=19).lut)
    end
    for i in 0:3, k in 0:3, r in 0:3, c in 1:15
        visit("calderini_f2", "i=$i,k=$k,r=$r,c=$c", Calderini.f2_sbox(4,i,k,r,c;modulus=19).lut)
    end
    for (label,terms) in Shift.TABLE1_ENTRIES
        visit("generalized_shift_table1", label, Shift.zeta_poly_lut(8,terms;modulus=285))
    end
end

const DOMAIN_COUNTS = Dict("power"=>255, "bcl_trace"=>255,"zhou_pott"=>120,"taniguchi"=>480,
    "carlet"=>8192,"gologlu_f1"=>2,"clv_f1"=>32,"clv_f2"=>16,"li_bivariate"=>1,
    "shi_peng_zheng"=>4,"calderini_theorem6_2"=>512,"calderini_f1"=>61440,
    "calderini_f2"=>960,"generalized_shift_table1"=>12)

"""Fingerprint executable dependencies and private paper inputs used to audit formulas."""
function source_hashes()
    paths=String[@__FILE__,joinpath(@__DIR__, "family_coverage.toml"),joinpath(ROOT,"Project.toml"),joinpath(ROOT,"Manifest.toml")]
    for folder in ("packages/VBF/src","packages/VBFCatalog/src","packages/VBFCatalog/tools/reference","packages/VBFSearch/src")
        append!(paths,[joinpath(dir,f) for (dir,_,fs) in walkdir(joinpath(ROOT,folder)) for f in fs if endswith(f,".jl")])
    end
    push!(paths,joinpath(@__DIR__, "../../src/evidence.jl"),joinpath(@__DIR__, "check_sources.jl"))
    for folder in ("papers/2021/Calderini_202100","papers/2022/Gologlu_202207","papers/2022/Li_202207","papers/2021/Budaghyan_202101",
                   "papers/2025/Gologlu_202503","papers/2022/Zheng_202211","papers/2019/Taniguchi_201909")
        append!(paths,[joinpath(dir,f) for (dir,_,fs) in walkdir(joinpath(ROOT,folder)) for f in fs if endswith(f,".jl") || endswith(f,".tex")])
    end
    Dict(relpath(normpath(p),ROOT)=>filehash(p) for p in paths)
end

"""Write completed-domain evidence. Partial output never receives a completed report."""
function check_families(outdir,baseline=joinpath(ROOT,"data/apn/archive/census/results/signature_rebuild"))
    mkpath(outdir)
    any(isfile(joinpath(outdir,p)) for p in ("report.toml","parameters.tsv","luts.tsv")) && error("use a new output directory")
    hashes=source_hashes()
    ledger=TOML.parsefile(joinpath(@__DIR__, "family_coverage.toml"))
    downloads=joinpath(ROOT,"data/apn/archive/census/results/literature_family_coverage")
    for (path,expected) in ledger["downloaded_source_sha256"]
        filehash(joinpath(downloads,path))==expected || error("downloaded paper differs: $path")
    end
    reference=open_reference(baseline)
    cache=Dict{String,Dict{String,Any}}()
    totals=Dict(name=>Dict("parameters"=>0,"apn"=>0,"quadratic_apn"=>0,"absent"=>0) for name in keys(DOMAIN_COUNTS))
    signatures=Dict(name=>Set{String}() for name in keys(DOMAIN_COUNTS))
    missing=Dict{String,String}()
    started=now(UTC)
    try
        open(joinpath(outdir,"luts.tsv"),"w") do luts
            open(joinpath(outdir,"parameters.tsv"),"w") do parameters
                println(luts,"lut_sha256\tlut_hex\tapn\tdegree\tsigma_hash\treference_signature_match\tnon_apn_witness")
                println(parameters,"family\tparameters\tlut_sha256\tapn\tquadratic\tsigma_hash\treference_signature_match")
                visit_parameters() do family,params,input
                    lut=UInt8.(input); id=lut_id(lut)
                    p=get!(cache,id) do
                        witness=non_apn_witness(lut)
                        result=if witness===nothing
                            result=classify(lut,reference)
                            result["apn"] || error("APN verifier disagreement")
                            result
                        else
                            Dict{String,Any}("apn"=>false,"quadratic"=>false,"non_apn_witness"=>join(witness,','))
                        end
                        println(luts,join((id,bytes2hex(lut),result["apn"],get(result,"algebraic_degree",""),
                            get(result,"sigma_hash",""),get(result,"reference_signature_match",""),
                            witness===nothing ? "" : join(witness,',')),'\t'))
                        result
                    end
                    total=totals[family]; total["parameters"]+=1
                    total["apn"]+=p["apn"]; total["quadratic_apn"]+=p["apn"] && p["quadratic"]
                    if p["apn"] && p["quadratic"]
                        sigma=p["sigma_hash"]; push!(signatures[family],sigma)
                        if !p["reference_signature_match"]
                            total["absent"]+=1; missing[sigma]=bytes2hex(lut)
                        end
                    elseif p["apn"] && family!="power"
                        error("nonquadratic APN in quadratic formula: $family $params")
                    end
                    println(parameters,join((family,params,id,p["apn"],p["quadratic"],get(p,"sigma_hash",""),get(p,"reference_signature_match","")),'\t'))
                    if total["parameters"]==DOMAIN_COUNTS[family]
                        flush(luts);flush(parameters)
                        println(family,": ",total,"; signatures=",length(signatures[family]));flush(stdout)
                    end
                end
            end
        end
        all(totals[name]["parameters"]==expected for (name,expected) in DOMAIN_COUNTS) || error("incomplete domain")
        hashes==source_hashes() || error("audit source changed during execution")
        report=Dict{String,Any}("completed"=>true,"started_utc"=>string(started),"finished_utc"=>string(now(UTC)),
            "julia_version"=>string(VERSION),"threads"=>Threads.nthreads(),"source_sha256"=>hashes,
            "reference"=>reference.metadata,"parameters_sha256"=>filehash(joinpath(outdir,"parameters.tsv")),
            "luts_sha256"=>filehash(joinpath(outdir,"luts.tsv")),"unique_exact_luts"=>length(cache),
            "parameters"=>sum(t["parameters"] for t in values(totals)),"distinct_absent_signatures"=>length(missing),
            "downloaded_source_sha256"=>ledger["downloaded_source_sha256"],
            "missing_luts"=>missing,"families"=>totals,"family_signatures"=>Dict(k=>sort(collect(v)) for (k,v) in signatures),
            "guarantee"=>"All APN members of the declared finite domains were checked. Equal signatures do not certify equivalence.",
            "literature_complete"=>false)
        open(io->TOML.print(io,report;sorted=true),joinpath(outdir,"report.toml.tmp"),"w")
        mv(joinpath(outdir,"report.toml.tmp"),joinpath(outdir,"report.toml"))
        report
    finally
        close_reference(reference)
    end
end
end
if abspath(PROGRAM_FILE)==@__FILE__
    length(ARGS) in (1,2) || error("expected OUTPUT_DIR [BASELINE_DIR]")
    FamilyCoverage.check_families(abspath(ARGS[1]),ARGS[2:end]...)
end
