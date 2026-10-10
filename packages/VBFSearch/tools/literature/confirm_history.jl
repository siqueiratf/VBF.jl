using VBF
"""Bind family separation to the existing independently checked historical candidate inputs.

Usage: julia --compiled-modules=no --startup-file=no --project=. \
    confirm_history.jl FAMILY_OUTPUT_DIR [HISTORY_REPORT]
Reuse is digest-bound. This rechecks baseline membership, not all 500090 DDTs.
"""
const CONFIRM_HISTORY_USAGE=nothing
using TOML,SHA,Dates,VBF,VBFCatalog
using VBFSearch: DiscoveryEvidence
using VBFSearch: DiscoveryInputs
using .DiscoveryEvidence,.DiscoveryInputs
include("../../../VBFCatalog/tools/reference/paths.jl")

"""Resolve audited signatures through the existing catalog API, without importing duplicate rows."""
function catalog_crosscheck(familydir)
    indexpath=VBFCatalog.sigma_index_path(); catalogpath=VBFCatalog.catalog_path()
    index=DiscoveryEvidence.SQL.DB("file:"*abspath(indexpath)*"?mode=ro")
    catalog=DiscoveryEvidence.SQL.DB("file:"*abspath(catalogpath)*"?mode=ro")
    evidence=Dict{String,Any}[];seen=Set{String}()
    try
        for line in Iterators.drop(eachline(joinpath(familydir,"luts.tsv")),1)
            id,hex,apn,degree,sigma,hit,witness=split(line,'\t';keepempty=true)
            isempty(sigma) && continue
            sigma in seen && continue
            push!(seen,sigma)
            F=VBF.SBox{8,UInt8}(hex2bytes(hex))
            VBFCatalog.sigma_hash(F)==sigma || error("catalog/independent invariant disagreement")
            status,source,member=VBFCatalog.classify_ccz(F;index,catalog)
            push!(evidence,Dict("sigma_hash"=>String(sigma),"lut_sha256"=>String(id),
                "status"=>string(status),"source"=>something(source,"none"),"member_idx"=>something(member,-1)))
        end
        report=Dict("source_sha256"=>filehash(@__FILE__),"catalog_sha256"=>filehash(catalogpath),
            "index_sha256"=>filehash(indexpath),"family_report_sha256"=>filehash(joinpath(familydir,"report.toml")),
            "api"=>"VBFCatalog.sigma_hash and VBFCatalog.classify_ccz with catalog coverage checks",
            "signatures"=>length(seen),"signature_matches"=>count(r->r["status"]=="sigma_match",evidence),
            "evidence"=>evidence,"guarantee"=>"Existing catalog locations for audited invariant buckets; a signature match is not an equivalence witness.")
        open(io->TOML.print(io,report;sorted=true),joinpath(familydir,"catalog_crosscheck.toml"),"w")
        println("Existing catalog API: $(report["signature_matches"])/$(length(seen)) audited signatures matched; no duplicate catalog rows imported.")
        report
    finally
        DiscoveryEvidence.SQL.close(index);DiscoveryEvidence.SQL.close(catalog)
    end
end
function confirm_history(familydir,historypath=joinpath(@__DIR__, "../../../../data/apn/archive/census/discovery/results/history/history.toml"))
    history=TOML.parsefile(historypath)
    family=TOML.parsefile(joinpath(familydir,"report.toml"))
    family["completed"] || error("incomplete family audit")
    baseline=artifact_path(dirname(history["reference"]["path"]))
    reference=open_reference(baseline)
    try
        for key in ("sha256","manifest_sha256","supplement_sha256")
            reference.metadata[key]==family["reference"][key]==history["reference"][key] || error("different reference scopes")
        end
        filehash(joinpath(baseline,"candidate_comparison.toml"))==history["verification"]["prior_report_sha256"] || error("prior independent report changed")
        paths=[artifact_path(joinpath(ROOT,s["path"])) for s in history["sources"]]
        all(filehash(p)==s["sha256"] for (p,s) in zip(paths,history["sources"])) || error("candidate changed")
        known,verification=validated_study(paths,baseline)
        length(known)==history["distinct_study_signatures"] || error("history count changed")
        DBI=DiscoveryEvidence.DBI
        DBI.execute(reference.db,"CREATE TEMP TABLE study(sigma_hash TEXT PRIMARY KEY) WITHOUT ROWID")
        DBI.execute(reference.db,"BEGIN")
        stmt=DBI.prepare(reference.db,"INSERT INTO study VALUES(?)")
        try
            for hash in known
                DBI.execute(stmt,(hash,))
            end
            DBI.execute(reference.db,"COMMIT")
        finally
            DBI.close!(stmt)
        end
        absent=Set(String(r.sigma_hash) for r in DBI.execute(reference.db,
            "SELECT s.sigma_hash FROM study s LEFT JOIN signatures b ON s.sigma_hash=b.sigma_hash WHERE b.sigma_hash IS NULL"))
        setdiff!(absent,keys(reference.supplement))
        length(absent)==history["corpus_absent_signature_buckets"] || error("historical absence count differs")
        family_hashes=Set(s for values in values(family["family_signatures"]) for s in values)
        overlap=intersect(absent,family_hashes)
        missing=String[]
        for hash in family_hashes
            hit=haskey(reference.supplement,hash) || !isempty(collect(DBI.execute(reference.statement,(hash,))))
            hit || push!(missing,hash)
        end
        length(missing)==family["distinct_absent_signatures"] || error("family membership changed")
        report=Dict("created_utc"=>string(now(UTC)),"source_sha256"=>filehash(@__FILE__),
            "history_report_sha256"=>filehash(historypath),"family_report_sha256"=>filehash(joinpath(familydir,"report.toml")),
            "family_parameters_sha256"=>filehash(joinpath(familydir,"parameters.tsv")),"reference"=>reference.metadata,
            "candidate_verification"=>verification,"corpus_absent_candidates"=>length(absent),
            "audited_family_signatures"=>length(family_hashes),"candidate_family_signature_overlap"=>sort(collect(overlap)),
            "all_absent_candidates_separated_from_audited_quadratic_domains"=>isempty(overlap),
            "all_audited_quadratic_family_signatures_in_reference"=>isempty(missing),
            "literature_novelty"=>"unresolved", "guarantee"=>"Different ortho-derivative invariants separate verified quadratic APNs under EA and CCZ (Yoshiara 2012). Named-domain coverage is limited to family_coverage.toml. APN power exclusion uses Yoshiara 2016.")
        open(io->TOML.print(io,report;sorted=true),joinpath(familydir,"candidate_separation.toml"),"w")
        println("Corpus-absent candidate signatures: $(length(absent)); audited quadratic family signatures: $(length(family_hashes)); overlaps: $(length(overlap)); family signatures absent from reference: $(length(missing))")
        report
    finally
        close_reference(reference)
    end
end
if abspath(PROGRAM_FILE)==@__FILE__
    length(ARGS) in (1,2) || error("expected FAMILY_OUTPUT_DIR [HISTORY_REPORT]")
    catalog_crosscheck(abspath(ARGS[1]))
    confirm_history(abspath(ARGS[1]),ARGS[2:end]...)
end
