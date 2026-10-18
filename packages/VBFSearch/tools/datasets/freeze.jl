"""Freeze historical discoveries and one complete expansion of published roots.

Experiment bundles remain VBFSearch evidence. They are never catalog inputs.
Run with the experiment's archived project: freeze.jl RUN HISTORICAL_TSV OUTPUT_DIR
[LEGACY_COEFFICIENTS_GZ]. Only direct V5/switching outputs of original roots enter
published-roots.sqlite; recursive discoveries remain in the campaign ledger.
"""
module APNDatasetFreeze
using VBFSearch,SHA,Dates,TOML
const SQL=VBFSearch.SQLite;const DBI=VBFSearch.DBInterface;const J=VBFSearch.JSON3
hashfile(path)=bytes2hex(open(SHA.sha256,path))
scalar(db,sql,args=())=only(first(Tuple(r)) for r in DBI.execute(db,sql,args))
function metadata!(db,key,value)
 DBI.execute(db,"INSERT OR REPLACE INTO metadata VALUES(?,?)",(key,J.write(value)))
end
function create(path,scope)
 ispath(path) && error("output already exists: $path")
 db=SQL.DB(path);SQL.execute(db,"PRAGMA foreign_keys=ON");SQL.execute(db,"PRAGMA journal_mode=DELETE")
 SQL.execute(db,"CREATE TABLE metadata(key TEXT PRIMARY KEY,value TEXT NOT NULL) WITHOUT ROWID")
 metadata!(db,"schema","vbfsearch-apn-dataset-v1");metadata!(db,"scope",scope)
 metadata!(db,"created_utc",string(now(UTC))*"Z");metadata!(db,"freezer_sha256",hashfile(@__FILE__))
 db
end
function historical(tsv,path;legacy="")
 db=create(path,"historical discoveries: 111009 earlier + 79445 later classes; excluded from published reference")
 try
  SQL.execute(db,"CREATE TABLE classes(class_id INTEGER PRIMARY KEY,sigma_hash TEXT NOT NULL UNIQUE,lut_sha256 TEXT NOT NULL UNIQUE,lut BLOB NOT NULL CHECK(length(lut)=256),source TEXT NOT NULL,source_member_idx INTEGER NOT NULL,source_run TEXT NOT NULL)")
  SQL.execute(db,"CREATE TABLE source_artifacts(name TEXT PRIMARY KEY,sha256 TEXT NOT NULL,bytes BLOB NOT NULL) WITHOUT ROWID")
  metadata!(db,"input_representatives",abspath(tsv));metadata!(db,"input_representatives_sha256",hashfile(tsv))
  counts=Dict{String,Int}();count=0
  stmt=DBI.prepare(db,"INSERT INTO classes VALUES(?,?,?,?,?,?,?)")
  SQL.transaction(db) do
   for line in Iterators.drop(eachline(tsv),1)
    c=split(line,'\t');length(c)==6 || error("invalid historical row");f=hex2bytes(c[2]);bytes2hex(SHA.sha256(f))==c[3] || error("historical LUT digest changed")
    count+=1;DBI.execute(stmt,(count,String(c[1]),String(c[3]),f,String(c[4]),parse(Int,c[5]),String(c[6])))
    counts[String(c[4])]=get(counts,String(c[4]),0)+1
   end
  end
  DBI.close!(stmt)
  if !isempty(legacy)
   DBI.execute(db,"INSERT INTO source_artifacts VALUES(?,?,?)",(basename(legacy),hashfile(legacy),read(legacy)))
  end
  metadata!(db,"classes",count);metadata!(db,"by_source",counts)
  metadata!(db,"mathematical_audit",joinpath(dirname(abspath(tsv)),"mathematical_audit.toml"))
  for name in ("freeze.json","mathematical_audit.toml","ledger_audit.json")
   p=joinpath(dirname(tsv),name);isfile(p) || continue
   DBI.execute(db,"INSERT INTO source_artifacts VALUES(?,?,?)",(name,hashfile(p),read(p)))
  end
  Dict("path"=>abspath(path),"classes"=>count,"by_source"=>counts)
 finally
  close(db)
 end
