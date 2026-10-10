# Read-only revalidation of the 32 historical F063 proposals. Root Julia project.
# Full invariants are filters. Positive graph maps are independently replayed.
using VBF, VBFCatalog, VBFSearch, SHA, TOML
include(joinpath(@__DIR__,"apn_power_evidence.jl"))
using .APNPowerEvidence
const PROPOSAL_PAPERS=normpath(joinpath(@__DIR__,"..","..","papers"))
const PROPOSAL_ROOT=normpath(joinpath(PROPOSAL_PAPERS,"..","..",".."))
module ProposalB20
include(joinpath(@__DIR__,"..","..","papers","2020","Budaghyan_202011","helpers.jl"))
end
module ProposalB21
include(joinpath(@__DIR__,"..","..","papers","2021","Budaghyan_202101","theorem3_1.jl"))
end
module ProposalG22
include(joinpath(@__DIR__,"..","..","papers","2022","Gologlu_202207","theorem3_2.jl"))
end
module ProposalZ22
include(joinpath(@__DIR__,"..","..","papers","2022","Zheng_202211","helpers.jl"))
end
module ProposalC23
include(joinpath(@__DIR__,"..","..","papers","2023","Calderini_202306","helpers.jl"))
end
module ProposalL24
include(joinpath(@__DIR__,"..","..","papers","2024","Li_202402","theorem1.jl"))
end
module ProposalL24Second
include(joinpath(@__DIR__,"..","..","papers","2024","Li_202402","theorem6.jl"))
end
module ProposalY25
include(joinpath(@__DIR__,"..","..","papers","2025","Yu_202512","table1.jl"))
end
module ProposalG25
include(joinpath(@__DIR__,"..","..","papers","2025","Gologlu_202503","helpers.jl"))
end

proposal_lut_sha(F)=bytes2hex(SHA.sha256(UInt8[b for x in F.lut for b in (Int(x)&255,Int(x)>>8)]))
proposal_spectrum(s)=[[Int(k),Int(v)] for (k,v) in sorted_pairs(s)]

