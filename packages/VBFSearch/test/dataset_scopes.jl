module APNDatasetScopeTests
using Test,SHA,TOML,VBF,VBFSearch
include(joinpath(@__DIR__,"..","tools","datasets","freeze.jl"))
include(joinpath(@__DIR__,"..","tools","datasets","verify_comparisons.jl"))
include(joinpath(@__DIR__,"..","tools","datasets","prepare_comparisons.jl"))
include(joinpath(@__DIR__,"..","tools","datasets","compact.jl"))
const SQL=VBFSearch.SQLite;const DBI=VBFSearch.DBInterface
function compact_fixture(path;sigma=nothing)
 db=SQL.DB(path)
 SQL.execute(db,"CREATE TABLE metadata(key TEXT PRIMARY KEY,value TEXT NOT NULL) WITHOUT ROWID")
 SQL.execute(db,"CREATE TABLE classes(class_id INTEGER PRIMARY KEY,sigma_hash TEXT NOT NULL,lut_sha256 TEXT NOT NULL,lut BLOB NOT NULL,source TEXT NOT NULL,source_member_idx INTEGER NOT NULL,source_run TEXT NOT NULL)")
 SQL.execute(db,"CREATE TABLE source_artifacts(name TEXT PRIMARY KEY,sha256 TEXT NOT NULL,bytes BLOB NOT NULL) WITHOUT ROWID")
 SQL.execute(db,"CREATE TABLE links(class_id INTEGER NOT NULL REFERENCES classes(class_id),n INTEGER NOT NULL,PRIMARY KEY(class_id,n)) WITHOUT ROWID")
 DBI.execute(db,"INSERT INTO metadata VALUES(?,?)",("note","tab\there\nline\\end"))
 G=UInt8.(gold_apn(8).lut)
 # Constant and linear parts survive the 37-byte record, not only the quadratic part.
 for (id,f) in ((3,G),(7,G .⊻ 0x05),(11,G .⊻ UInt8.(0:255)))
  s=something(sigma,VBF.sigma_hash(SBox{8}(f)))
  DBI.execute(db,"INSERT INTO classes VALUES(?,?,?,?,?,?,?)",(id,s,bytes2hex(SHA.sha256(f)),f,"fixture",id,"run-$id"))
  DBI.execute(db,"INSERT INTO links VALUES(?,?)",(id,2id))
 end
 DBI.execute(db,"INSERT INTO source_artifacts VALUES(?,?,?)",("raw.bin",bytes2hex(SHA.sha256(UInt8[0,9,10,13])),UInt8[0,9,10,13]))
 close(db)
end
rows(path,t)=(db=SQL.DB("file:$path?mode=ro");try [Tuple(r) for r in DBI.execute(db,"SELECT * FROM $t ORDER BY 1,2")] finally close(db) end)
@testset "Direct-root freeze excludes recursive outputs and retains both constructions" begin
 mktempdir() do dir
  run=joinpath(dir,"run");mkpath(run);write(joinpath(run,"identity.toml"),"fixture = true\n")
  open(io->TOML.print(io,Dict("running"=>false,"initial_roots"=>1,"seed_progress"=>Dict("completed"=>1))),joinpath(run,"progress.toml"),"w")
  db=SQL.DB(joinpath(run,"closure.sqlite"))
  SQL.execute(db,"CREATE TABLE parents(id INTEGER PRIMARY KEY,candidate_id TEXT,sigma TEXT,origin TEXT,source TEXT)")
  SQL.execute(db,"CREATE TABLE candidates(id TEXT PRIMARY KEY,lut_hex TEXT,class_id INTEGER,apn INTEGER,degree INTEGER)")
  SQL.execute(db,"CREATE TABLE paths(id INTEGER PRIMARY KEY,parent_id INTEGER,child_id TEXT,method TEXT)")
  # Minimal transport fixture; the scope operation consumes already-classified rows.
  for (id,origin) in ((1,"root"),(2,"discovered"),(3,"discovered"))
   f=UInt8.(mod.(collect(0:255).+id,256));sha=bytes2hex(SHA.sha256(f))
   DBI.execute(db,"INSERT INTO parents VALUES(?,?,?,?,?)",(id,sha,"fixture-sigma-$id",origin,"fixture:$id"))
   DBI.execute(db,"INSERT INTO candidates VALUES(?,?,?,1,2)",(sha,bytes2hex(f),id))
  end
  ids=Dict(Int(r.id)=>String(r.candidate_id) for r in DBI.execute(db,"SELECT id,candidate_id FROM parents"))
  DBI.execute(db,"INSERT INTO paths VALUES(1,1,?,'v5')",(ids[2],));DBI.execute(db,"INSERT INTO paths VALUES(2,1,?,'switching')",(ids[1],));DBI.execute(db,"INSERT INTO paths VALUES(3,2,?,'v5')",(ids[3],))
  DBI.execute(db,"INSERT INTO paths VALUES(4,1,?,'other_method')",(ids[3],))
  close(db)
  dest=joinpath(dir,"direct.sqlite");result=APNDatasetFreeze.roots(run,dest);frozen=SQL.DB(dest)
  @test result["counts"]["direct_output_classes"]==2
  @test [r.class_id for r in DBI.execute(frozen,"SELECT class_id FROM classes ORDER BY class_id")]==[1,2]
  @test [r.name for r in DBI.execute(frozen,"SELECT name FROM methods ORDER BY method_id")]==["v5","switching"]
  @test APNDatasetFreeze.scalar(frozen,"SELECT COUNT(*) FROM derivations")==2
  @test isempty(collect(DBI.execute(frozen,"PRAGMA foreign_key_check")))
  close(frozen)
  db=SQL.DB(joinpath(run,"closure.sqlite"));pending=UInt8.(mod.(collect(0:255).+4,256));sha=bytes2hex(SHA.sha256(pending));DBI.execute(db,"INSERT INTO candidates VALUES(?,?,NULL,1,2)",(sha,bytes2hex(pending)));DBI.execute(db,"INSERT INTO paths VALUES(5,1,?,'v5')",(sha,));close(db)
  @test_throws ErrorException APNDatasetFreeze.roots(run,joinpath(dir,"pending.sqlite"))
 end
