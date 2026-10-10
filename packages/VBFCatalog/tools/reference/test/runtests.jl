using Test, Random
include("../rebuild.jl")
include("candidates.jl")
include("comparison.jl")
include("equivalence.jl")

@testset "independent signatures" begin
    rng = Xoshiro(901)
    w = Workspace()
    cat = readonly(VBFCatalog.catalog_path())
    try
        for name in VBFCatalog.list_corpora(cat)
            for i in unique([1, min(7, VBFCatalog.corpus_length(cat, name))])
                f = VBFCatalog.corpus_function(cat, name, i)
                lut = UInt8.(f.lut)
                @test bytes2hex(signature(w, lut)) == VBFCatalog.sigma_hash(f)
                @test differential_uniformity(f) == 2
                @test algebraic_degree(f) == 2
                @test w.ortho == UInt8.(ortho_derivative(f).lut)
                shifted = UInt8[lut[(x⊻0x53)+1] ⊻ UInt8(x) ⊻ 0xac for x in 0:255]
                @test signature(w, shifted) == signature(w, lut)
            end
        end
    finally
        close(cat)
    end
    @test_throws ErrorException signature(w, UInt8.(0:255))
    @test_throws ErrorException signature(w, rand(rng, UInt8, 256))
    @test_throws ErrorException signature(w, UInt8[x & 3 == 3 ? 1 : 0 for x in 0:255])
end

@testset "literal parser" begin
    mktempdir() do dir
        path = joinpath(dir, "luts.py")
        open(io -> println(io, "all_funcs = [[", join(["0x" * string(i; base=16) for i in 0:255], ','), "]],"), path, "w")
        @test only(literal_luts(path)) == UInt8.(0:255)
        f = SBox{8}(polynomial_to_lut("X^3", 8, conway_polynomial(8)))
        open(path, "w") do io
            println(io, "[", join(f.lut, ','), "]")
            println(io, "[", join(0:255, ','), "]")
        end
        desc = (; name="mixed_fixture", kind=:literals, paths=[path], expected=0,
                corpus="fixture", modulus=0, url="fixture", descriptor_sha="")
        rebuild(desc, dir)
        db = readonly(joinpath(dir, "mixed_fixture.sqlite"))
        try
            @test scalar(db, "SELECT COUNT(*) c FROM records") == 1
            @test scalar(db, "SELECT COUNT(*) c FROM excluded") == 1
            @test require_complete(db, "mixed fixture") === nothing
        finally
            close(db)
        end
    end
end

@testset "checkpoint and fail-closed coverage" begin
    mktempdir() do dir
        path = joinpath(dir, "input.txt")
        f = SBox{8}(polynomial_to_lut("X^3", 8, conway_polynomial(8)))
        open(path, "w") do io
            for _ in 1:3
                println(io, "[", join(f.lut, ','), "]")
            end
        end
        desc = (; name="fixture", kind=:stream, paths=[path], expected=3,
                corpus="fixture", modulus=0, url="fixture", descriptor_sha="")
        rebuild(desc, dir; batch=2)
        db = readonly(joinpath(dir, "fixture.sqlite"))
        try
            @test scalar(db, "SELECT COUNT(*) c FROM records") == 3
            @test scalar(db, "SELECT COUNT(DISTINCT sigma_hash) c FROM records") == 1
            @test require_complete(db, "fixture") === nothing
        finally
            close(db)
        end
        rebuild(desc, dir; batch=2)
        db = SQL.DB(joinpath(dir, "fixture.sqlite"))
        try
            SQL.execute(db, "DELETE FROM records WHERE member_idx=3")
            SQL.execute(db, "UPDATE metadata SET value='false' WHERE key='complete'")
        finally
            close(db)
        end
        rebuild(desc, dir; batch=2)
        db = readonly(joinpath(dir, "fixture.sqlite"))
        try
            @test scalar(db, "SELECT COUNT(*) c FROM records") == 3
            @test require_complete(db, "fixture") === nothing
        finally
            close(db)
        end
        open(io -> println(io, "[]"), path, "a")
        @test_throws ErrorException rebuild(desc, dir; batch=2)
    end
    mktempdir() do dir
        source = joinpath(dir, "fixture.sqlite")
        db = SQL.DB(source)
        try
            SQL.execute(db, "CREATE TABLE members(idx INTEGER PRIMARY KEY, coeffs BLOB)")
            f = SBox{8}(polynomial_to_lut("X^3", 8, conway_polynomial(8)))
            for i in 1:3
                DBI.execute(db, "INSERT INTO members VALUES(?,?)", (i, encode_quadratic(f)))
            end
        finally
            close(db)
        end
        desc = (; name="limited", kind=:store, paths=[source], expected=3,
                corpus="fixture", modulus=conway_polynomial(8), url="fixture", descriptor_sha="")
        rebuild(desc, dir; limit=1, batch=2)
        db = readonly(joinpath(dir, "limited.sqlite"))
        try
            @test scalar(db, "SELECT COUNT(*) c FROM records") == 1
            @test_throws ErrorException require_complete(db, "fixture")
        finally
            close(db)
        end
        @test_throws ErrorException rebuild(desc, dir; limit=0, batch=2)
    end
