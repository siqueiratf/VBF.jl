"""Remove private singleton sources from a derived reference index after rebuilding the catalog.

Existing repeated-signature classification remains valid only when every removed
record was a singleton and no shared-bucket member changes. All remaining catalog
records, packed-source digests, curated LUTs, index rows and summary counts are
revalidated through VBFSearch before rebinding the derived classification cache.
Usage: restrict_reference.jl CATALOG_DIR REMOVED_SOURCE EVIDENCE_JSON
"""
module APNReferenceRestriction
using VBFSearch,VBFCatalog,SHA,Dates
const SQL=VBFSearch.SQLite;const DBI=VBFSearch.DBInterface;const J=VBFSearch.JSON3
scalar(db,sql,args=())=only(first(Tuple(r)) for r in DBI.execute(db,sql,args))
function main(directory,source,evidence)
 directory=abspath(directory);cat=SQL.DB("file:"*joinpath(directory,"catalog.sqlite")*"?mode=ro");idx=SQL.DB(joinpath(directory,"ccz_sigma_index.sqlite"))
 try
  corpus_info(cat,source)===nothing || error("remove the private source declaration and rebuild first")
  shared=scalar(idx,"SELECT COUNT(*) FROM ccz_sigma_index l WHERE l.source=? AND EXISTS(SELECT 1 FROM ccz_sigma_index p WHERE p.n=l.n AND p.source!=l.source AND p.sigma_hash=l.sigma_hash)",(source,))
  shared==0 || error("source has shared signatures; a full classification rebuild is required")
  scalar(idx,"SELECT COUNT(*) FROM ccz_bucket_members WHERE source=?",(source,))==0 || error("source contributed repeated-bucket evidence")
  rows=Int(scalar(idx,"SELECT COUNT(*) FROM ccz_sigma_index WHERE source=?",(source,)));rows>0 || error("source is absent already")
  prior=only(Dict(string(k)=>v for (k,v) in pairs(NamedTuple(r))) for r in DBI.execute(idx,"SELECT * FROM ccz_classification_meta WHERE n=8"))
  SQL.transaction(idx) do
   DBI.execute(idx,"DELETE FROM ccz_sigma_index WHERE source=?",(source,));DBI.execute(idx,"DELETE FROM sigma_coverage WHERE source=?",(source,))
   input=VBFSearch._classification_inputs(cat,idx,8)
   input.records==prior["records"]-rows && input.signatures==prior["signatures"]-rows && input.singletons==prior["singletons"]-rows || error("unexpected reference restriction counts")
   DBI.execute(idx,"UPDATE ccz_classification_meta SET input_sha256=?,records=?,signatures=?,singletons=? WHERE n=8",(input.input_sha256,input.records,input.signatures,input.singletons))
  end
  result=Dict("schema"=>"vbfsearch-reference-restriction-v1","removed_source"=>source,"removed_records"=>rows,"removed_shared_buckets"=>shared,"prior_classification"=>prior,"repeated_bucket_evidence_unchanged"=>true,"catalog_sha256"=>bytes2hex(open(SHA.sha256,joinpath(directory,"catalog.sqlite"))),"completed_utc"=>string(now(UTC))*"Z")
  close(idx);idx=nothing
  reference=VBFSearch.DiscoveryEvidence.open_reference(directory)
  try;result["published_reference"]=VBFSearch.reference_metadata(reference);finally;VBFSearch.DiscoveryEvidence.close_reference(reference);end
  result["classification"]=VBFSearch.classification_summary(;n=8,path=joinpath(directory,"ccz_sigma_index.sqlite"))
  open(io->J.write(io,result),evidence,"w");println(J.write(result))
 finally
  idx===nothing || close(idx);close(cat)
 end
end
end
abspath(PROGRAM_FILE)==(@__FILE__) && APNReferenceRestriction.main(ARGS...)
