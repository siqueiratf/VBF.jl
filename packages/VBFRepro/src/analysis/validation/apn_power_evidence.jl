# Shared research-consumer evidence for a sourced theorem; no catalog writes.
module APNPowerEvidence
using VBF, SHA
export gold_indices, build_gold_coverage, gold_power_evidence, encode_gold_coverage,
       known_power_controls, power_target_identity, power_lut_sha, power_exclusion_applies,
       YOSHIARA_POWER_THEOREM

const YOSHIARA_POWER_THEOREM=Dict(
    "source"=>"https://link.springer.com/article/10.1007/s10801-016-0680-z",
    "theorem"=>"Yoshiara2016 Theorem2",
    "hypotheses"=>"n>=3; candidate is a quadratic APN function on GF(2^n)",
    "statement"=>"A quadratic APN is CCZ-equivalent to an APN power function iff it is EA-equivalent to a Gold function.",
    "use"=>"Unequal exact ortho-derivative invariant tuples against every admissible Gold index exclude every APN power function. Matching tuples do not prove equivalence.")

power_lut_sha(F)=bytes2hex(SHA.sha256(UInt8[b for x in F.lut for b in (Int(x)&255,Int(x)>>8)]))
gold_indices(n::Int)=[k for k in 1:n-1 if gcd(k,n)==1]

"""Check ALL admissible Gold indices, retaining incomplete budget outcomes.
Indices are not collapsed using invariant equality. Each LUT is checked APN/quadratic.
The deadline is cooperative: a row may finish after it, but the coverage then
remains incomplete even when that row was the final requested index.
"""
function build_gold_coverage(n::Int;modulus::Int=primitive_polynomial(n),
        indices=gold_indices(n),max_evaluations::Int=typemax(Int),timeout_seconds::Real=Inf)
    3<=n<=12 || throw(ArgumentError("supported theorem evidence dimensions are3:12"))
    max_evaluations>=0 && timeout_seconds>=0 || throw(ArgumentError("nonnegative Gold budgets required"))
    gf_primitive_element(n;modulus) # validates an actual field; integer2 need not be a generator
    expected=gold_indices(n);requested=Int.(collect(indices))
    all(k->k in expected,requested) || throw(ArgumentError("inadmissible Gold index"))
    length(unique(requested))==length(requested) || throw(ArgumentError("duplicate Gold index"))
    started=time_ns();records=NamedTuple[];stopped=false
    for k in requested
        if length(records)>=max_evaluations || (time_ns()-started)/1e9>=timeout_seconds
            stopped=true;break
        end
        F=gold_apn(n,k;modulus);du=differential_uniformity(F);degree=algebraic_degree(F)
        du==2 && degree==2 || error("Gold hypothesis contradiction at n$n k$k")
        push!(records,(;k,exponent=(1<<k)+1,F,du,degree,sigma=sigma_key(F),sha256_uint16_le=power_lut_sha(F)))
        if (time_ns()-started)/1e9>=timeout_seconds
            stopped=true;break
        end
    end
    checked=[r.k for r in records];missing=setdiff(expected,checked)
    (;n,modulus,expected,records,missing,complete=isempty(missing) && !stopped,
        max_evaluations,timeout_seconds,budget_exhausted=stopped,
        elapsed_seconds=(time_ns()-started)/1e9)
end

"""Apply the theorem only after actual candidate properties and complete Gold coverage.
Fail closed on dimensions, missing indices, or an invariant collision.
"""
function gold_power_evidence(F::SBox,coverage)
    n=inputbits(F);du=differential_uniformity(F);degree=algebraic_degree(F)
    result=Dict{String,Any}("n"=>n,"du"=>du,"degree"=>degree,
        "candidate_sha256_uint16_le"=>power_lut_sha(F),"theorem"=>deepcopy(YOSHIARA_POWER_THEOREM),
        "all_apn_power_functions_excluded"=>false,"literature_novelty_verified"=>false)
    if n<3 || du!=2 || degree!=2
        result["status"]="theorem_hypotheses_not_met";return result
    end
    if n!=coverage.n
        result["status"]="coverage_dimension_mismatch";return result
    end
    # Do not trust a caller's `complete` flag without checking the actual domain.
    expected=gold_indices(n);checked=[r.k for r in coverage.records]
    complete=coverage.complete && sort(checked)==expected && coverage.expected==expected
    result["expected_gold_indices"]=expected
    result["checked_gold_indices"]=checked
    result["missing_gold_indices"]=setdiff(expected,checked)
    result["gold_coverage_complete"]=complete
    if !complete
        result["status"]="incomplete_gold_coverage";return result
    end
    valid=try
        gf_primitive_element(n;modulus=coverage.modulus)
        all(r->r.exponent==(1<<r.k)+1 && r.du==2 && r.degree==2 && inputbits(r.F)==n &&
            power_lut_sha(r.F)==r.sha256_uint16_le &&
            r.F.lut==gold_apn(n,r.k;modulus=coverage.modulus).lut && sigma_key(r.F)==r.sigma,coverage.records)
    catch error
        error isa InterruptException && rethrow()
        false
    end
    result["gold_reference_integrity_verified"]=valid
    if !valid
        result["gold_coverage_complete"]=false
        result["status"]="invalid_gold_reference_evidence";return result
    end
    sig=sigma_key(F)
    result["candidate_sigma_differential"]=[[Int(k),Int(v)] for (k,v) in sig[1]]
    result["candidate_sigma_absolute_walsh"]=[[Int(k),Int(v)] for (k,v) in sig[2]]
    checks=[Dict("k"=>r.k,"exponent"=>r.exponent,
        "reference_sha256_uint16_le"=>r.sha256_uint16_le,"exact_invariants_equal"=>sig==r.sigma) for r in coverage.records]
    result["gold_checks"]=checks
    result["matching_gold_indices"]=[r.k for r in coverage.records if sig==r.sigma]
    excluded=all(x->!x["exact_invariants_equal"],checks)
    result["all_apn_power_functions_excluded"]=excluded
    result["status"]=excluded ? "ccz_inequivalent_to_every_apn_power_function" : "gold_invariant_match_unresolved"
    result
