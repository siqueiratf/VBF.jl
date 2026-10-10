# Proposition 5: finite separation from the entire inverse two-point-swap family.
# Earlier source: https://eprint.iacr.org/2011/047.pdf, Section4, Proposition4,
# Theorem1, Corollary1 and Remark2 (pages8,11,14 in PDF page numbering).
# General differential/Walsh spectra are CCZ invariants; no APN-specific theorem is used.
include(joinpath(@__DIR__,"table1.jl"))
using VBFSearch, TOML, SHA

inverse_swap_invariants(F::SBox) = (; du=differential_uniformity(F),
    nonlinearity=nonlinearity(F), differential=Tuple(sorted_pairs(differential_spectrum(F))),
    walsh=Tuple(sorted_pairs(absolute_walsh_spectrum(F))))

"""Exact EA certificate H_(u,v) -> H_(1,v/u), for u,v nonzero and distinct.
Input multiplication by u^-1 and output multiplication by u are bijective GF(2) maps.
The identity is u*H_(u,v)(u*x)=H_(1,v/u)(x), including both swapped points and zero.
"""
function inverse_swap_scaling_witness(u::Int,v::Int,N::Int;modulus=primitive_polynomial(N))
    N==8 || throw(ArgumentError("the independent witness replayer supports eight-bit functions"))
    0<u<(1<<N) && 0<v<(1<<N) && u!=v || throw(ArgumentError("need distinct nonzero field elements"))
    iu=gf_inv(u,N;modulus)
    ratio=gf_mul(v,iu,N;modulus)
    columns=[gf_mul(u,1<<j,N;modulus) for j in 0:N-1]
    append!(columns,[gf_mul(iu,1<<j,N;modulus)<<N for j in 0:N-1])
    F=ZhaInverseSwapControl.inverse_swap(u,v,N;modulus)
    G=ZhaInverseSwapControl.inverse_swap(1,ratio,N;modulus)
    (; ratio, columns, constant=0, verified=verify_ea_witness(F.lut,G.lut,columns,0))
end

"""Enumerate the full finite earlier family with an exact scaling reduction.
Every distinct unordered nonzero pair is checked at every input against its
normalized LUT. Zero-point swaps form another scaling orbit and are included.
Only completed normalized invariant computations AND the full identity check
license Exhausted; partial spectra or equal invariants supply no separation.
"""
function inverse_swap_family_evidence(N::Int=8;modulus=primitive_polynomial(N),
        max_evaluations::Int=typemax(Int),timeout_seconds::Real=60)
    iseven(N) && 4<=N<=8 || throw(ArgumentError("supported even dimensions are4,6,8"))
    max_evaluations>=0 && timeout_seconds>=0 || throw(ArgumentError("budgets must be nonnegative"))
    gf_primitive_element(N;modulus) # validates the field, preserving its polynomial basis
    q=1<<N;started=time_ns();elapsed()=(time_ns()-started)/1e9
    region=SearchRegion(:inverse_two_point_swaps,"inverse-swaps-n$N";size=binomial(q,2),
        params=Dict{String,Any}("n"=>N,"modulus"=>Int(modulus),
            "domain"=>"all unordered distinct u,v in GF(2^n), including zero",
            "source"=>"https://eprint.iacr.org/2011/047.pdf Section4",
            "reduction"=>"bijective input/output field multiplications; all graph points checked"))
    records=NamedTuple[];stop=nothing
    for ratio in 0:q-1
        ratio==1 && continue
        if length(records)>=max_evaluations || elapsed()>=timeout_seconds
            stop=StopPoint(elapsed()>=timeout_seconds ? :time : :nodes,"normalized family remains unexplored")
            break
        end
        F=ratio==0 ? ZhaInverseSwapControl.inverse_swap(0,1,N;modulus) :
            ZhaInverseSwapControl.inverse_swap(1,ratio,N;modulus)
        invs=inverse_swap_invariants(F)
        eligible=ratio==0 ? nothing : gf_trace(ratio,N;modulus)==1 && gf_trace(gf_inv(ratio,N;modulus),N;modulus)==1
        ratio==0 || (eligible==(invs.du<=4)) || error("source trace hypothesis disagrees with complete derivative checks")
        push!(records,(;ratio,invariants=invs,trace_eligible=eligible,lut=Int.(F.lut)))
    end
    nonzero_pairs=0;du4_pairs=0;identity_points=0
    if stop===nothing
        byratio=Dict(r.ratio=>r for r in records)
        mul=[gf_mul(x,y,N;modulus) for x in 0:q-1,y in 0:q-1]
        inverse=[safe_inv(x,N;modulus) for x in 0:q-1]
        # Check bijectivity for every claimed scalar map before using the reduction.
        all(u->rank_f2(UInt.(mul[u+1,[1+(1<<j) for j in 0:N-1]]);nbits=N)==N,1:q-1) || error("singular scaling map")
        for u in 0:q-1,v in u+1:q-1
            if elapsed()>=timeout_seconds
                stop=StopPoint(:time,"full scaling certificate remains unchecked");break
            end
            scalar=u==0 ? v : u
            ratio=u==0 ? 0 : mul[v+1,inverse[u+1]+1]
            normalized=byratio[ratio]
            for x in 0:q-1
                sx=mul[scalar+1,x+1]
                y=sx==u ? inverse[v+1] : sx==v ? inverse[u+1] : inverse[sx+1]
                mul[scalar+1,y+1]==normalized.lut[x+1] || error("scaling identity failed")
                identity_points+=1
            end
            u==0 || (nonzero_pairs+=1)
            normalized.invariants.du==4 && (du4_pairs+=1)
        end
    end
    outcome=stop===nothing ? Exhausted(region,records;nodes_visited=length(records),elapsed_seconds=elapsed()) :
        BudgetHit(stop,region,records;nodes_visited=length(records),elapsed_seconds=elapsed())
    (;outcome,records,complete=outcome isa Exhausted,nonzero_pairs,du4_pairs,identity_points,
        unordered_pairs=binomial(q,2),elapsed_seconds=elapsed())
