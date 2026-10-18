"""Lossless compact export of a frozen APN class database, and its exact restore.

Run from the root environment, with threads for the signature checks:
  compact.jl export FREEZE.sqlite DIR [REPRESENTATIVES.tsv]
  compact.jl restore DIR NEW.sqlite
Each class LUT becomes VBF's 37-byte quadratic-coeffs-v1 record. The export drops
`lut_sha256` and `sigma_hash` only after it proves that SHA-256 and VBF.sigma_hash
rebuild both for every class; every other table and column is kept as TSV. A
restore must reproduce the logical SHA-256 of every table, so logical identity,
not the SQLite page layout, is the contract. An optional historical TSV is
recorded only when the restore can regenerate it byte for byte.
"""
module APNDatasetCompact
using VBF,VBFSearch,SHA,Dates
const SQL=VBFSearch.SQLite;const DBI=VBFSearch.DBInterface;const J=VBFSearch.JSON3
const FORMAT="vbfsearch-apn-compact-v1";const RECORD=37;const MODULUS=conway_polynomial(8)
const DERIVED=("sigma_hash","lut_sha256","lut")
const REPRESENTATIVES=("sigma_hash","lut","lut_sha256","source","source_member_idx","source_run")
hashfile(path)=bytes2hex(open(SHA.sha256,path))
quoted(name)="\""*replace(name,"\""=>"\"\"")*"\""
escape(s)=replace(s,'\\'=>"\\\\",'\t'=>"\\t",'\n'=>"\\n",'\r'=>"\\r")
function unescape(s)
 io=IOBuffer();escaped=false
 for c in s
  if escaped
   write(io,c=='t' ? '\t' : c=='n' ? '\n' : c=='r' ? '\r' : c=='\\' ? '\\' : error("invalid TSV escape \\$c"));escaped=false
  elseif c=='\\'
   escaped=true
  else
   write(io,c)
  end
 end
 escaped && error("unterminated TSV escape");String(take!(io))
end
cell(v)=v isa Missing ? "\\N" : v isa Integer ? string(v) : v isa AbstractString ? escape(v) :
 v isa AbstractVector{UInt8} ? bytes2hex(v) : error("unsupported SQLite value $(typeof(v))")
function parse_cell(s,type)
 s=="\\N" && return missing
 type=="INTEGER" ? parse(Int,s) : type=="TEXT" ? unescape(s) : type=="BLOB" ? hex2bytes(s) : error("unsupported column type $type")
end
"""Typed canonical text of one value; the digest distinguishes SQLite storage classes."""
tag(v)=v isa Missing ? "n" : v isa Integer ? "i"*string(v) : v isa AbstractString ? "t"*escape(v) :
 v isa AbstractVector{UInt8} ? "b"*bytes2hex(v) : v isa AbstractFloat ? "r"*repr(v) : error("unsupported SQLite value $(typeof(v))")
scalar(db,sql)=only(first(Tuple(r)) for r in DBI.execute(db,sql))
columns(db,t)=[(name=String(r.name),type=uppercase(String(r.type)),pk=Int(r.pk)) for r in DBI.execute(db,"PRAGMA table_info($(quoted(t)))")]
function ordering(cols)
 keys=sort!([c for c in cols if c.pk>0];by=c->c.pk)
 join(quoted.(getfield.(isempty(keys) ? cols : keys,:name)),",")
end
"""SHA-256 of all rows in primary-key order, one typed tab-separated line per row."""
function digest(db,t,cols)
 ctx=SHA.SHA256_CTX()
 for r in DBI.execute(db,"SELECT $(join(quoted.(getfield.(cols,:name)),",")) FROM $(quoted(t)) ORDER BY $(ordering(cols))")
  SHA.update!(ctx,codeunits(join((tag(v) for v in Tuple(r)),'\t')*"\n"))
 end
 bytes2hex(SHA.digest!(ctx))
end
function write_tsv(db,t,cols,path)
 open(path,"w") do io
  println(io,join(escape.(getfield.(cols,:name)),'\t'))
  for r in DBI.execute(db,"SELECT $(join(quoted.(getfield.(cols,:name)),",")) FROM $(quoted(t)) ORDER BY $(ordering(cols))")
   println(io,join((cell(v) for v in Tuple(r)),'\t'))
  end
 end
 basename(path)