end
@testset "Compact export restores every table and rejects changed data" begin
 mktempdir() do dir
  source=joinpath(dir,"frozen.sqlite");compact_fixture(source)
  tsv=joinpath(dir,"representatives.tsv")
  db=SQL.DB("file:$source?mode=ro");open(io->APNDatasetCompact.representatives(db,io),tsv,"w");close(db)
  out=joinpath(dir,"compact");manifest=APNDatasetCompact.export_dataset(source,out;representatives_tsv=tsv)
  @test Set(keys(manifest["tables"]))==Set(["metadata","classes","source_artifacts","links"])
  @test filesize(joinpath(out,"classes.q37"))==3*37
  @test !occursin("lut_sha256",readline(joinpath(out,"classes.tsv")))
  restored=joinpath(dir,"restored","frozen.sqlite");mkpath(dirname(restored))
  result=APNDatasetCompact.restore_dataset(out,restored)
  @test result["tables"]["classes"]==3
  for t in ("metadata","classes","source_artifacts","links")
   @test rows(restored,t)==rows(source,t)
  end
  @test read(joinpath(dirname(restored),"representatives.tsv"))==read(tsv)
  @test_throws ErrorException APNDatasetCompact.export_dataset(source,out)
  # One changed coefficient yields another quadratic LUT, so the table digest fails.
  bad=joinpath(dir,"bad");cp(out,bad);bytes=read(joinpath(bad,"classes.q37"));bytes[40]⊻=0x01;write(joinpath(bad,"classes.q37"),bytes)
  @test_throws Exception APNDatasetCompact.restore_dataset(bad,joinpath(dir,"bad.sqlite"))
  wrong=joinpath(dir,"wrong.sqlite");compact_fixture(wrong;sigma="0"^64)
  @test_throws Exception APNDatasetCompact.export_dataset(wrong,joinpath(dir,"wrong"))
 end
end
@testset "Cached positives require complete invertible EA graph replay" begin
 f=UInt8.(gold_apn(8).lut);columns=UInt16[1<<i for i in 0:15]
 proof=vcat(UInt8[1],collect(reinterpret(UInt8,htol.(vcat(columns,UInt16[0])))))
 result=APNDatasetVerification.verify_pair(f,f,proof)
 @test result[1]==1 && result[4]
 @test APNDatasetVerification.verify_pair(f,f,zeros(UInt8,35))[1]==1
 bad=copy(proof);bad[2]=0
 @test_throws ErrorException APNDatasetVerification.verify_pair(f,f,bad)
 g=copy(f);g[2]⊻=1
 @test_throws ErrorException APNDatasetVerification.verify_pair(f,g,proof)
end
@testset "Pair preparation uses the specified reference's member store" begin
 mktempdir() do dir
  reference=joinpath(dir,"published");out=joinpath(dir,"audit");mkpath(reference);mkpath(joinpath(out,"datasets"))
  F=gold_apn(8);f=UInt8.(F.lut);packed=VBF.encode_quadratic(F;modulus=285)
  cat=SQL.DB(joinpath(reference,"catalog.sqlite"));SQL.execute(cat,"CREATE TABLE bulk_corpora(name TEXT,modulus INTEGER,encoding TEXT,bytes_per_member INTEGER,store_file TEXT)");SQL.execute(cat,"INSERT INTO bulk_corpora VALUES('published_fixture',285,'quadratic-coeffs-v1',37,'members.sqlite')");close(cat)
  members=SQL.DB(joinpath(reference,"members.sqlite"));SQL.execute(members,"CREATE TABLE corpus_members(corpus TEXT,idx INTEGER,coeffs BLOB)");DBI.execute(members,"INSERT INTO corpus_members VALUES('published_fixture',1,?)",(packed,));close(members)
  roots=SQL.DB(joinpath(out,"datasets/published-roots-24294.sqlite"));SQL.execute(roots,"CREATE TABLE classes(class_id INTEGER,lut BLOB)");DBI.execute(roots,"INSERT INTO classes VALUES(1,?)",(f,));close(roots)
  old=SQL.DB(joinpath(out,"datasets/historical-190454.sqlite"));SQL.execute(old,"CREATE TABLE classes(class_id INTEGER,lut BLOB)");close(old)
  plan=SQL.DB(joinpath(out,"comparisons.sqlite"));SQL.execute(plan,"CREATE TABLE literature(pair_id INTEGER,class_id INTEGER,target_source TEXT,target_member_idx INTEGER,cached_proof BLOB)");SQL.execute(plan,"INSERT INTO literature VALUES(1,1,'published_fixture',1,NULL)");SQL.execute(plan,"CREATE TABLE historical(pair_id INTEGER,class_id INTEGER,historical_class_id INTEGER,cached_proof BLOB)");close(plan)
  withenv("BFA_DATA_DIR"=>joinpath(dir,"wrong-member-store")) do
   APNComparisonPairs.main(out,reference)
  end
  bytes=read(joinpath(out,"literature/pairs.bin"))
  @test length(bytes)==513 && bytes[1]==1
  @test bytes[2:257]==f && bytes[258:294]==packed
  @test read(joinpath(out,"literature/cached-proofs.bin"))==zeros(UInt8,35)
 end
end
end
