# Implements 8 — Two level; Fact 5.
# Paper: Gillot and Langevin (2026), "Observation of known APNs", arXiv:2601.11247v1
# Section: 8 — Two level; Fact 5
#
# Pseudocode:
#   1. Build finite cubic/quartic orbits and compatible cubic stabilizer representatives.
#   2. Enumerate compatible cubic three-spaces, test extension obstructions and complete candidates.
# VBF API used: partition_refinement_automorphisms, rank_f2, span_from_basis, apn_extension_tests, apn_extensions

if !isdefined(@__MODULE__,:gl_kappa)
    include("helpers.jl")
end

"""Enumerate a deterministic bounded prefix of a Boolean EA orbit, GL Section 8."""
function gl_boolean_orbit(f::VBFTable{N,1};max_evaluations=1000,timeout_seconds=10) where {N}
    max_evaluations>=0 && timeout_seconds>=0 || throw(ArgumentError("invalid orbit bounds"))
    started=time_ns()
    evaluations=0
    complete=true
    seen=Dict{Tuple,VBFTable{N,1,UInt8}}()
    columns=UInt32[]
    function visit()
        if evaluations>=max_evaluations || (time_ns()-started)*1e-9>=timeout_seconds
            complete=false
            return false
        end
        if length(columns)==N
            L=F2LinearMap{N,UInt32}(copy(columns))
            for c in 0:length(f)-1
                if evaluations>=max_evaluations || (time_ns()-started)*1e-9>=timeout_seconds
                    complete=false
                    return false
                end
                g=gl_normalize_boolean(VBFTable{N,1}(UInt8[f(Int(L(x))⊻c) for x in 0:length(f)-1]))
                seen[Tuple(g.lut)]=g
                evaluations+=1
            end
            return true
        end
        for column in UInt32(1):UInt32(length(f)-1)
            (time_ns()-started)*1e-9>=timeout_seconds && (complete=false;return false)
            rank_f2([columns;column];nbits=N)==length(columns)+1 || continue
            push!(columns,column)
            done=visit()
            pop!(columns)
            done || return false
        end
        return true
    end
    visit()
    return (;functions=sort!(collect(values(seen));by=f->Tuple(f.lut)),complete,evaluations,
        elapsed_seconds=(time_ns()-started)*1e-9)
end

"""Select compatible cubic representatives under verified quartic stabilizer generators (Section 8)."""
function gl_compatible_representatives(cubics,h,H)
    lookup=Dict(Tuple(f.lut)=>i for (i,f) in enumerate(cubics))
    unseen=Set(eachindex(cubics))
    representatives=Int[]
    N=inputbits(h)
    while !isempty(unseen)
        start=minimum(unseen)
        push!(representatives,start)
        delete!(unseen,start)
        queue=[start]
        while !isempty(queue)
            i=popfirst!(queue)
            f=cubics[i]
            for A in H.generators
                g=gl_normalize_boolean(VBFTable{N,1}(UInt8[f(Int(A(UInt32(x)<<1))>>1)
                    for x in 0:length(f)-1]))
                j=get(lookup,Tuple(g.lut),0)
                j in unseen || continue
                delete!(unseen,j)
                push!(queue,j)
            end
        end
    end
    return representatives
end

