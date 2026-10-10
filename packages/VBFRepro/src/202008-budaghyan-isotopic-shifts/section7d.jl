# Implements Section VII-D — n=6 coverage by Gold isotopic shifts.
# Paper: Budaghyan et al. (2020), Constructing APN Functions Through Isotopic Shifts.
# Pseudocode:
#   1. Reuse the 13 quadratic Edel–Pott Table-5 representatives in their field.
#   2. Replay a permutation and a 2-to-1 L witness for each named representative.
#   3. Verify literal Gold shifts, APN, linear-map nullities and full EA graph maps.
#   4. Optionally discover witnesses in a deterministic bounded sample of L.
# VBF API used: F2LinearMap, F2AffineMap, rank_f2, gf_mul, gf_pow, is_qam,
#   gold_apn, encode_quadratic, apn_ea_mugshot, partition_refinement_equivalence.
# Guarantee: finite existential coverage of the named reference rows; neither
# exhaustion of all 2^36 linear maps nor classification of all 6-bit APNs.

include(joinpath(@__DIR__, "proposition_vi1.jl"))
using Random, SHA, TOML

# Reuse the source-faithful builders rather than duplicate 14 switching formulas.
module Section7dReferences
include(joinpath(@__DIR__, "..", "200900-edel-switching", "helpers.jl"))
end

const SECTION7D_MODULUS=91 # Edel–Pott Table 2: x^6+x^4+x^3+x+1, ζ=2.
const SECTION7D_FIXTURE=joinpath(@__DIR__, "test", "fixtures", "section7d_witnesses.toml")

section7d_references()=filter(r->algebraic_degree(r.sbox)==2,Section7dReferences.edelpott_table5())

# Explicit platform-independent identity binding for finite witness records.
section7d_lut_sha256(lut)=bytes2hex(sha256(UInt8[b for v in lut for b in (v & 0xff,(v >> 8) & 0xff)]))

function section7d_shift(images::AbstractVector{<:Integer})
    length(images)==6 && all(0<=v<64 for v in images) || throw(ArgumentError("need six field images"))
    L=F2LinearMap{6,UInt8}(UInt8.(images))
    L_lut=[Int(L(x)) for x in 0:63]
    G=gold_apn(6,1;modulus=SECTION7D_MODULUS)
    F=SBox{6}(isotopic_shift_lut(G.lut,L_lut))
    (;F,L_lut,nullity=6-rank_f2(UInt.(images);nbits=6))
end

function section7d_verify_graph(source,target,mapping::F2AffineMap{12})
    rank_f2(mapping.linear.cols;nbits=12)==12 || return false
    # EA requires preserving the vertical output subspace, in addition to CCZ.
    all(iszero(Int(mapping.linear(1 << j)) >> 6) for j in 0:5) || return false
    all(begin
        point=Int(mapping((x << 6)|Int(source(x))))
        (point & 63)==Int(target(point >> 6))
    end for x in 0:63)
end

function section7d_verify_record(record,references=section7d_references())
    reference=only(filter(r->r.name==record["name"],references)).sbox
    shift=section7d_shift(record["images"])
    mapping=F2AffineMap{12,UInt32}(record["columns"],record["constant"])
    coefficients=record["coefficients"]
    rebuilt=terms_to_lut([(coefficients[j+1],1 << j) for j in 0:5],6,SECTION7D_MODULUS)
    norm=record["normalization"]
    normalized=proposition_vi1_witness(coefficients,6,1;
        k=norm["k"],t=norm["t"],modulus=SECTION7D_MODULUS)
    canonical=proposition_vi1_normalize(coefficients,6;modulus=SECTION7D_MODULUS)
    valid=canonical.complete && canonical.coefficients==norm["coefficients"] &&
        canonical.evaluations==norm["evaluations"] && shift.nullity==record["nullity"] && shift.nullity in (0,1) &&
        rebuilt==shift.L_lut &&
        differential_uniformity(shift.F)==2 && differential_uniformity(reference)==2 &&
        algebraic_degree(shift.F)==2 && algebraic_degree(reference)==2 &&
        section7d_lut_sha256(shift.F.lut)==record["source_sha256"] &&
        section7d_lut_sha256(reference.lut)==record["target_sha256"] &&
        section7d_verify_graph(shift.F,reference,mapping) && normalized.verified &&
        normalized.coefficients==norm["coefficients"]
    (;valid,name=record["name"],nullity=shift.nullity,shift,mapping,normalized)
end