end

@testset "raw readers reject lossy decoding" begin
    lut=zeros(UInt8,256)
    @test RawReaders.parse_ints!(lut,"TT= "*join(0:255," "))==256
    @test RawReaders.parse_ints!(lut,"TT= -1 "*join(1:255," "))==-1
    @test RawReaders.parse_ints!(lut,"TT= 256 "*join(1:255," "))==-1
    @test RawReaders.parse_ints!(lut,"TT= "*join([collect(0:255);0]," "))==257
    @test_throws ArgumentError RawReaders.lut_from_masks!(lut,ntuple(_->UInt64(1)<<28,8))
    historical=joinpath(REPO,"census/quadratic_apn8/new_classes_553.tsv")
    @test isfile(artifact_path(historical))
    @test filehash(historical)==filehash(artifact_path(historical))
end

@testset "original source stream formats" begin
    mktempdir() do dir
        gold=gold_apn(8).lut
        C=VBF.QuadraticAPNTree.coeff_matrix_from_lut(gold)
        masks=ntuple(k->sum((UInt64((C[i+1,j+1]>>(k-1))&1)<<(t-1) for (t,(i,j)) in enumerate(RawReaders.COLEX));init=UInt64(0)),8)
        homogeneous=UInt8.(VBF.QuadraticAPNTree.lut(C,8))
        binary=joinpath(dir,"fixture.out")
        open(binary,"w") do io
            write(io,htol.(collect(masks)))
            write(io,htol.(collect(masks)))
            write(io,UInt8[1,2])
        end
        batches(path;skip=0,limit=0)=collect(Channel{RawReaders.Batch}(2) do ch
            RawReaders.produce!(ch,path,RawReaders.fmt_of(path),skip,limit,1)
        end)
        rows=batches(binary)
        @test reduce(vcat,(b.ok for b in rows))==[true,true,false]
        @test rows[1].luts[1]==homogeneous
        @test length(reduce(vcat,(b.ids for b in batches(binary;skip=1,limit=2))))==1
        text=joinpath(dir,"fixture.txt")
        write(text,"TT= "*join(gold," ")*"\nTT= -1 "*join(gold[2:end]," ")*"\n")
        @test reduce(vcat,(b.ok for b in batches(text)))==[true,false]
        @test batches(text)[1].luts[1]==gold
        compressed=text*".gz"
        open(compressed,"w") do io
            run(pipeline(`gzip -c $text`;stdout=io))
        end
        @test reduce(vcat,(b.ok for b in batches(compressed)))==[true,false]
        member=joinpath(dir,"fixture with spaces.sage")
        write(member,"["*join(Int.(gold),",")*"],\n")
        archive=joinpath(dir,"fixture.tar")
        run(`tar -cf $archive -C $dir $(basename(member))`)
        rows=batches(archive)
        @test only(reduce(vcat,(b.ok for b in rows)))
        @test only(reduce(vcat,(b.luts for b in rows)))==gold
    end
end
