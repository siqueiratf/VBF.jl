# Implements Section 3.2, Table 4
# Paper: Yu, Kaleyski, Budaghyan, Li (2020),
#   "Classification of quadratic APN functions with coefficients in F₂ for dimensions up to 9"
# Section: 3.2, Table 4 — n=9: 8 CCZ classes, 2 previously unknown (s₁, s₂)
#
# Scope: formula/APN/quadratic/AB checks on eight publication representatives,
# and signature separation from the explicitly enumerated curated n9 APN entries.
# This is not a complete literature corpus. Matching signatures only locate
# equivalence queries. Power references use an explicit Gold-domain theorem check;
# other nonquadratic references require general CCZ evidence.
# No catalog writes or literature-novelty guarantee follows from this report.

include(joinpath(@__DIR__, "helpers.jl"))

using VBFCatalog, SHA, TOML
if !isdefined(@__MODULE__, :APNPowerEvidence)
    include(joinpath(@__DIR__,"..","..","..","analysis","scripts","apn_power_evidence.jl"))
end
using .APNPowerEvidence

# (exponents, label, is_new)
const TABLE4_FUNCTIONS = [
    ([3],                                   "x³",   false),
    ([5],                                   "x⁵",   false),
    ([17],                                  "x¹⁷",  false),
    ([136, 132, 96, 80, 36, 34, 18, 17, 12], "s₁",  true),
    ([257, 144, 130, 72, 65, 18, 9],        "f₅",   false),
    ([144, 130, 72, 65, 18, 9, 3],          "f₆",   false),
    ([264, 160, 144, 132, 80, 72, 66, 40, 17], "f₇", false),
    ([288, 272, 264, 160, 144, 130, 48, 34], "s₂",  true),
]

"""
    n9_catalog_split() -> (quadratic, non_quadratic)

Every n=9 APN row in the catalog functions table, split by whether σ can reach it.
Bulk-corpus/construction coverage and literature completeness are not asserted. `quadratic` entries are
`(name, sigma_key)`; `non_quadratic` are `(name, algebraic_degree)` — σ is undefined
there (no ortho-derivative), which is limit (a).
"""
function n9_catalog_evidence()
    records=NamedTuple[]
    catalog_digest=bytes2hex(SHA.sha256(read(VBFCatalog.catalog_path())))
    db=VBFCatalog.load_catalog()
    try
        for row in VBFCatalog.list_functions(db;n=9,is_apn=true)
            F=VBFCatalog.load_sbox(db,row.id)
            differential_uniformity(F)==2 || error("catalog APN flag failed derivative check: $(row.id)")
            name=row.canonical_name===nothing ? "id:$(row.id)" : String(row.canonical_name)
            degree=algebraic_degree(F)
            push!(records,(;name,F,degree,sigma=degree==2 ? sigma_key(F) : nothing,
                source_repo=String(row.source_repo),sha256_uint16_le=power_lut_sha(F)))
        end
    finally
        VBFCatalog.SQLite.close(db)
    end
    bytes2hex(SHA.sha256(read(VBFCatalog.catalog_path())))==catalog_digest || error("catalog changed during Table4 comparison")
    (;records,catalog_digest)
end

function n9_catalog_split()
    evidence=n9_catalog_evidence()
    ([(r.name,r.sigma) for r in evidence.records if r.degree==2],
     [(r.name,r.degree) for r in evidence.records if r.degree!=2])
end

"""Per-target scoped comparison, with no inference from algebraic degree alone."""
function table4_target_evidence(F,r,power,controls)
    result=Dict{String,Any}("reference"=>r.name,"reference_degree"=>r.degree,
        "candidate_sha256_uint16_le"=>power_lut_sha(F),"reference_sha256_uint16_le"=>r.sha256_uint16_le)
    if F.lut==r.F.lut
        result["status"]="identical_lut"
    elseif r.degree==2
        result["status"]=sigma_key(F)!=r.sigma ? "ccz_inequivalent_by_exact_quadratic_invariant" : "invariant_match_equivalence_unresolved"
    else
        identity=power_target_identity(r.F,controls)
        result["power_target_identity"]=identity
        if identity["status"]=="literal_known_power_map"
            result["status"]=power_exclusion_applies(F,power) ? "ccz_inequivalent_by_yoshiara_power_theorem" : "inconclusive_power_coverage"
        else
            left=sorted_pairs(absolute_walsh_spectrum(F));right=sorted_pairs(absolute_walsh_spectrum(r.F))
            result["status"]=left!=right ? "ccz_inequivalent_by_exact_walsh_spectrum" : "general_ccz_comparison_unresolved"
        end
    end
    result