end

"""Bind a computed theorem outcome to the current candidate before reusing it."""
function power_exclusion_applies(F::SBox,evidence)
    get(evidence,"all_apn_power_functions_excluded",false) &&
        get(evidence,"status","")=="ccz_inequivalent_to_every_apn_power_function" &&
        get(evidence,"gold_coverage_complete",false) &&
        get(evidence,"gold_reference_integrity_verified",false) &&
        get(evidence,"n",0)==inputbits(F) && get(evidence,"du",0)==2 && get(evidence,"degree",0)==2 &&
        get(evidence,"candidate_sha256_uint16_le","")==power_lut_sha(F)
end

function encode_gold_coverage(c)
    Dict("n"=>c.n,"modulus"=>c.modulus,"expected_indices"=>c.expected,
        "missing_indices"=>c.missing,"complete"=>c.complete,"elapsed_seconds"=>c.elapsed_seconds,
        "max_evaluations"=>c.max_evaluations,"timeout_seconds"=>c.timeout_seconds,
        "budget_exhausted"=>c.budget_exhausted,
        "theorem"=>deepcopy(YOSHIARA_POWER_THEOREM),
        "references"=>[Dict("k"=>r.k,"exponent"=>r.exponent,"du"=>r.du,"degree"=>r.degree,
            "sha256_uint16_le"=>r.sha256_uint16_le,"lut"=>Int.(r.F.lut),
            "sigma_differential"=>[[Int(k),Int(v)] for (k,v) in r.sigma[1]],
            "sigma_absolute_walsh"=>[[Int(k),Int(v)] for (k,v) in r.sigma[2]]) for r in c.records])
end

"""Literal controls for identifying current reference targets as known power maps.
Failure to identify a target is not a proof that it has no power presentation.
The candidate's theorem check, independently, covers ALL APN power functions.
"""
function known_power_controls(n::Int;modulus::Int=primitive_polynomial(n))
    records=NamedTuple[]
    add(family,exponent,F)=push!(records,(;family,exponent=mod(exponent,(1<<n)-1),modulus,F,
        sha256_uint16_le=power_lut_sha(F)))
    for k in gold_indices(n)
        add("Gold(k=$k)",(1<<k)+1,gold_apn(n,k;modulus))
        add("Kasami(k=$k)",(1<<(2k))-(1<<k)+1,kasami_apn(n,k;modulus))
    end
    if isodd(n)
        t=n÷2
        add("Welch",(1<<t)+3,welch_apn(n;modulus))
        e=iseven(t) ? (1<<t)+(1<<(t÷2))-1 : (1<<t)+(1<<((3t+1)÷2))-1
        add("Niho",e,niho_apn(n;modulus))
        add("Inverse",(1<<n)-2,inverse_apn(n;modulus))
    end
    if n%5==0
        k=n÷5;e=(1<<(4k))+(1<<(3k))+(1<<(2k))+(1<<k)-1
        add("Dobbertin",e,dobbertin_apn(n;modulus))
    end
    records
end

function power_target_identity(G::SBox,controls)
    for r in controls
        G.lut==r.F.lut || continue
        # Literal identity licenses the theorem only if the matched control
        # still replays as the recorded monomial in a valid binary field.
        valid=try
            n=inputbits(G)
            gf_primitive_element(n;modulus=r.modulus)
            inputbits(r.F)==n && power_lut_sha(r.F)==r.sha256_uint16_le &&
                1<=r.exponent<(1<<n)-1 &&
                all(Int(G.lut[x+1])==gf_pow(x,r.exponent,n;modulus=r.modulus) for x in 0:(1<<n)-1)
        catch error
            error isa InterruptException && rethrow()
            false
        end
        valid || continue
        return Dict("status"=>"literal_known_power_map","family"=>r.family,
            "exponent"=>r.exponent,"modulus"=>r.modulus,"sha256_uint16_le"=>power_lut_sha(G))
    end
    Dict("status"=>"not_identified_as_power","sha256_uint16_le"=>power_lut_sha(G))
end
end