function section7d_replay(;fixture::AbstractString=SECTION7D_FIXTURE)
    data=TOML.parsefile(fixture)
    data["modulus"]==SECTION7D_MODULUS && data["dimension"]==6 || error("fixture field mismatch")
    data["generator"]==gf_primitive_element(6;modulus=SECTION7D_MODULUS) || error("fixture generator mismatch")
    data["basis"]=="polynomial bits: e_i=2^i, i=0..5" || error("fixture basis mismatch")
    data["hash_encoding"]=="UInt16 little endian LUT values" || error("fixture hash encoding mismatch")
    data["graph_packing"]=="(input << 6) | output" || error("fixture graph packing mismatch")
    data["witness_orientation"]=="literal Gold isotopic shift -> named reference" || error("fixture witness orientation mismatch")
    refs=section7d_references()
    records=[section7d_verify_record(record,refs) for record in data["witnesses"]]
    expected=Set((r.name,nullity) for r in refs for nullity in (0,1))
    verified=Set((r.name,r.nullity) for r in records if r.valid)
    all_valid=all(r.valid for r in records)
    complete=length(records)==26 && all_valid && verified==expected
    (;complete,all_valid,records,references=refs,verified,expected,
        discovery=data["discovery"],space_exhausted=false)
end

"""
    section7d_discover(;seed=20261010,max_evaluations=10^6,timeout_seconds=60)

Sample linear maps uniformly by their six basis images, with replacement.
The Eq.(7) polar matrix enables the exact QAM test before expensive invariants.
Both L and L+x give the same literal shift and may have different nullities.
Equal full mugshots are candidate filters; every positive reference membership
requires a verified EA graph map. `Found` means all 26 requested witnesses were
obtained, not that the 2^36-map region was exhausted. Unfinished searches are
BudgetHit, including unresolved equivalence comparisons.
"""
function section7d_discover(;seed::Int=20261010,max_evaluations::Int=10^6,
    timeout_seconds::Real=60,equivalence_timeout_seconds::Real=10,max_equivalence_nodes::Int=10^6)
    max_evaluations>=0 && max_equivalence_nodes>=0 && timeout_seconds>=0 && equivalence_timeout_seconds>=0 ||
        throw(ArgumentError("budgets must be nonnegative"))
    start=time()
    refs=section7d_references();mugs=apn_ea_mugshot.([r.sbox for r in refs])
    wanted=Set((r.name,nullity) for r in refs for nullity in (0,1))
    records=NamedTuple[];seen=Set{Tuple{String,Int}}()
    rng=Xoshiro(seed);H=zeros(Int,6,6);images=zeros(Int,6)
    # Eq.(7), B(e_i,e_j)=P_i(L(e_j))+P_j(L(e_i)). Finite field arithmetic
    # remains in VBF; the precomputed table merely avoids repeating it.
    P=[gf_mul(gf_pow(1 << (i-1),2,6;modulus=SECTION7D_MODULUS),a,6;modulus=SECTION7D_MODULUS) ⊻
       gf_mul(1 << (i-1),gf_pow(a,2,6;modulus=SECTION7D_MODULUS),6;modulus=SECTION7D_MODULUS)
       for i in 1:6,a in 0:63]
    evaluations=0;apn_trials=0;undecided=0;reason=:nodes
    while evaluations<max_evaluations
        if time()-start>=timeout_seconds
            reason=:time;break
        end
        evaluations+=1
        for j in 1:6
            images[j]=rand(rng,0:63)
            for i in 1:j-1
                H[i,j]=H[j,i]=P[i,images[j]+1] ⊻ P[j,images[i]+1]
            end
        end
        is_qam(H) || continue
        apn_trials+=1
        shift=section7d_shift(images)
        differential_uniformity(shift.F)==2 || error("polar APN test disagrees with literal shift")
        matches=findall(==(apn_ea_mugshot(shift.F)),mugs)
        for variant in (false,true)
            cols=variant ? [images[i] ⊻ (1 << (i-1)) for i in 1:6] : copy(images)
            nullity=6-rank_f2(UInt.(cols);nbits=6)
            nullity in (0,1) || error("APN shift violates necessary valence constraint")
            for row in matches
                key=(refs[row].name,nullity)
                key in seen && continue
                eq=partition_refinement_equivalence(shift.F,refs[row].sbox;relation=:ea,
                    timeout_seconds=min(equivalence_timeout_seconds,max(0,timeout_seconds-(time()-start))),
                    max_nodes=max_equivalence_nodes)
                if eq isa Found
                    map=only(search_solutions(eq))
                    section7d_verify_graph(shift.F,refs[row].sbox,map) || error("invalid EA witness")
                    push!(seen,key)
                    push!(records,(;name=refs[row].name,nullity,images=cols,mapping=map,trial=evaluations))
                elseif eq isa BudgetHit
                    undecided+=1
                end
            end
        end
        seen==wanted && break
    end
    region=SearchRegion(:gold_isotopic_linear_maps,"Gold x^3 shifts by all linear maps in dimension6";
        size=BigInt(1)<<36,params=Dict{String,Any}("seed"=>seed,"modulus"=>SECTION7D_MODULUS,
            "sampling"=>"uniform basis images with replacement","reference_source"=>"Edel–Pott2009Table5 quadratic rows",
            "solution_unit"=>"verified EA witness by reference row and L nullity"))
    outcome=seen==wanted ? Found(records,region;nodes_visited=evaluations,elapsed_seconds=time()-start) :
        BudgetHit(StopPoint(reason,"finite witness coverage incomplete; sampled region is not exhausted"),
            region,records;nodes_visited=evaluations,elapsed_seconds=time()-start)
    (;outcome,evaluations,apn_trials,undecided,covered=seen,required=wanted,seed,space_exhausted=false)