end
function read_tsv(path,cols)
 lines=eachline(path);header=iterate(lines)
 header===nothing && error("empty TSV $path")
 split(header[1],'\t')==escape.(getfield.(cols,:name)) || error("TSV columns differ: $path")
 rows=Vector{Any}[]
 for line in Iterators.rest(lines,header[2])
  fields=split(line,'\t');length(fields)==length(cols) || error("invalid TSV row in $path")
  push!(rows,Any[parse_cell(f,c.type) for (f,c) in zip(fields,cols)])
 end
 rows
end
function insert_rows!(db,t,rows,width)
 stmt=DBI.prepare(db,"INSERT INTO $(quoted(t)) VALUES($(join(fill("?",width),",")))")
 try
  for row in rows;DBI.execute(stmt,row);end
 finally
  DBI.close!(stmt)
 end
end
"""Prove the derived columns for every class, then write records and kept columns."""
function export_classes(db,cols,out)
 names=getfield.(cols,:name)
 all(in(names),("class_id",DERIVED...)) || error("classes table lacks class_id or a derived column")
 kept=[c for c in cols if !(c.name in DERIVED)]
 ids=Int[];sigmas=String[];shas=String[];luts=Vector{UInt8}[]
 # SQLite rows are cursors; copy every value while the row is current.
 for r in DBI.execute(db,"SELECT class_id,sigma_hash,lut_sha256,lut FROM classes ORDER BY class_id")
  push!(ids,r.class_id);push!(sigmas,r.sigma_hash);push!(shas,r.lut_sha256);push!(luts,Vector{UInt8}(r.lut))
 end
 n=length(ids);records=Vector{Vector{UInt8}}(undef,n);powtab=monomial_power_table(8,MODULUS)
 Threads.@threads for i in 1:n
  length(luts[i])==256 || error("class $(ids[i]): LUT is not 256 bytes")
  bytes2hex(SHA.sha256(luts[i]))==shas[i] || error("class $(ids[i]): lut_sha256 is not SHA-256(lut)")
  F=SBox{8}(luts[i]);sigma_hash(F)==sigmas[i] || error("class $(ids[i]): sigma_hash differs from VBF.sigma_hash")
  records[i]=encode_quadratic(F;modulus=MODULUS,verify=true,powtab)
  length(records[i])==RECORD || error("class $(ids[i]): unexpected record length")
 end
 path=joinpath(out,"classes.q37")
 open(path,"w") do io;foreach(r->write(io,r),records);end
 Dict("records"=>basename(path),"records_sha256"=>hashfile(path),"tsv"=>write_tsv(db,"classes",kept,joinpath(out,"classes.tsv")),
  "encoding"=>"quadratic-coeffs-v1","modulus"=>MODULUS,"record_bytes"=>RECORD,
  "derived"=>Dict("lut"=>"VBF.decode_quadratic_lut(record, 8, modulus)","lut_sha256"=>"SHA-256 of lut","sigma_hash"=>"VBF.sigma_hash(SBox{8}(lut))"))
end
function restore_classes(db,dir,entry,cols)
 kept=[c for c in cols if !(c.name in DERIVED)]
 extra=read_tsv(joinpath(dir,entry["classes"]["tsv"]),kept)
 bytes=read(joinpath(dir,entry["classes"]["records"]))
 length(bytes)==RECORD*length(extra)==RECORD*entry["rows"] || error("class records and rows differ")
 n=length(extra);luts=Vector{Vector{UInt8}}(undef,n);sigmas=Vector{String}(undef,n);powtab=monomial_power_table(8,MODULUS)
 Threads.@threads for i in 1:n
  luts[i]=UInt8.(decode_quadratic_lut(bytes[RECORD*(i-1)+1:RECORD*i],8,MODULUS;powtab))
  sigmas[i]=sigma_hash(SBox{8}(luts[i]))
 end
 position=Dict(c.name=>k for (k,c) in enumerate(kept))
 value(c,i)=c.name=="lut" ? luts[i] : c.name=="lut_sha256" ? bytes2hex(SHA.sha256(luts[i])) :
  c.name=="sigma_hash" ? sigmas[i] : extra[i][position[c.name]]
 insert_rows!(db,"classes",(Any[value(c,i) for c in cols] for i in 1:n),length(cols))
end
"""Write the historical representatives TSV exactly as the frozen input was written."""
function representatives(db,io)
 println(io,"sigma_hash\tlut_hex\tlut_sha256\tsource\tsource_member_idx\tsource_run")
 for r in DBI.execute(db,"SELECT $(join(REPRESENTATIVES,",")) FROM classes ORDER BY class_id")
  println(io,join((r.sigma_hash,bytes2hex(r.lut),r.lut_sha256,r.source,r.source_member_idx,r.source_run),'\t'))
 end