"""Rebuild original proposed representatives, pinning the actual field and parameters.
This is a finite proposal inventory, not enumeration of the source families.
"""
function catalog_proposal_candidates()
    rows=NamedTuple[]
    add(name,paper,locator,recipe,F)=push!(rows,(;name,paper,locator,recipe,F))
    add("BHK2020_C3","2020/Budaghyan_202011","Observation1/Corollary1 item2","build_ci_sbox(10,3,2;modulus=1033)",ProposalB20.build_ci_sbox(10,3,2;modulus=1033))
    add("BHK2020_C7","2020/Budaghyan_202011","Observation1/Corollary1 item3","build_ci_sbox(10,7,0;modulus=1033)",ProposalB20.build_ci_sbox(10,7,0;modulus=1033))
    for i in (1,2)
        add("Gologlu2022_F2_i$i","2022/Gologlu_202207","TheoremIII.2 F2","f2_sbox(5,$i;modulus=37)",ProposalG22.f2_sbox(5,i;modulus=37))
    end
    add("Gologlu2022_F3","2022/Gologlu_202207","TheoremIII.2 F3","f3_sbox(modulus=37), primitive u=2",ProposalG22.f3_sbox(modulus=37))
    add("Zheng2022_F15","2022/Zheng_202211","Theorem3.3","f15_sbox(5;a=2,b=2,modulus=1033)",ProposalZ22.f15_sbox(5;a=2,b=2,modulus=1033))
    add("Zheng2022_Remark3_6","2022/Zheng_202211","Remark3.6/Table2 sporadic","a=2,b=1,c=2^11; n10 modulus1033",SBox{10}(ProposalZ22.zheng_lut(5,3,2,1,gf_pow(2,11,10;modulus=1033);modulus=1033)))
    z=23 # A tested primitive representative; not every primitive choice satisfies the example.
    gf_multiplicative_order(z,10;modulus=1033)==1023 || error("Example1 representative not primitive")
    example=ProposalZ22.zheng_lut(5,2,z,1,z;modulus=1033) .⊻ ProposalZ22.zheng_lut(5,7,z,0,gf_pow(z,369,10;modulus=1033);modulus=1033)
    add("Zheng2022_Example1","2022/Zheng_202211","Example1/Table2 sporadic","z=23 primitive, b=1,g=z,e=z^369; modulus1033",SBox{10}(example))
    add("Calderini2023_F2_n6","2023/Calderini_202306","Theorem4 m3","family_f2_lut(3,2;modulus=11)",ProposalC23.family_f2_lut(3,2;modulus=11))
    add("Yu2025_short_n10","2025/Yu_202512","Table1 row3 (prior trace-family representative)","seven exponents513,192,96,48,33,18,12; modulus1135",ProposalY25.build_table1_sboxes(1135)[3])
    # Reuse finite-field and polynomial APIs for the older trace construction.
    trace_lut=[gf_pow(x,3,11;modulus=2053) ⊻ gf_trace(gf_pow(x,9,11;modulus=2053),11;modulus=2053) for x in 0:2047]
    add("Yu2025_trace_n11","2025/Yu_202512","Table3 x3+Tr(x9), prior Budaghyan2009 family","x3+absolute_trace(x9); modulus2053",SBox{11}(trace_lut))
    u=28
    gf_pow(u,3,9;modulus=529) ⊻ u ⊻ 1==0 || error("Beierle coefficient fails minimal polynomial")
    gf_multiplicative_order(2,9;modulus=529)==511 || error("Table3 zeta is not primitive")
    gf_multiplicative_order(2,8;modulus=285)==255 || error("Beierle g is not primitive")
    for (index,terms) in enumerate(([(1,3),(u,10),(gf_pow(u,2,9;modulus=529),17),(gf_pow(u,4,9;modulus=529),80),(gf_pow(u,5,9;modulus=529),192)],
            [(1,3),(gf_pow(u,2,9;modulus=529),10),(u,24),(gf_pow(u,4,9;modulus=529),80),(gf_pow(u,6,9;modulus=529),136)]))
        add("Beierle2022_perm$index","2022/Beierle_202201","Section1.1 explicit n9 permutation$index","u=28 root X3+X+1; modulus529; terms=$(repr(terms))",SBox{9}(terms_to_lut(terms,9,529)))
    end
    coeffpowers=[(0,3),(60,5),(191,6),(198,9),(232,10),(120,12),(54,17),(64,18),(159,20),(144,24),(248,33),(203,34),(32,36),(18,40),(216,48),(78,65),(46,66),(91,68),(27,72),(70,80),(52,96),(224,129),(18,130),(197,136),(253,144),(0,160)]
    add("Beierle2022_lin128","2022/Beierle_202201","Section1.1 explicit n8 polynomial","g=2 primitive; modulus285; coefficient powers=$(repr(coeffpowers))",SBox{8}(terms_to_lut([(gf_pow(2,c,8;modulus=285),e) for (c,e) in coeffpowers],8,285)))
    for (index,(label,i,terms)) in enumerate(ProposalB21.TABLE3_ENTRIES)
        label=="new" || continue
        add("Budaghyan2021_table3_row$index","2021/Budaghyan_202101","Table3 printed new row$index i=$i","zeta_poly_lut(9,terms;modulus=529,zeta=2); terms=$(repr(terms))",SBox{9}(ProposalB21.zeta_poly_lut(9,terms;modulus=529,zeta=2)))
    end
    add("Li2024_F1_n9","2024/Li_202402","Theorem1/Proposition4","family1_lut(3,1), GF8 modulus11 trivariate basis",SBox{9}(ProposalL24.family1_lut(3,1)))
    add("Li2024_F2_n9","2024/Li_202402","Theorem6/Proposition8","family2_lut(3,1), GF8 modulus11 trivariate basis",SBox{9}(ProposalL24Second.family2_lut(3,1)))
    fld=ProposalG25.BiField(6;modulus=67)
    ProposalG25.f4_valid(fld,1,2,1) || error("F4 parameters not admissible")
    add("Gologlu2025_F4_n12","2025/Gologlu_202503","Theorem3.3/Table2.1","family_f4(BiField(6;modulus67),1,2,1)",ProposalG25.bipair_sbox(ProposalG25.family_f4(fld,1,2,1)))
    length(rows)==32 || error("proposal inventory changed")
    rows
