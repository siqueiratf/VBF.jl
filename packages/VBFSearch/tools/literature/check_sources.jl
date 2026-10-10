"""
Verify additional literature sources against a completed independent rebuild.
Usage: julia --compiled-modules=no --startup-file=no --project=. -t 8 \
    packages/VBFSearch/tools/literature/check_sources.jl DOWNLOAD_DIR BASELINE_DIR
Does not change the baseline. All output goes under DOWNLOAD_DIR.
"""
const LITERATURE_USAGE = nothing
include("../../../VBFCatalog/tools/reference/check_equivalence.jl")

function trace_lut(rho, eta)
    mul(x,y) = gf_mul(x,y,8;modulus=0x11b)
    pow(x,k) = gf_pow(x,k,8;modulus=0x11b)
    tr(x) = gf_trace(x,8;modulus=0x11b)
    Q(r,x) = tr(mul(r,x)) & tr(mul(mul(0xbd,r),x))
    c = mul(eta,pow(rho,252))
    UInt8[pow(x,3) ⊻ (eta*Q(1,x)) ⊻ (c*Q(rho,x)) for x in 0:255]
end

function shi_lut(k)
    mul(x,y) = gf_mul(x,y,4;modulus=0x13)
    pow(x,e) = gf_pow(x,e,4;modulus=0x13)
    q = 1 << k
    lut = zeros(UInt8,256)
    for x in 0:15, y in 0:15
        xy = mul(x,y)
        first = pow(x,q+1) ⊻ mul(x,pow(y,q)) ⊻ pow(y,q+1)
        second = pow(x,q*q+1) ⊻ mul(pow(x,q*q),y) ⊻ pow(y,q*q+1)
        for i in 0:k-1
            first ⊻= pow(xy,1<<i)
            second ⊻= pow(xy ⊻ pow(xy,q),1<<i)
        end
        lut[(x<<4 | y)+1] = UInt8(first<<4 | second)
    end
    lut
end

function source_lut(kind,payload)
    kind == "lut" && return hex2bytes(payload)
    kind == "polynomial" && return UInt8.(polynomial_to_lut(payload,8,0x11d))
    kind == "trace2" && return trace_lut(parse.(Int,split(payload,','))...)
    if kind == "trace1"
        theta = parse(Int,payload)
        return UInt8[gf_pow(x,3,8;modulus=0x11b) ⊻
            theta*(gf_trace(x,8;modulus=0x11b) &
                   gf_trace(gf_mul(0xbd,x,8;modulus=0x11b),8;modulus=0x11b)) for x in 0:255]
    end
    kind == "shi" && return shi_lut(parse(Int,payload))
    kind == "polynomial_pairs" || error("unknown source encoding")
    lut = zeros(UInt8,256)
    for pair in split(payload,';')
        a,e = parse.(Int,split(pair,','))
        c = gf_pow(2,a,8;modulus=0x11d)
        for x in 0:255
            lut[x+1] ⊻= UInt8(gf_mul(c,gf_pow(x,e,8;modulus=0x11d),8;modulus=0x11d))
        end
    end
    lut
end

