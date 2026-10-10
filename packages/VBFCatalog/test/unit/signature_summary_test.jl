@testitem "signature_summary" begin
using Test, VBFCatalog, SQLite
mktempdir() do dir
    path=joinpath(dir,"index.sqlite");db=SQLite.DB(path)
    SQLite.execute(db,"CREATE TABLE ccz_sigma_index(source TEXT,n INTEGER,sigma_hash TEXT)")
    SQLite.execute(db,"INSERT INTO ccz_sigma_index VALUES ('a',8,'x'),('a',8,'x'),('a',8,'y'),('b',8,'y'),('b',8,'z'),('a',9,'y')")
    close(db);before=read(path)
    summary=signature_summary(;path)
    a=only(filter(r->r.source=="a" && r.n==8,summary.sources))
    @test a.indexed_rows==3 && a.distinct_signatures==2
    @test a.unique_signatures==1 && a.shared_signatures==1
    @test only(summary.overlaps).shared_signatures==1
    @test only(filter(r->r.n==8,summary.dimensions)).distinct_signatures==3
    @test signature_count(;path,n=8,sources=["a","b"])==3
    @test signature_count(;path,n=9,sources=["a","b"])==1
    @test signature_count(;path,n=8,sources=["absent"])==0
    @test signature_count(;path,n=8,sources=String[])==0
    @test read(path)==before
end
end