end

"""Replay a generic EA graph certificate at EVERY point, separate from its solver.
Packed low bits are outputs, high bits inputs. Exact rank and block checks precede replay.
For n8, also run VBFSearch's stdlib-only independent verifier.
"""
function replay_proposal_graph(F,G,A::F2AffineMap;relation::Symbol=:ea)
    relation in (:ea,:ccz) || throw(ArgumentError("relation must be EA or CCZ"))
    n=inputbits(F); inputbits(G)==n && inputbits(A)==2n || return false
    cols=Int.(A.linear.cols);constant=Int(A.constant);mask=(1<<n)-1
    rank_f2(UInt.(cols);nbits=2n)==2n || return false
    if relation==:ea
        all(c->c>>n==0,cols[1:n]) || return false
        rank_f2(UInt.(cols[1:n]);nbits=n)==n || return false
        rank_f2(UInt.(cols[n+1:end].>>n);nbits=n)==n || return false
    end
    seen=falses(1<<n)
    for x in 0:(1<<n)-1
        p=(x<<n)|Int(F.lut[x+1]);z=constant
        for j in 0:2n-1; isodd(p>>j) && (z⊻=cols[j+1]);end
        y=z>>n
        seen[y+1] && return false
        seen[y+1]=true
        Int(G.lut[y+1])==z&mask || return false
    end
    all(seen) || return false
    verifier=relation==:ea ? verify_ea_witness : verify_ccz_witness
    n!=8 || verifier(F.lut,G.lut,cols,constant) || return false
    true
end
replay_proposal_ea(F,G,A::F2AffineMap)=replay_proposal_graph(F,G,A;relation=:ea)

function proposal_pair_evidence(F,G;timeout_seconds::Real=2,max_nodes::Int=100_000,relation::Symbol=:ea)
    relation in (:ea,:ccz) || throw(ArgumentError("relation must be EA or CCZ"))
    timeout_seconds>=0 && max_nodes>=0 || throw(ArgumentError("nonnegative equivalence budgets required"))
    inputbits(F)==inputbits(G) || throw(ArgumentError("different dimensions"))
    if F.lut==G.lut
        A=F2AffineMap(identity_linear_map(2inputbits(F)),0)
        replay_proposal_graph(F,G,A;relation) || error("identity certificate failed")
        return Dict("status"=>"identical_lut","columns"=>Int.(A.linear.cols),"constant"=>0)
    end
    result=partition_refinement_equivalence(F,G;relation,timeout_seconds,max_nodes)
    if result isa Found
        A=first(result.functions)
        replay_proposal_graph(F,G,A;relation) || error("solver certificate failed independent replay")
        return Dict("status"=>"$(relation)_equivalent_witness_replayed","columns"=>Int.(A.linear.cols),"constant"=>Int(A.constant),"nodes"=>result.nodes_visited)
    end
    Dict("status"=>result isa Exhausted ? "exhaustive_$(relation)_inequivalent" : "inconclusive_budget",
         "nodes"=>result.nodes_visited,"elapsed_seconds"=>result.elapsed_seconds)
end

