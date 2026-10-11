import SHA, TOML

_receipt_path() = joinpath(catalog_data_dir(), "imports.toml")

"""Reuse verified external members independently of any previous catalog."""
function _import_code_hash()
    paths=sort!([joinpath(dir,file) for (dir,_,files) in walkdir(joinpath(pkgdir(VBF),"src"))
        for file in files if endswith(file,".jl")])
    append!(paths,[joinpath(@__DIR__,file) for file in ("convert_beierle2025.jl","readers.jl")])
    bytes2hex(SHA.sha256(join([bytes2hex(open(SHA.sha256,path)) for path in paths],"\n")))
end

function record_import!(db,name,source_path)
    info=corpus_info(db,name)
    data=isfile(_receipt_path()) ? TOML.parsefile(_receipt_path()) : Dict{String,Any}()
    descriptor=Dict(string(key)=>value for (key,value) in pairs(info) if key!=:id && !ismissing(value))
    data[name]=Dict("source_sha256"=>bytes2hex(open(SHA.sha256,source_path)),
        "implementation_sha256"=>_import_code_hash(),"descriptor"=>descriptor)
    mkpath(dirname(_receipt_path()));partial=_receipt_path()*".partial"
    open(io->TOML.print(io,data;sorted=true),partial,"w")
    mv(partial,_receipt_path();force=true)
    nothing
end

function cached_corpus!(target,name,source_path;entry=nothing)
    isfile(_receipt_path()) && isfile(source_path) || return false
    receipt=get(TOML.parsefile(_receipt_path()),name,nothing)
    receipt===nothing && return false
    get(receipt,"implementation_sha256",nothing)==_import_code_hash() || return false
    receipt["source_sha256"]==bytes2hex(open(SHA.sha256,source_path)) || error("cached original changed")
    descriptor=receipt["descriptor"]
    descriptor["store_file"]=="members.sqlite" || error("cache must hold external members")
    descriptor["n"]==descriptor["m"]==8 && descriptor["degree"]==2 &&
        descriptor["modulus"]==conway_polynomial(8) && descriptor["bytes_per_member"]==37 &&
        descriptor["encoding"]=="quadratic-coeffs-v1" || error("cached encoding metadata changed")
    path=joinpath(catalog_data_dir(),"members.sqlite")
    isfile(path) || return false
    store=SQLite.DB("file:"*abspath(path)*"?mode=ro")
    ctx=SHA.SHA2_256_CTX();count=0
    try
        for row in DBInterface.execute(store,"SELECT idx,coeffs FROM corpus_members WHERE corpus=? ORDER BY idx",(name,))
            count+=1
            row.idx==count && length(row.coeffs)==descriptor["bytes_per_member"] || error("cached member index/width changed")
            SHA.update!(ctx,row.coeffs)
        end
    finally
        close(store)
    end
    count==descriptor["member_count"] && bytes2hex(SHA.digest!(ctx))==descriptor["store_sha256"] || error("cached packed members changed")
    fields=(; (Symbol(key)=>get(descriptor,key,nothing) for key in
        ("name","n","m","member_count","degree","modulus","encoding","bytes_per_member",
         "store_file","store_sha256","family","bib_key","source_repo","contributor","added_date","notes"))...)
    if entry===nothing
        register_corpus!(target;fields...)
    else
        store=(count=count,bytes_per_member=descriptor["bytes_per_member"],
            store_file="members.sqlite",sha256=descriptor["store_sha256"])
        VBFCatalog._register_declared_corpus!(target,entry,store;source_repo=descriptor["source_repo"])
    end
    @info "Reused verified external members" name count
    true
end