"""Run GL Section 8’s compatible cubic/quartic pipeline with measured finite limits."""
function gl_section8(;path=joinpath(@__DIR__,"input","author_data","class-2-6.txt"),
    known_roots=Pair{String,SBox}[],max_evaluations=1000,max_candidates=10,max_nodes=100000,
    max_solutions=5,timeout_seconds=60,seed=940,save_results=false)
    started=time_ns()
    input=gl_author_boolean_classes(path;timeout_seconds)
    quartics=[f for f in input.functions if algebraic_degree(f)==4 && gl_kappa(f)==7//4]
    cubics=[f for f in input.functions if algebraic_degree(f)==3 && gl_kappa(f)==4]
    candidates=0
    evaluations=0
    quartic_seeds_processed=0
    complete=length(input.functions)==150356 && length(quartics)==8 && length(cubics)==6
    records=NamedTuple[]
    for (hindex,h) in enumerate(quartics)
        remaining=timeout_seconds-(time_ns()-started)*1e-9
        if remaining<=0 || evaluations>=max_evaluations || candidates>=max_candidates
            complete=false
            break
        end
        quartic_seeds_processed+=1
        seed_evaluations_start=evaluations
        seed_candidates_start=candidates
        per_seed_evaluations=max(1,max_evaluations÷max(1,length(quartics)))
        per_seed_candidates=max(1,max_candidates÷max(1,length(quartics)))
        orbit_limit=max(1,min(1000,per_seed_evaluations÷(1+2length(cubics))))
        oh=gl_boolean_orbit(h;max_evaluations=min(orbit_limit,max_evaluations-evaluations),timeout_seconds=remaining)
        evaluations+=oh.evaluations
        complete &= oh.complete
        hkeys=Set(Tuple(f.lut) for f in oh.functions)
        remaining=timeout_seconds-(time_ns()-started)*1e-9
        H=partition_refinement_automorphisms(h;relation=:ea,max_nodes,timeout_seconds=max(0,remaining),rng=Xoshiro(seed))
        for (gindex,g) in enumerate(cubics)
            remaining=timeout_seconds-(time_ns()-started)*1e-9
            if remaining<=0 || evaluations>=max_evaluations || candidates>=max_candidates ||
                evaluations-seed_evaluations_start>=per_seed_evaluations ||
                candidates-seed_candidates_start>=per_seed_candidates
                complete=false
                break
            end
            og=gl_boolean_orbit(g;max_evaluations=min(orbit_limit,max_evaluations-evaluations),timeout_seconds=remaining)
            evaluations+=og.evaluations
            complete &= og.complete && H.complete
            gkeys=Set(Tuple(f.lut) for f in og.functions)
            compatible=[f for f in og.functions if Tuple(f.lut .⊻ h.lut) in hkeys]
            R=gl_compatible_representatives(compatible,h,H)
            seen=Set{Tuple}()
            for i in R,j in eachindex(compatible),k in j+1:length(compatible)
                remaining=timeout_seconds-(time_ns()-started)*1e-9
                if remaining<=0 || evaluations>=max_evaluations || candidates>=max_candidates ||
                    evaluations-seed_evaluations_start>=per_seed_evaluations ||
                    candidates-seed_candidates_start>=per_seed_candidates
                    complete=false
                    break
                end
                evaluations+=1
                f1,f2,f3=compatible[i],compatible[j],compatible[k]
                masks=[sum(UInt128(f.lut[x])<<(x-1) for x in eachindex(f.lut)) for f in (f1,f2,f3)]
                rank_f2(masks;nbits=64)==3 || continue
                span=span_from_basis(masks)
                key=Tuple(sort!(span))
                key in seen && continue
                push!(seen,key)
                space=[UInt8[UInt8((v>>(x-1))&1) for x in 1:64] for v in span]
                all(v->all(iszero,v) || Tuple(v) in gkeys,space) || continue
                all(v->Tuple(v .⊻ h.lut) in hkeys,space) || continue
                G=VBFTable{6,4}([Int(f1.lut[x])|(Int(f2.lut[x])<<1)|(Int(f3.lut[x])<<2)|
                    (Int(h.lut[x])<<3) for x in 1:64])
                tests=apn_extension_tests(G;max_nodes,timeout_seconds=remaining)
                tests isa Exhausted || (complete=false;continue)
                only(search_solutions(tests)).passes || continue
                remaining=timeout_seconds-(time_ns()-started)*1e-9
                outcome=apn_extensions(G;max_nodes,max_solutions,timeout_seconds=max(0,remaining))
                candidates+=1
                complete &= outcome isa Exhausted
                matches=NamedTuple[]
                for F in search_solutions(outcome)
                    levels=Set(gl_kappa(gl_component(F,b)) for b in 1:63)
                    type_checked=levels==Set([7//4,4//1])
                    remaining=timeout_seconds-(time_ns()-started)*1e-9
                    match=isempty(known_roots) ? nothing : gl_classify_ccz(F,known_roots;
                        max_nodes,timeout_seconds=max(0,remaining),seed)
                    push!(matches,(;source_lut=Int.(F.lut),type_checked,match))
                end
                push!(records,(;quartic_seed=hindex,cubic_seed=gindex,projection_lut=Int.(G.lut),
                    complete=outcome isa Exhausted,solutions=length(search_solutions(outcome)),matches))
            end
        end
    end
    r=(;parameters=(;max_evaluations,max_candidates,max_nodes,max_solutions,timeout_seconds,seed,input_file=relpath(path,@__DIR__)),complete,processed=candidates,evaluations,records,seed,quartic_seeds_processed,quartic_seed_count=length(quartics),
        cubic_seed_count=length(cubics),source_sha256=input.sha256,
        bihomogeneous_classification_verified=false,
        elapsed_seconds=(time_ns()-started)*1e-9,stop_reason=complete ? :none : :budget)
    gl_save("section8",r;save_results)
    return r
end

function gl_section8_report(io::IO=stdout;kwargs...)
    return gl_report("Section 8 — cubic/quartic extension",gl_section8(;kwargs...),io)
end
if abspath(PROGRAM_FILE)==@__FILE__
    gl_section8_report(max_evaluations=100,timeout_seconds=5)
end