function check_sources(root,baseline)
    inputs = joinpath(root,"inputs.tsv")
    inputs_sha = filehash(inputs)
    comparisons = TOML.parsefile(joinpath(baseline,"comparison.toml"))
    comparisons["provenance_complete"] || error("incomplete comparison baseline")
    baseline_sha = filehash(joinpath(baseline,"fresh_union.sqlite"))
    baseline_sha == comparisons["fresh_union_sha256"] || error("baseline changed")
    lines = [split(line,'\t';keepempty=true) for line in Iterators.drop(eachline(inputs),1)]
    luts = Vector{Vector{UInt8}}(undef,length(lines))
    hashes = Vector{String}(undef,length(lines))
    errors = fill("",length(lines))
    Threads.@threads :static for worker in 1:Threads.nthreads()
        w = Workspace()
        for i in worker:Threads.nthreads():length(lines)
            c = lines[i]
            lut = source_lut(c[3],c[4])
            luts[i] = lut
            isempty(c[5]) || bytes2hex(SHA.sha256(lut)) == c[5] || error("reconstruction differs: $(c[1:2])")
            try
                hashes[i] = bytes2hex(signature(w,lut))
            catch e
                errors[i] = sprint(showerror,e)
                hashes[i] = ""
                kasami = (c[1] == "andersen" && c[4] == "0,57") || (c[1] == "xanadu" && c[2] == "3")
                kasami && errors[i] == "degree 4, expected 2" || rethrow()
            end
        end
    end
    candidates = TOML.parsefile(joinpath(baseline,"candidate_comparison.toml"))
    candidate_hashes = Set{String}()
    for (path,expected) in candidates["candidate_sha256"]
        filehash(path) == expected || error("candidate file changed")
        for line in eachline(artifact_path(path))
            hash = first(split(line,'\t';limit=2))
            length(hash) == 64 && push!(candidate_hashes,hash)
        end
    end
    db = readonly(joinpath(baseline,"fresh_union.sqlite"))
    stmt = DBI.prepare(db,"SELECT 1 FROM signatures WHERE sigma_hash=? LIMIT 1")
    totals = Dict{String,Dict{String,Int}}()
    missing = Dict{String,Vector{UInt8}}()
    # Exact-LUT identities independently certify coverage of the large old list.
    # Use original-source records from the completed rebuild, not upstream labels.
    original_hashes = Set{String}()
    exact_input_hashes = Dict{String,String}()
    for filename in readdir(baseline)
        startswith(filename,"raw_") && endswith(filename,".sqlite") || continue
        filename in ("raw_beierle2025_n8.sqlite","raw_langevin_may2025.sqlite") && continue
        path = joinpath(baseline,filename)
        exact_input_hashes[filename] = filehash(path)
        original = readonly(path)
        try
            union!(original_hashes, (String(r.lut_sha256) for r in DBI.execute(original,"SELECT lut_sha256 FROM records")))
        finally
            close(original)
        end
    end
    lut_hashes = [bytes2hex(SHA.sha256(lut)) for lut in luts]
    try
        open(joinpath(root,"checks.tsv"),"w") do io
            println(io,"source\tmember\tlut_sha256\tsigma_hash\tbaseline_status\texact_original_lut\tcandidate_signature_hit\tverification_error")
            for (i,c) in enumerate(lines)
                hash = hashes[i]
                status = isempty(hash) ? "excluded" : isempty(collect(DBI.execute(stmt,(hash,)))) ? "absent" : "signature_hit"
                counts = get!(totals,String(c[1]),Dict("records"=>0,"signature_hit"=>0,"absent"=>0,"excluded"=>0))
                counts["records"] += 1; counts[status] += 1
                status == "absent" && (missing[hash]=luts[i])
                println(io,join((c[1],c[2],lut_hashes[i],hash,status,lut_hashes[i] in original_hashes,hash in candidate_hashes,errors[i]),'\t'))
            end
        end
    finally
        DBI.close!(stmt);close(db)
    end
    open(joinpath(root,"supplemental_luts.tsv"),"w") do io
        println(io,"sigma_hash\tlut_hex")
        for (hash,lut) in sort(collect(missing);by=first)
            println(io,hash,'\t',bytes2hex(lut))
        end
    end
    # Resolve small new-source lists with actual EA maps. A signature match alone
    # is not an equivalence proof. Store and independently verify each witness.
    witnesses = Dict{String,Any}[]
    public = edelpott_luts(joinpath(baseline,"sources/sboxU/sboxU/scripts/apnDB/eightBitAPN.py"))
    append!(public,[UInt8.(r.sbox.lut) for r in taniguchi_apn_representatives(4) if r.new])
    workspace = Workspace()
    public_hashes = [bytes2hex(signature(workspace,lut)) for lut in public]
    for (i,c) in enumerate(lines)
        c[1] in ("trace_product_rank1","trace_product_rank2","shi_peng_zheng","xanadu","sboxu_reprs8","kuznetsov_gb","andersen") || continue
        isempty(hashes[i]) && continue
        c[1] == "andersen" && lut_hashes[i] in original_hashes && continue
        match_indices = findall(==(hashes[i]),public_hashes)
        row = Dict{String,Any}("source"=>c[1],"member"=>c[2],"sigma_hash"=>hashes[i],"status"=>"no_edelpott_signature_match")
        for j in match_indices
            solved = solve_pair(luts[i],public[j];timeout_seconds=30.0,max_nodes=1_000_000)
            solved.status == "ea_equivalent" || continue
            merge!(row,Dict("status"=>solved.status,"public_member"=>j,"candidate_lut_hex"=>bytes2hex(luts[i]),
                "public_lut_hex"=>bytes2hex(public[j]),"cols"=>solved.cols,"constant"=>solved.constant))
            break
        end
        push!(witnesses,row)
    end
    filehash(inputs) == inputs_sha || error("extracted input changed during verification")
    all(filehash(path)==h for (path,h) in candidates["candidate_sha256"]) || error("candidate changed during verification")
    all(r["status"]=="ea_equivalent" for r in witnesses) || error("unresolved positive equivalence checks")
    code_paths = [joinpath(dir,f) for (dir,_,files) in walkdir(joinpath(REPO,"packages/VBF/src")) for f in files if endswith(f,".jl")]
    append!(code_paths,[(@__FILE__),joinpath(@__DIR__, "prepare_sources.py"),joinpath(@__DIR__, "sources.tsv"),
        joinpath(REPO,"Manifest.toml"),joinpath(@__DIR__, "../../src/verification/signature.jl"),
        joinpath(@__DIR__, "../../src/verification/ea_witness.jl")])
    report = Dict("baseline_sha256"=>baseline_sha,"inputs_sha256"=>inputs_sha,
        "candidate_report_sha256"=>filehash(joinpath(baseline,"candidate_comparison.toml")),
        "distinct_absent_signatures"=>length(missing),"absent_candidate_overlaps"=>count(h->h in candidate_hashes,keys(missing)),
        "exact_original_luts"=>count(h->h in original_hashes,lut_hashes),
        "checks_sha256"=>filehash(joinpath(root,"checks.tsv")),
        "supplemental_luts_sha256"=>filehash(joinpath(root,"supplemental_luts.tsv")),
        "original_database_sha256"=>exact_input_hashes,
        "code_sha256"=>Dict(path=>filehash(path) for path in code_paths),"sources"=>totals,"witnesses"=>witnesses)
    open(io->TOML.print(io,report;sorted=true),joinpath(root,"checks.toml"),"w")
    for (source,count) in sort(collect(totals);by=first)
        println(source,": ",count)
    end
    println("Distinct absent signatures: ",length(missing),"; verified EA maps: ",count(r->r["status"]=="ea_equivalent",witnesses),"/",length(witnesses))
end

if abspath(PROGRAM_FILE) == (@__FILE__)
    length(ARGS)==2 || error("expected download and baseline directories")
    check_sources(abspath(ARGS[1]),abspath(ARGS[2]))
end