end

function proposition5_family_report(;max_evaluations::Int=typemax(Int),timeout_seconds::Real=60,
        modulus::Int=primitive_polynomial(8),io::IO=stdout,save_results::Bool=false)
    reference=inverse_swap_family_evidence(8;modulus,max_evaluations,timeout_seconds)
    comparisons=NamedTuple[]
    for (s,n) in ((2,4),(4,2)),t in subfield_elements(8,s;modulus)
        t==0 && continue
        F=SBox{8}(construction1_lut(s,n,t;modulus));invs=inverse_swap_invariants(F)
        invs.du==4 && is_permutation(F) || error("Zha theorem instance failed")
        matching=[r.ratio for r in reference.records if r.invariants.du==4 &&
            r.invariants.differential==invs.differential && r.invariants.walsh==invs.walsh]
        status=reference.complete && isempty(matching) ? :proven_ccz_inequivalent_to_entire_finite_family : :inconclusive
        push!(comparisons,(;s,n,t,lut=Int.(F.lut),invariants=invs,matching_normalized_ratios=matching,status))
    end
    print_section("Proposition5 — full eight-bit inverse-swap family",io)
    print_kv("normalized functions / complete", "$(length(reference.records)) / $(reference.complete)",io)
    print_kv("unordered pairs / nonzero pairs / DU4 pairs", "$(reference.unordered_pairs) / $(reference.nonzero_pairs) / $(reference.du4_pairs)",io)
    print_kv("verified graph identity points",reference.identity_points,io)
    for row in comparisons;print_kv("s=$(row.s), n=$(row.n), t=$(row.t)",row.status,io);end
    print_kv("scope","all admissible inverse two-point swaps and their affine equivalents at n8; no claim about all earlier DU4 constructions",io)
    result=(;reference,comparisons,all_separated=all(r.status==:proven_ccz_inequivalent_to_entire_finite_family for r in comparisons))
    if save_results
        encode(invs)=Dict("du"=>invs.du,"nonlinearity"=>invs.nonlinearity,
            "differential"=>[[a,b] for (a,b) in invs.differential],
            "absolute_walsh"=>[[a,b] for (a,b) in invs.walsh])
        sources=Dict{String,Any}[]
        root=normpath(joinpath(@__DIR__,"..","..","..","..",".."))
        for directory in (@__DIR__,joinpath(@__DIR__,"..","..","2013","Yuyin_201300"),joinpath(pkgdir(VBF),"src"))
            for (dir,_,files) in walkdir(directory),file in sort(files)
                (endswith(file,".jl") || (basename(dir)=="input" && endswith(file,".tex"))) || continue
                path=joinpath(dir,file)
                push!(sources,Dict("path"=>relpath(path,root),"sha256"=>bytes2hex(SHA.sha256(read(path)))))
            end
        end
        evidence=Dict("n"=>8,"modulus"=>modulus,"timeout_seconds"=>timeout_seconds,
            "max_evaluations"=>max_evaluations,"complete"=>reference.complete,
            "source"=>"https://eprint.iacr.org/2011/047.pdf Section4",
            "code_sha256"=>bytes2hex(SHA.sha256(read(@__FILE__))),
            "source_identities"=>sources,
            "julia_version"=>string(VERSION),"unordered_pairs"=>reference.unordered_pairs,
            "nonzero_pairs"=>reference.nonzero_pairs,"du4_pairs"=>reference.du4_pairs,
            "identity_points"=>reference.identity_points,"elapsed_seconds"=>reference.elapsed_seconds,
            "literature_novelty_verified"=>false,
            "references"=>[merge(encode(r.invariants),Dict("ratio"=>r.ratio,"lut"=>r.lut)) for r in reference.records],
            "comparisons"=>[merge(encode(r.invariants),Dict("s"=>r.s,"n"=>r.n,"t"=>r.t,"lut"=>r.lut,
                "matching_ratios"=>r.matching_normalized_ratios,"status"=>string(r.status))) for r in comparisons])
        mkpath(joinpath(@__DIR__,"results"))
        open(joinpath(@__DIR__,"results","proposition5.toml"),"w") do out
            TOML.print(out,evidence;sorted=true)
        end
    end
    result
end

if abspath(PROGRAM_FILE)==@__FILE__
    proposition5_family_report()
end