end

"""Render only the separation guarantees actually established by these checks."""
function table4_scope_note(candidate_evidence,n_quadratic,n_nonquadratic,pair_separated)
    selected=filter(c->c["label"] in ("s₁","s₂"),candidate_evidence)
    quadratic_separated=length(selected)==2 && all(selected) do c
        targets=filter(r->r["reference_degree"]==2,c["target_checks"])
        !isempty(targets) && all(r->r["status"]=="ccz_inequivalent_by_exact_quadratic_invariant",targets)
    end
    powers_excluded=length(selected)==2 && all(c->c["power_exclusion"]["all_apn_power_functions_excluded"],selected)
    quadratic_note=quadratic_separated ?
        "s₁/s₂ are separated by exact signatures from the $n_quadratic explicitly enumerated curated quadratic n9 references. " :
        "Separation of s₁/s₂ from every current curated quadratic n9 reference remains unresolved. "
    pair_note=pair_separated ? "Their unequal exact signatures also separate them from each other. " :
        "Their mutual CCZ equivalence remains unresolved. "
    power_note=powers_excluded ?
        "Complete Gold checks and Yoshiara2016 Theorem2 exclude every APN power function. " :
        "The Gold coverage or power exclusion is incomplete; no exclusion of every APN power function follows. "
    quadratic_note * pair_note * "Matching signatures require exact witnesses. " * power_note *
        "The $n_nonquadratic current nonquadratic targets need literal power identities or general CCZ evidence. " *
        "Unlisted non-power constructions remain unresolved; no literature-completeness or novelty guarantee is established."
end

"""
    table4_verify() -> NamedTuple
"""
function table4_verify(;gold_indices_to_check=gold_indices(9),gold_max_evaluations::Int=typemax(Int),gold_timeout_seconds::Real=Inf)
    n = 9
    checks = Tuple{String,Bool}[]

    boxes = [(label, sbox_from_exponents(n, exps), isnew)
             for (exps, label, isnew) in TABLE4_FUNCTIONS]

    # 1. All 8 are APN, quadratic, and AB — the abstract's "s₁, s₂ are also AB" (R7).
    for (label, F, _) in boxes
        push!(checks, ("$label: APN (δ=2)", differential_uniformity(F) == 2))
        push!(checks, ("$label: quadratic (deg 2)", algebraic_degree(F) == 2))
        push!(checks, ("$label: AB (linearity 2⁵=32)", is_almost_bent(F)))
    end

    reference=n9_catalog_evidence()
    quad_entries=[(r.name,r.sigma) for r in reference.records if r.degree==2]
    nonquad_entries=[(r.name,r.degree) for r in reference.records if r.degree!=2]
    gold=build_gold_coverage(9;indices=gold_indices_to_check,max_evaluations=gold_max_evaluations,timeout_seconds=gold_timeout_seconds)
    controls=known_power_controls(9)
    candidate_evidence=Dict{String,Any}[]
    for (label,F,isnew) in boxes
        power=gold_power_evidence(F,gold)
        targets=[table4_target_evidence(F,r,power,controls) for r in reference.records]
        separated=!isempty(targets) && all(startswith(r["status"],"ccz_inequivalent_") for r in targets)
        push!(candidate_evidence,Dict("label"=>label,"lut"=>Int.(F.lut),
            "sha256_uint16_le"=>power_lut_sha(F),"power_exclusion"=>power,"target_checks"=>targets,
            "finite_catalog_separation_proved"=>separated,"literature_novelty"=>"unresolved"))
        isnew || continue
        push!(checks,("$label: all admissible Gold indices checked and every APN power construction excluded",power["all_apn_power_functions_excluded"]))
        push!(checks,("$label: CCZ-separated from every explicitly enumerated current catalog APN target",separated))
    end
    push!(checks, ("n=9 catalog has quadratic entries to compare against",
                   !isempty(quad_entries)))

    # 2. Separation from the explicitly enumerated curated quadratic entries.
    for (label, F, isnew) in boxes
        isnew || continue
        h = sigma_key(F)
        mismatch_all = !isempty(quad_entries) && all(h != qh for (_, qh) in quad_entries)
        push!(
            checks,
            ("$label: σ-MISMATCH against all $(length(quad_entries)) quadratic n=9 catalog " *
             "entries ⟹ rigorously CCZ-inequivalent to each",
             mismatch_all),
        )
        push!(checks, ("$label: signature absent from the enumerated curated quadratic entries",
                       !isempty(quad_entries) && all(h != qh for (_, qh) in quad_entries)))
    end

    # 3. s₁ and s₂ are CCZ-inequivalent to each other (σ-mismatch, rigorous).
    s1 = sbox_from_exponents(n, TABLE4_FUNCTIONS[4][1])
    s2 = sbox_from_exponents(n, TABLE4_FUNCTIONS[8][1])
    push!(checks, ("σ(s₁) ≠ σ(s₂) ⟹ s₁ and s₂ are CCZ-inequivalent", sigma_key(s1) != sigma_key(s2)))

    # Current nonquadratic n9 targets are literal known power maps, established
    # by complete LUT identity to core constructors, rather than by degree tags.
    push!(checks,("all current nonquadratic n9 references identified as explicit power maps",
        all(power_target_identity(r.F,controls)["status"]=="literal_known_power_map" for r in reference.records if r.degree!=2)))

    # Positive controls locate reference candidates by signatures. They do not
    # establish equivalence or completeness of the wider literature database.
    f7 = sbox_from_exponents(n, TABLE4_FUNCTIONS[7][1])
    push!(
        checks,
        ("known f₇ has a signature match among curated references; exact equivalence is separate",
         any(sigma_key(f7) == h for (_,h) in quad_entries)),
    )

    # Guard against a vacuous novelty test: the catalog lookup must actually be able to
    # RECOGNISE something. f₅ and f₆ are in the catalog and must NOT read :new.
    f5 = sbox_from_exponents(n, TABLE4_FUNCTIONS[5][1])
    f6 = sbox_from_exponents(n, TABLE4_FUNCTIONS[6][1])
    push!(
        checks,
        ("non-vacuity: f₅ and f₆ ARE found in the catalog (σ-match) — the :new verdicts " *
         "above are not an artefact of an empty or broken index",
         any(sigma_key(f5) == h for (_,h) in quad_entries) && any(sigma_key(f6) == h for (_,h) in quad_entries)),
    )

    finite_separated=all(c["finite_catalog_separation_proved"] for c in candidate_evidence if c["label"] in ("s₁","s₂"))
    (; checks,
       n_quadratic_catalog = length(quad_entries),
       n_nonquadratic_catalog = length(nonquad_entries),
       literature_novelty = :unresolved,
       catalog_sha256=reference.catalog_digest,
       gold_coverage=encode_gold_coverage(gold),
       candidate_evidence,
       finite_catalog_separation_proved=finite_separated,
       reference_functions=[Dict("name"=>r.name,"degree"=>r.degree,"source_repo"=>r.source_repo,
           "sha256_uint16_le"=>r.sha256_uint16_le,"lut"=>Int.(r.F.lut)) for r in reference.records],
       note=table4_scope_note(candidate_evidence,length(quad_entries),length(nonquad_entries),sigma_key(s1)!=sigma_key(s2)))
