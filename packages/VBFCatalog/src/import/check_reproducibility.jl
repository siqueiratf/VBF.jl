using VBFCatalog, SHA

function main()
    mktempdir() do dir
        hashes=String[]
        for name in ("first", "second")
            path=joinpath(dir,name*".sqlite")
            run(`$(Base.julia_cmd()) --startup-file=no --project=$(@__DIR__) -t $(Threads.nthreads()) $(joinpath(@__DIR__,"build_catalog.jl")) --output $path`)
            push!(hashes,bytes2hex(open(SHA.sha256,path)))
        end
        hashes[1]==hashes[2] || error("catalog builds differ: $hashes")
        println("catalog reproducibility: OK (SHA-256 $(first(hashes)))")
    end
end
abspath(PROGRAM_FILE)==(@__FILE__) && main()
