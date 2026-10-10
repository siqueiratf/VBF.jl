using Test, VBF, VBFCatalog, SHA, TOML
import SQLite, DBInterface
include(joinpath(@__DIR__, "..", "reuse_verified_corpus.jl"))

@testset "verified corpus reuse binds originals, store and audit evidence" begin
    mktempdir() do dir
        source = joinpath(dir, "original.txt")
        write(source, "first\nsecond\n")
        @test _source_digest_and_records(source) == (bytes2hex(open(SHA.sha256, source)), 2)
        write(source, "first\nsecond")
        @test _source_digest_and_records(source)[2] == 2
        store_path = joinpath(dir, "store.sqlite")
        store = SQLite.DB(store_path)
        DBInterface.execute(store, "CREATE TABLE members(idx INTEGER PRIMARY KEY, coeffs BLOB NOT NULL)")
        for i in 1:2
            DBInterface.execute(store, "INSERT INTO members VALUES(?,?)", (i, zeros(UInt8,37)))
        end
        SQLite.close(store)
        previous_path = joinpath(dir, "previous.sqlite")
        previous = create_catalog(previous_path)
        digest = bytes2hex(open(SHA.sha256, store_path))
        register_corpus!(previous; name="fixture", n=8,m=8,member_count=2,degree=2,
            modulus=0x11d,encoding="quadratic-coeffs-v1",bytes_per_member=37,
            store_file="corpora/fixture.sqlite",store_sha256=digest,family="fixture",
            bib_key=nothing,source_repo="fixture",contributor="fixture",added_date="fixture",notes="original")
        close(previous)
        target = create_catalog(joinpath(dir, "target.sqlite"))
        raw = Dict("complete"=>true,"excluded_records"=>0,"records"=>2,"expected_records"=>2,
            "quadratic_apn_records"=>2,"code_sha256"=>"verified-code", "source"=>"raw_fixture",
            "input_sha256"=>Dict(source=>bytes2hex(open(SHA.sha256,source))))
        stored = merge(copy(raw), Dict("source"=>"stored_fixture","input_sha256"=>Dict(store_path=>digest)))
        evidence = Dict("records"=>2,"raw_records_absent_from_store_luts"=>0,
            "stored_records_absent_from_raw_luts"=>0,"raw_signatures_absent_from_store"=>0,
            "stored_signatures_absent_from_raw"=>0,"excluded_records"=>0)
        comparison = Dict("scope"=>"quadratic (8,8)-APN", "provenance_complete"=>true,"stored_original_lut_sets_match"=>true,
            "stored_original_signature_sets_match"=>true,"sources"=>Dict("raw_fixture"=>evidence))
        write_audits() = for (name,data) in (("raw_fixture",raw),("stored_fixture",stored),("comparison",comparison))
            open(joinpath(dir,name*".toml"),"w") do io
                TOML.print(io,data)
            end
        end
        write_audits()
        reuse() = reuse_verified_corpus!(target,previous_path,"fixture",source,dir;store_path)
        try
            reuse()
            @test corpus_length(target,"fixture") == 2
            @test corpus_info(target,"fixture").store_sha256 == digest
            @test occursin("Verified-store reuse:", corpus_info(target,"fixture").notes)
            notes = corpus_info(target,"fixture").notes
            previous = SQLite.DB(previous_path)
            DBInterface.execute(previous,"UPDATE bulk_corpora SET notes=?",(notes,))
            close(previous)
            reuse()
            @test corpus_info(target,"fixture").notes == notes
            write(source,"changed\nsecond")
            @test_throws ErrorException reuse()
            write(source,"first\nsecond")
            raw["complete"] = false
            write_audits()
            @test_throws ErrorException reuse()
            raw["complete"] = true
            evidence["raw_records_absent_from_store_luts"] = 1
            write_audits()
            @test_throws ErrorException reuse()
            evidence["raw_records_absent_from_store_luts"] = 0
            write_audits()
            write(store_path*"-wal", "unbound")
            @test_throws ErrorException reuse()
            rm(store_path*"-wal")
            store = SQLite.DB(store_path)
            DBInterface.execute(store,"UPDATE members SET coeffs=? WHERE idx=1",(zeros(UInt8,36),))
            close(store)
            @test_throws ErrorException reuse() # changed content digest
            # Even resealed metadata cannot conceal an invalid encoding size.
            digest = bytes2hex(open(SHA.sha256,store_path))
            previous = SQLite.DB(previous_path)
            DBInterface.execute(previous,"UPDATE bulk_corpora SET store_sha256=?",(digest,))
            close(previous)
            stored["input_sha256"] = Dict(store_path=>digest)
            write_audits()
            @test_throws ErrorException reuse()
        finally
            close(target)
        end
    end
end