end

# Optional discovery evidence; never written by a default report or test.
function section7d_save_evidence(result;path::AbstractString=joinpath(@__DIR__, "results", "section7d_witnesses.toml"))
    refs=section7d_references()
    records=Dict{String,Any}[]
    for record in search_solutions(result.outcome)
        reference=only(filter(r->r.name==record.name,refs)).sbox
        shift=section7d_shift(record.images)
        packed=Int.(encode_quadratic(SBox{6}(shift.L_lut);modulus=SECTION7D_MODULUS))
        exps=quadratic_exponents(6)
        all(iszero(packed[index]) for (index,e) in enumerate(exps) if count_ones(e)!=1) ||
            error("linear map contains nonlinear coefficients")
        coefficients=[packed[findfirst(==(1 << j),exps)] for j in 0:5]
        norm=proposition_vi1_normalize(coefficients,6;modulus=SECTION7D_MODULUS)
        norm.complete || error("normalization budget insufficient")
        push!(records,Dict("name"=>record.name,"nullity"=>record.nullity,"images"=>record.images,
            "columns"=>Int.(record.mapping.linear.cols),"constant"=>Int(record.mapping.constant),
            "coefficients"=>coefficients,"trial"=>record.trial,
            "source_sha256"=>section7d_lut_sha256(shift.F.lut),
            "target_sha256"=>section7d_lut_sha256(reference.lut),
            "normalization"=>Dict("k"=>norm.k,"t"=>norm.t,"coefficients"=>norm.coefficients,
                "evaluations"=>norm.evaluations)))
    end
    sort!(records;by=r->(r["name"],r["nullity"]))
    data=Dict("dimension"=>6,"modulus"=>SECTION7D_MODULUS,"generator"=>2,
        "basis"=>"polynomial bits: e_i=2^i, i=0..5","hash_encoding"=>"UInt16 little endian LUT values",
        "graph_packing"=>"(input << 6) | output","witness_orientation"=>"literal Gold isotopic shift -> named reference",
        "reference"=>"Edel–Pott(2009)Table5 quadratic rows (reused source builders)",
        "discovery"=>Dict("seed"=>result.seed,"evaluations"=>result.evaluations,
            "apn_trials"=>result.apn_trials,"undecided"=>result.undecided,
            "outcome"=>string(outcome_tag(result.outcome)),"space_size"=>string(BigInt(1)<<36),
            "space_exhausted"=>false,"sampling"=>"uniform basis images with replacement"),
        "witnesses"=>records)
    mkpath(dirname(path))
    open(path*".tmp","w") do io
        TOML.print(io,data;sorted=true)
    end
    mv(path*".tmp",path;force=true)
    path
end

function section7d_report(io::IO=stdout)
    result=section7d_replay()
    print_section(io,"Section VII-D — exact witnesses for named n=6 reference classes")
    print_kv(io,"reference", "13 quadratic Edel–Pott(2009)Table5 rows; modulus91,ζ2")
    print_kv(io,"verified reference/valence witnesses","$(length(result.verified)) / $(length(result.expected))")
    print_check(io,"each named reference has both permutation and 2-to-1 Gold shifts",result.complete)
    print_kv(io,"discovery",result.discovery)
    print_kv(io,"guarantee","all64graphpoints per EA witness; source/target LUT hashes; literal APN checks")
    print_kv(io,"not certified","exhaustion of2^36linear maps, all6bitAPNs, or literature completeness beyond these13rows")
    result
end

if abspath(PROGRAM_FILE)==@__FILE__
    section7d_report()
end