"""Every explicit catalog target gets a conclusive method or an unresolved outcome.
EA exhaustion licenses CCZ separation only when BOTH functions are quadratic APNs.
For arbitrary degree targets use general CCZ invariants or the general graph solver.
"""
function finite_target_evidence(F,r,power,controls,sig,matching_checks;
        timeout_seconds::Real=2,max_nodes::Int=100_000)
    G=r.F
    result=Dict{String,Any}("reference"=>r.name,"scope"=>r.scope,
        "candidate_sha256_uint16_le"=>proposal_lut_sha(F),
        "reference_sha256_uint16_le"=>proposal_lut_sha(G),"reference_degree"=>r.degree)
    if r.degree==2
        if sig!=r.sigma
            result["status"]="ccz_inequivalent_by_exact_quadratic_invariant"
        else
            proof=only(filter(x->x["reference"]==r.name,matching_checks))
            merge!(result,proof)
            if proof["status"]=="exhaustive_ea_inequivalent"
                result["status"]="ccz_inequivalent_by_exhaustive_quadratic_ea"
            end
        end
        return result
    end
    identity=power_target_identity(G,controls)
    result["power_target_identity"]=identity
    if identity["status"]=="literal_known_power_map"
        result["status"]=power_exclusion_applies(F,power) ?
            "ccz_inequivalent_by_yoshiara_power_theorem" : "inconclusive_power_coverage"
        result["theorem"]=deepcopy(YOSHIARA_POWER_THEOREM)
        return result
    end
    left=sorted_pairs(absolute_walsh_spectrum(F));right=sorted_pairs(absolute_walsh_spectrum(G))
    if left!=right
        result["status"]="ccz_inequivalent_by_exact_walsh_spectrum"
        result["candidate_absolute_walsh"]=[[Int(a),Int(b)] for (a,b) in left]
        result["reference_absolute_walsh"]=[[Int(a),Int(b)] for (a,b) in right]
    else
        merge!(result,proposal_pair_evidence(F,G;relation=:ccz,timeout_seconds,max_nodes))
    end
    result
end

const FINITE_NEGATIVE_STATUSES=Set(["ccz_inequivalent_by_exact_quadratic_invariant",
    "ccz_inequivalent_by_exhaustive_quadratic_ea","ccz_inequivalent_by_yoshiara_power_theorem",
    "ccz_inequivalent_by_exact_walsh_spectrum","exhaustive_ccz_inequivalent"])
const FINITE_POSITIVE_STATUSES=Set(["identical_lut","ea_equivalent_witness_replayed","ccz_equivalent_witness_replayed"])

function finite_catalog_disposition(checks)
    isempty(checks) && return "no_catalog_references_available"
    any(x->x["status"] in FINITE_POSITIVE_STATUSES,checks) && return "represented_in_current_catalog"
    all(x->x["status"] in FINITE_NEGATIVE_STATUSES,checks) && return "ccz_inequivalent_to_current_catalog"
    "comparison_incomplete"
end

"""Use the existing digest-bound n8 snapshot and independent n8 evidence machinery.
The union is already computed. Only its indexed membership is queried; no corpus
LUT/signature regeneration. Missing or changed snapshots remain unavailable.
"""
function archived_n8_proposal_evidence(F,reference_dir::AbstractString)
    r=nothing
    try
        r=VBFSearch.open_reference(reference_dir;supplement_path="")
        evidence=VBFSearch.classify(F.lut,r)
        Dict{String,Any}("status"=>"available","reference"=>VBFCatalog.reference_metadata(r),
            "candidate_sha256_uint16_le"=>proposal_lut_sha(F),
            "independent_n8_properties"=>evidence,"literature_novelty_verified"=>false)
    catch error
        error isa InterruptException && rethrow()
        Dict{String,Any}("status"=>"unavailable","reason"=>sprint(showerror,error),
            "reference_dir"=>reference_dir,"literature_novelty_verified"=>false)
    finally
        r===nothing || VBFSearch.close_reference(r)
    end
end