end

function table4_report(io::IO = stdout;save_results::Bool=false)
    print_section(io, "Table 4 — n=9 (8 publication representatives; scoped separation)")
    result = table4_verify()
    print_kv(io, "note", result.note)
    print_kv(io, "quadratic n=9 catalog entries (σ-comparable)", result.n_quadratic_catalog)
    print_kv(io, "nonquadratic n9 catalog targets", result.n_nonquadratic_catalog)
    for (desc, ok) in result.checks
        print_check(io, desc, ok)
    end
    all_pass = all(ok for (_, ok) in result.checks)
    print_kv(io, "overall", all_pass ? "all checks pass" : "SOME CHECKS FAILED")
    if save_results
        evidence=Dict("finding"=>"F040","catalog_sha256"=>result.catalog_sha256,
            "julia_version"=>string(VERSION),"gold_coverage"=>result.gold_coverage,
            "candidate_evidence"=>result.candidate_evidence,"reference_functions"=>result.reference_functions,
            "finite_catalog_separation_proved"=>result.finite_catalog_separation_proved,
            "literature_novelty_verified"=>false,"scope"=>"current catalog functions-table snapshot and every APN power function; no n9 bulk or literature completeness",
            "runner_sha256"=>bytes2hex(SHA.sha256(read(@__FILE__))),
            "power_evidence_helper_sha256"=>bytes2hex(SHA.sha256(read(joinpath(@__DIR__,"..","..","..","analysis","scripts","apn_power_evidence.jl")))))
        directory=joinpath(@__DIR__,"results");mkpath(directory)
        temporary,out=mktemp(directory)
        try
            TOML.print(out,evidence;sorted=true);close(out)
            mv(temporary,joinpath(directory,"table4_evidence.toml");force=true)
        finally
            isopen(out) && close(out)
            isfile(temporary) && rm(temporary)
        end
    end
    result
end

if abspath(PROGRAM_FILE) == @__FILE__
    table4_report()
end
