"""Prepare digest-bound comparison pairs from isolated root/historical datasets.

The plan database contains source/member references and optional positive EA
witnesses. Catalog records are read through VBFCatalog; packed quadratic members
are decoded later by VBF workers. This does not modify any function database.
Usage: prepare_comparisons.jl AUDIT_DIR CATALOG_DIR
"""
module APNComparisonPairs
using VBFSearch,VBFCatalog,SHA
const SQL=VBFSearch.SQLite;const DBI=VBFSearch.DBInterface;const J=VBFSearch.JSON3
hashfile(p)=bytes2hex(open(SHA.sha256,p))
function prepare(out,reference)
 out=abspath(out);reference=abspath(reference)
 cat=SQL.DB("file:"*joinpath(reference,"catalog.sqlite")*"?mode=ro")
 plan=SQL.DB("file:"*joinpath(out,"comparisons.sqlite")*"?mode=ro")
 wanted=Dict{String,Set{Int}}()
 for row in DBI.execute(plan,"SELECT target_source,target_member_idx FROM literature WHERE pair_id IS NOT NULL")
  push!(get!(()->Set{Int}(),wanted,String(row.target_source)),Int(row.target_member_idx))
 end
 targets=Dict{Tuple{String,Int},Vector{UInt8}}()
 for source in sort!(collect(keys(wanted)))
  if source=="functions"
   for idx in wanted[source];targets[(source,idx)]=UInt8.(load_sbox(cat,idx).lut);end
  else
   info=corpus_info(cat,source);info.modulus==285 && info.encoding=="quadratic-coeffs-v1" || error("unsupported catalog encoding")
   with_corpus_rows(cat,source) do rows
    for row in rows
     row.idx in wanted[source] && (targets[(source,Int(row.idx))]=Vector{UInt8}(row.coeffs))
    end
   end
  end
  println(J.write(Dict("packed_source"=>source,"selected"=>length(wanted[source]))));flush(stdout)
 end
 DBI.execute(plan,"ATTACH DATABASE ? AS roots",("file:"*joinpath(out,"datasets/published-roots-24294.sqlite")*"?mode=ro",))
 DBI.execute(plan,"ATTACH DATABASE ? AS old",("file:"*joinpath(out,"datasets/historical-190454.sqlite")*"?mode=ro",))
 function prepare(name,query)
  directory=joinpath(out,name);mkpath(directory);count=cached=0;ctx=SHA.SHA2_256_CTX()
  open(joinpath(directory,"pairs.bin"),"w") do io
   open(joinpath(directory,"cached-proofs.bin"),"w") do certs
    for row in DBI.execute(plan,query)
     count+=1;row.pair_id==count || error("unordered pair roster")
     f=Vector{UInt8}(row.f)
     g=name=="literature" ? targets[(String(row.target_source),Int(row.target_member_idx))] : Vector{UInt8}(row.g)
     length(f)==256 && length(g) in (37,256) || error("invalid pair encoding")
     write(io,UInt8(length(g)==37 ? 1 : 0));write(io,f);write(io,g);length(g)==37 && write(io,zeros(UInt8,219))
     proof=ismissing(row.cached_proof) ? zeros(UInt8,35) : Vector{UInt8}(row.cached_proof)
     length(proof)==35 && proof[1] in (0,1) || error("invalid cached proof record")
     write(certs,proof);cached+=proof[1]==1
     SHA.update!(ctx,codeunits(string(count,':',row.class_id,':',bytes2hex(SHA.sha256(f)),':',bytes2hex(SHA.sha256(g)),'\n')))
    end
   end
  end
  meta=Dict("schema"=>"vbfsearch-comparison-pairs-v1","comparison"=>name,"rows"=>count,"cached_pairs"=>cached,"bytes_per_pair"=>513,"input_sha256"=>hashfile(joinpath(directory,"pairs.bin")),"cached_proofs_sha256"=>hashfile(joinpath(directory,"cached-proofs.bin")),"pair_roster_sha256"=>bytes2hex(SHA.digest!(ctx)))
  open(io->J.write(io,meta),joinpath(directory,"pairs.json"),"w");println(J.write(meta));flush(stdout)
 end
 prepare("literature","SELECT l.pair_id,l.class_id,c.lut f,l.target_source,l.target_member_idx,l.cached_proof FROM literature l JOIN roots.classes c ON c.class_id=l.class_id WHERE l.pair_id IS NOT NULL ORDER BY l.pair_id")
 empty!(targets);GC.gc()
 prepare("historical","SELECT h.pair_id,h.class_id,o.lut f,c.lut g,h.cached_proof FROM historical h JOIN roots.classes c ON c.class_id=h.class_id JOIN old.classes o ON o.class_id=h.historical_class_id ORDER BY h.pair_id")
 close(plan);close(cat)
end
function main(out,reference)
 withenv("BFA_DATA_DIR"=>abspath(reference)) do
  prepare(out,reference)
 end
end
end
abspath(PROGRAM_FILE)==(@__FILE__) && APNComparisonPairs.main(ARGS...)