end
function export_dataset(source,out;representatives_tsv="")
 ispath(out) && error("output already exists: $out")
 db=SQL.DB("file:"*abspath(source)*"?mode=ro&immutable=1")
 try
  mkpath(out)
  schema=[Dict("type"=>String(r.type),"name"=>String(r.name),"sql"=>String(r.sql))
   for r in DBI.execute(db,"SELECT type,name,sql FROM sqlite_master WHERE sql IS NOT NULL ORDER BY rowid")]
  tables=Dict{String,Any}()
  for t in [s["name"] for s in schema if s["type"]=="table"]
   cols=columns(db,t)
   entry=Dict{String,Any}("rows"=>Int(scalar(db,"SELECT COUNT(*) FROM $(quoted(t))")),"digest"=>digest(db,t,cols),
    "columns"=>[Dict("name"=>c.name,"type"=>c.type,"pk"=>c.pk) for c in cols])
   t=="classes" ? (entry["classes"]=export_classes(db,cols,out)) : (entry["file"]=write_tsv(db,t,cols,joinpath(out,t*".tsv")))
   tables[t]=entry
  end
  regenerates=Dict{String,String}()
  if !isempty(representatives_tsv)
   io=IOBuffer();representatives(db,io)
   bytes2hex(SHA.sha256(take!(io)))==hashfile(representatives_tsv) || error("classes do not regenerate $(representatives_tsv) byte for byte")
   regenerates[basename(representatives_tsv)]=hashfile(representatives_tsv)
  end
  manifest=Dict("format"=>FORMAT,"created_utc"=>string(now(UTC))*"Z","exporter_sha256"=>hashfile(@__FILE__),
   "julia"=>string(VERSION),"source"=>Dict("file"=>basename(source),"bytes"=>filesize(source),"sha256"=>hashfile(source)),
   "schema"=>schema,"tables"=>tables,"regenerates"=>regenerates)
  open(io->J.pretty(io,J.write(manifest)),joinpath(out,"manifest.json"),"w")
  manifest
 finally
  close(db)
 end
end
function restore_dataset(dir,dest)
 manifest=J.read(read(joinpath(dir,"manifest.json"),String),Dict{String,Any})
 manifest["format"]==FORMAT || error("unsupported compact format")
 ispath(dest) && error("output already exists: $dest")
 db=SQL.DB(dest)
 try
  SQL.execute(db,"PRAGMA journal_mode=DELETE")
  foreach(s->SQL.execute(db,s["sql"]),manifest["schema"])
  SQL.transaction(db) do
   for (t,entry) in manifest["tables"]
    cols=[(name=String(c["name"]),type=String(c["type"]),pk=Int(c["pk"])) for c in entry["columns"]]
    cols==columns(db,t) || error("restored schema of $t differs")
    t=="classes" ? restore_classes(db,dir,entry,cols) : insert_rows!(db,t,read_tsv(joinpath(dir,entry["file"]),cols),length(cols))
   end
  end
  for (t,entry) in manifest["tables"]
   scalar(db,"SELECT COUNT(*) FROM $(quoted(t))")==entry["rows"] || error("restored row count of $t differs")
   digest(db,t,columns(db,t))==entry["digest"] || error("restored table $t differs from the export")
  end
  isempty(collect(DBI.execute(db,"PRAGMA foreign_key_check"))) || error("restored foreign keys are inconsistent")
  for (name,sha) in manifest["regenerates"]
   path=joinpath(dirname(abspath(dest)),name);ispath(path) && error("output already exists: $path")
   open(io->representatives(db,io),path,"w");hashfile(path)==sha || error("regenerated $name differs")
  end
  Dict("path"=>abspath(dest),"tables"=>Dict(t=>e["rows"] for (t,e) in manifest["tables"]),"regenerated"=>collect(keys(manifest["regenerates"])))
 finally
  close(db)
 end
end
function main(args)
 if length(args) in (3,4) && args[1]=="export"
  m=export_dataset(args[2],args[3];representatives_tsv=length(args)==4 ? args[4] : "")
  println(J.write(Dict(t=>e["rows"] for (t,e) in m["tables"])))
 elseif length(args)==3 && args[1]=="restore"
  println(J.write(restore_dataset(args[2],args[3])))
 else
  error("usage: compact.jl export FREEZE.sqlite DIR [REPRESENTATIVES.tsv] | compact.jl restore DIR NEW.sqlite")
 end
end
end
abspath(PROGRAM_FILE)==(@__FILE__) && APNDatasetCompact.main(ARGS)
