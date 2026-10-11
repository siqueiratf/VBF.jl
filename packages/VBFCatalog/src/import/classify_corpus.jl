using VBFCatalog

"""Resume deduplication and equivalence classification of the indexed corpus."""
function main(args=ARGS)
    options=Dict("n"=>"8","seconds"=>"1","nodes"=>"1000000",
        "workers"=>string(Threads.nthreads()),"pairs"=>string(typemax(Int)),"algorithm"=>"optimized","rebuild"=>"false")
    iseven(length(args)) || error("expected --option value pairs")
    for i in 1:2:length(args)
        key=chopprefix(args[i],"--")
        haskey(options,key) || error("unknown option: $(args[i])")
        options[key]=args[i+1]
    end
    db=load_catalog()
    try
        options["rebuild"] in ("true","false") || error("--rebuild expects true or false")
        options["rebuild"]=="true" && deduplicate_signature_buckets!(db;n=parse(Int,options["n"]),rebuild=true)
        result=classify_signature_buckets!(db;n=parse(Int,options["n"]),
            timeout_seconds=parse(Float64,options["seconds"]),max_nodes=parse(Int,options["nodes"]),
            workers=parse(Int,options["workers"]),max_pairs=parse(Int,options["pairs"]),algorithm=Symbol(options["algorithm"]))
        println(result)
        flush(stdout)
        result
    finally
        close(db)
    end
end

abspath(PROGRAM_FILE)==(@__FILE__) && main()