end
function roots(run,path)
 report=TOML.parsefile(joinpath(run,"progress.toml"))
 get(report,"running",true) && error("stop the campaign before freezing")
 get(report["seed_progress"],"completed",-1)==report["initial_roots"] || error("original root expansion is incomplete")
 db=create(path,"one complete direct expansion of published roots: V5 + switching; recursive expansion excluded")
 try
  DBI.execute(db,"ATTACH DATABASE ? AS campaign",("file:"*abspath(joinpath(run,"closure.sqlite"))*"?mode=ro",))
  SQL.execute(db,"CREATE TEMP TABLE output_ids(class_id INTEGER PRIMARY KEY)")
  SQL.execute(db,"INSERT INTO output_ids SELECT DISTINCT c.class_id FROM campaign.paths x JOIN campaign.parents p ON p.id=x.parent_id JOIN campaign.candidates c ON c.id=x.child_id WHERE p.origin='root' AND x.method IN ('v5','switching') AND c.apn=1 AND c.degree=2 AND c.class_id IS NOT NULL")
  pending=scalar(db,"SELECT COUNT(DISTINCT c.id) FROM campaign.paths x JOIN campaign.parents p ON p.id=x.parent_id JOIN campaign.candidates c ON c.id=x.child_id WHERE p.origin='root' AND x.method IN ('v5','switching') AND c.apn=1 AND c.degree=2 AND c.class_id IS NULL")
  pending==0 || error("$pending direct-root LUTs still await equivalence admission")
  SQL.execute(db,"CREATE TABLE classes(class_id INTEGER PRIMARY KEY,sigma_hash TEXT NOT NULL UNIQUE,lut_sha256 TEXT NOT NULL UNIQUE,lut BLOB NOT NULL CHECK(length(lut)=256),initial_seed INTEGER NOT NULL,observed_output INTEGER NOT NULL,source TEXT NOT NULL)")
  SQL.execute(db,"INSERT INTO classes SELECT p.id,p.sigma,p.candidate_id,unhex(c.lut_hex),p.origin='root',o.class_id IS NOT NULL,p.source FROM campaign.parents p JOIN campaign.candidates c ON c.id=p.candidate_id LEFT JOIN output_ids o ON o.class_id=p.id WHERE p.origin='root' OR o.class_id IS NOT NULL ORDER BY p.id")
  SQL.execute(db,"CREATE TABLE roots(root_index INTEGER PRIMARY KEY,class_id INTEGER NOT NULL REFERENCES classes(class_id),source TEXT NOT NULL)")
  SQL.execute(db,"INSERT INTO roots SELECT ROW_NUMBER() OVER(ORDER BY p.id),p.id,p.source FROM campaign.parents p WHERE p.origin='root' ORDER BY p.id")
  SQL.execute(db,"CREATE TABLE methods(method_id INTEGER PRIMARY KEY,name TEXT NOT NULL UNIQUE)")
  SQL.execute(db,"INSERT INTO methods VALUES(1,'v5'),(2,'switching')")
  SQL.execute(db,"CREATE TABLE derivations(root_index INTEGER NOT NULL REFERENCES roots(root_index),child_class_id INTEGER NOT NULL REFERENCES classes(class_id),method_id INTEGER NOT NULL REFERENCES methods(method_id),first_campaign_path_id INTEGER NOT NULL,derivation_count INTEGER NOT NULL,PRIMARY KEY(root_index,child_class_id,method_id)) WITHOUT ROWID")
  SQL.execute(db,"INSERT INTO derivations SELECT r.root_index,c.class_id,m.method_id,MIN(x.id),COUNT(*) FROM campaign.paths x JOIN roots r ON r.class_id=x.parent_id JOIN campaign.candidates c ON c.id=x.child_id JOIN methods m ON m.name=x.method WHERE c.class_id IS NOT NULL GROUP BY r.root_index,c.class_id,m.method_id")
  metadata!(db,"campaign",abspath(run));metadata!(db,"campaign_identity_sha256",hashfile(joinpath(run,"identity.toml")))
  metadata!(db,"stopped_progress_sha256",hashfile(joinpath(run,"progress.toml")))
  metadata!(db,"construction_evidence","Each first_campaign_path_id references an immutable direct construction witness in the retained campaign ledger. Admission equivalence witnesses remain in that ledger's comparisons table.")
  counts=Dict("seed_classes"=>Int(scalar(db,"SELECT COUNT(*) FROM roots")),"direct_output_classes"=>Int(scalar(db,"SELECT COUNT(*) FROM classes WHERE observed_output=1")),"classes_including_seeds"=>Int(scalar(db,"SELECT COUNT(*) FROM classes")),"new_classes_beyond_seeds"=>Int(scalar(db,"SELECT COUNT(*) FROM classes WHERE initial_seed=0")),"class_derivation_links"=>Int(scalar(db,"SELECT COUNT(*) FROM derivations")),"construction_paths"=>Int(scalar(db,"SELECT SUM(derivation_count) FROM derivations")),"unresolved_root_outputs"=>pending)
  metadata!(db,"counts",counts)
  SQL.execute(db,"DETACH DATABASE campaign")
  Dict("path"=>abspath(path),"counts"=>counts)
 finally
  close(db)
 end
end
function main(args)
 length(args) in (3,4) || error("usage: freeze.jl RUN HISTORICAL_TSV OUTPUT_DIR [LEGACY_COEFFICIENTS_GZ]")
 run,tsv,out=abspath.(args[1:3]);mkpath(out)
 results=Dict("historical"=>historical(tsv,joinpath(out,"historical-190454.sqlite");legacy=length(args)==4 ? args[4] : ""),"published_roots"=>roots(run,joinpath(out,"published-roots-24294.sqlite")))
 for value in values(results);value["sha256"]=hashfile(value["path"]);end
 open(io->J.write(io,results),joinpath(out,"datasets.json"),"w");println(J.write(results))
end
end
abspath(PROGRAM_FILE)==(@__FILE__) && APNDatasetFreeze.main(ARGS)