function proposal_disposition(checks,peers,quadratic_reference_count)
    positive(x)=x["status"] in ("identical_lut","ea_equivalent_witness_replayed")
    any(x->x["scope"]=="catalog_functions_table" && positive(x),checks) && return "represented_in_functions_table"
    any(positive,checks) && return "represented_in_selected_prior_reference"
    any(positive,peers) && return "represented_by_another_proposal"
    quadratic_reference_count==0 && return "no_quadratic_references_available"
    isempty(checks) ? "separated_from_enumerated_quadratic_references" : "invariant_match_equivalence_unresolved"
end

function proposal_code_sources(candidates)
    records=Dict{String,Any}[]
    for paper in sort!(unique(c.paper for c in candidates))
        dir=joinpath(PROPOSAL_PAPERS,paper)
        for (d,_,files) in walkdir(dir),file in sort(files)
            path=joinpath(d,file)
            (endswith(file,".jl") || (basename(d)=="input" && endswith(file,".tex"))) || continue
            push!(records,Dict("path"=>relpath(path,PROPOSAL_ROOT),"sha256"=>bytes2hex(SHA.sha256(read(path)))))
        end
    end
    records
end

"""Validate all32 proposals against explicit functions-table rows and selected controls.
All selected references have their APN flag checked, and exact sigma tuples recomputed.
Power targets use the complete Gold-domain theorem; other targets use general CCZ methods.
All claims name their finite references. Literature completeness is never asserted.
"""
function review_catalog_proposals(;timeout_seconds::Real=2,max_nodes::Int=100_000,io::IO=stdout,
        gold_max_evaluations::Int=typemax(Int),gold_timeout_seconds::Real=Inf,
        n8_reference_dir::AbstractString=get(ENV,"VBF_F063_N8_REFERENCE",joinpath(PROPOSAL_ROOT,"data/apn/archive/census/results/signature_rebuild")))
    timeout_seconds>=0 && max_nodes>=0 || throw(ArgumentError("nonnegative equivalence budgets required"))
    catalog_path=joinpath(pkgdir(VBFCatalog),"BFA_catalog.sqlite")
    catalog_digest=bytes2hex(SHA.sha256(read(catalog_path)))
    candidates=catalog_proposal_candidates();db=load_catalog();references=NamedTuple[]
    dimensions=sort!(unique(inputbits(c.F) for c in candidates))
    gold=Dict(n=>build_gold_coverage(n;max_evaluations=gold_max_evaluations,timeout_seconds=gold_timeout_seconds) for n in dimensions)
    controls=Dict(n=>known_power_controls(n) for n in dimensions)
    corpus_descriptors=Dict{String,Any}[]
    try
        for n in dimensions,row in list_functions(db;n,is_apn=true)
            G=load_sbox(db,row.id);differential_uniformity(G)==2 || error("invalid APN catalog row$(row.id)")
            d=algebraic_degree(G)
            name=row.canonical_name===nothing ? "id:$(row.id)" : String(row.canonical_name)
            source=Dict("id"=>Int(row.id),"source_repo"=>String(row.source_repo),
                "bib_key"=>row.bib_key===nothing ? "unspecified" : String(row.bib_key))
            push!(references,(;name,F=G,degree=d,scope="catalog_functions_table",sigma=d==2 ? sigma_key(G) : nothing,source))
        end
        for corpus in list_corpora(db)
            info=corpus_info(db,corpus)
            push!(corpus_descriptors,Dict("name"=>corpus,"n"=>Int(info.n),"member_count"=>Int(info.member_count),"scope"=>"descriptor only; full members not compared"))
        end
        name="beierleleander2022_n8"
        if corpus_info(db,name)!==nothing && isfile(corpus_store_path(name))
            G=corpus_function(db,name,12658)
            is_quadratic_apn(G) || error("selected corpus control invalid")
            push!(references,(;name="$name:12658",F=G,degree=2,scope="selected_bulk_corpus_member",sigma=sigma_key(G),source=Dict("corpus"=>name,"member"=>12658)))
        end
    finally
        VBFCatalog.SQLite.close(db)
    end
    # An explicit older trace-family reference distinguishes prior construction identity
    # from whether the functions table has a curated row for this representative.
    for n in (10,11)
        modulus=n==10 ? 1135 : 2053
        G=SBox{n}([gf_pow(x,3,n;modulus) ⊻ gf_trace(gf_pow(x,9,n;modulus),n;modulus) for x in 0:(1<<n)-1])
        is_quadratic_apn(G) || error("prior trace-family control invalid")
        push!(references,(;name="Budaghyan2009_x3_Trx9_n$n",F=G,degree=2,scope="explicit_prior_construction",sigma=sigma_key(G),source=Dict("bib_key"=>"Budaghyan_200904","modulus"=>modulus,"recipe"=>"x3+absolute_trace(x9)")))
    end
    signatures=Dict(c.name=>sigma_key(c.F) for c in candidates)
    records=Dict{String,Any}[]
    for c in candidates
        F=c.F;n=inputbits(F);du=differential_uniformity(F);degree=algebraic_degree(F)
        du==2 && degree==2 || error("proposal property contradiction: $(c.name), du=$du degree=$degree")
        sig=signatures[c.name]
        matching=[r for r in references if inputbits(r.F)==n && r.degree==2 && r.sigma==sig]
        checks=Dict{String,Any}[]
        for r in matching
            proof=proposal_pair_evidence(F,r.F;timeout_seconds,max_nodes)
            merge!(proof,Dict("reference"=>r.name,"scope"=>r.scope,"reference_lut"=>Int.(r.F.lut),"reference_sha256_uint16_le"=>proposal_lut_sha(r.F)))
            push!(checks,proof)
        end
        peers=Dict{String,Any}[]
        # Check each proposal pair once; equal buckets are explicitly NOT deduplicated.
        for other in candidates
            other.name<c.name && inputbits(other.F)==n && signatures[other.name]==sig || continue
            push!(peers,merge(proposal_pair_evidence(F,other.F;timeout_seconds,max_nodes),Dict("proposal"=>other.name,"reference_lut"=>Int.(other.F.lut))))
        end
        same_n=[r for r in references if inputbits(r.F)==n]
        status=proposal_disposition(checks,peers,count(r->r.degree==2,same_n))
        power=gold_power_evidence(F,gold[n])
        targets=[finite_target_evidence(F,r,power,controls[n],sig,checks;timeout_seconds,max_nodes)
            for r in same_n if r.scope=="catalog_functions_table"]
        finite_status=finite_catalog_disposition(targets)
        record=Dict{String,Any}("name"=>c.name,"paper"=>c.paper,"source_locator"=>c.locator,"recipe"=>c.recipe,
            "n"=>n,"du"=>du,"degree"=>degree,"permutation"=>is_permutation(F),
            "lut"=>Int.(F.lut),"sha256_uint16_le"=>proposal_lut_sha(F),
            "sigma_differential"=>[[Int(k),Int(v)] for (k,v) in sig[1]],
            "sigma_absolute_walsh"=>[[Int(k),Int(v)] for (k,v) in sig[2]],
            "quadratic_reference_count"=>count(r->r.degree==2,same_n),
            "separated_quadratic_references"=>[r.name for r in same_n if r.degree==2 && r.sigma!=sig],
            "unresolved_nonquadratic_references"=>[r["reference"] for r in targets if r["reference_degree"]!=2 &&
                !(r["status"] in union(FINITE_NEGATIVE_STATUSES,FINITE_POSITIVE_STATUSES))],
            "power_exclusion"=>power,"catalog_target_checks"=>targets,
            "finite_catalog_status"=>finite_status,
            "finite_catalog_comparison_complete"=>!isempty(targets) && all(r->r["status"] in union(FINITE_NEGATIVE_STATUSES,FINITE_POSITIVE_STATUSES),targets),
            "remaining_nonpower_scope"=>"Unlisted literature non-power constructions and arbitrary nonquadratic classes are outside this finite catalog snapshot.",
            "equivalence_checks"=>checks,"proposal_pair_checks"=>peers,"status"=>status,"literature_novelty"=>"unresolved")
        push!(records,record)
        n==8 && (record["archived_n8_comparison"]=archived_n8_proposal_evidence(F,n8_reference_dir))
        println(io,c.name,": du=",du," degree=",degree," ",status,"; finite catalog=",finite_status,"; all powers=",power["status"])
    end
    bytes2hex(SHA.sha256(read(catalog_path)))==catalog_digest || error("catalog changed during review; rerun against a stable input")
    implementation=Dict{String,Any}[]
    for package in (VBF,VBFCatalog,VBFSearch), (dir,_,files) in walkdir(joinpath(pkgdir(package),"src")),file in sort(files)
        endswith(file,".jl") || continue
        path=joinpath(dir,file)
        push!(implementation,Dict("path"=>relpath(path,PROPOSAL_ROOT),"sha256"=>bytes2hex(SHA.sha256(read(path)))))
    end
    Dict("finding"=>"F063","proposal_count"=>length(records),"julia_version"=>string(VERSION),
        "equivalence_timeout_seconds_per_pair"=>timeout_seconds,"equivalence_max_nodes_per_pair"=>max_nodes,
        "reference_scope"=>"all current APN functions-table rows at proposal dimensions; bulk member beierleleander2022_n8:12658 if available; explicit prior trace functions at n10/n11",
        "catalog_sha256"=>catalog_digest,"implementation_source_identities"=>implementation,
        "runner_sha256"=>bytes2hex(SHA.sha256(read(@__FILE__))),
        "power_evidence_helper_sha256"=>bytes2hex(SHA.sha256(read(joinpath(@__DIR__,"apn_power_evidence.jl")))),
        "gold_coverage"=>[encode_gold_coverage(gold[n]) for n in dimensions],
        "reference_functions"=>[Dict("name"=>r.name,"n"=>inputbits(r.F),"degree"=>r.degree,
            "scope"=>r.scope,"source"=>r.source,"lut"=>Int.(r.F.lut),"sha256_uint16_le"=>proposal_lut_sha(r.F)) for r in references],
        "finite_catalog_comparison_complete"=>all(r["finite_catalog_comparison_complete"] for r in records),
        "source_parameter_note"=>"Zheng Example1 is a verified representative z23 under modulus1033; primitive z2 yields DU4. No assertion about all primitive choices or unspecified publication field basis.",
        "literature_novelty_verified"=>false,"all_bulk_corpora_compared"=>false,
        "catalog_mutated"=>false,"source_identities"=>proposal_code_sources(candidates),
        "bulk_corpus_descriptors"=>corpus_descriptors,"proposals"=>records)
end

if abspath(PROGRAM_FILE)==@__FILE__
    length(ARGS)<=3 || error("usage: review_catalog_proposals.jl [output.toml] [timeout_per_pair=2] [max_nodes=100000]")
    output=isempty(ARGS) ? joinpath(PROPOSAL_ROOT,"data","repro","analysis","catalog_proposals.toml") : abspath(ARGS[1])
    report=review_catalog_proposals(timeout_seconds=length(ARGS)>=2 ? parse(Float64,ARGS[2]) : 2,
        max_nodes=length(ARGS)>=3 ? parse(Int,ARGS[3]) : 100_000)
    mkpath(dirname(output))
    temporary,out=mktemp(dirname(output))
    try
        TOML.print(out,report;sorted=true)
        close(out)
        mv(temporary,output;force=true)
    finally
        isopen(out) && close(out)
        isfile(temporary) && rm(temporary)
    end
    println("Evidence: ",output,"; no catalog writes or global novelty guarantee.")
end
