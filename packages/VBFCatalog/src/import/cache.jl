# Import receipts avoid reprocessing unchanged originals during a catalog rebuild.
# This reuses VBF-produced data; it does not provide another verification engine.
import SHA, TOML

_receipt_path() = joinpath(catalog_data_dir(), "imports.toml")
_import_code_hash() = bytes2hex(SHA.sha256(join(vcat(
    [bytes2hex(open(SHA.sha256, joinpath(dir,f)))
     for (dir,_,files) in walkdir(joinpath(pkgdir(VBF), "src"))
     for f in sort(files) if endswith(f,".jl")],
    [bytes2hex(open(SHA.sha256,joinpath(@__DIR__,"convert_beierle2025.jl")))]), "\n")))

function record_import!(db, name, source_path)
    info = corpus_info(db, name)
    data = isfile(_receipt_path()) ? TOML.parsefile(_receipt_path()) : Dict{String,Any}()
    data[name] = Dict("source_sha256"=>bytes2hex(open(SHA.sha256, source_path)),
        "members_sha256"=>corpus_digest(db, name), "count"=>info.member_count,
        "encoding"=>info.encoding, "bytes_per_member"=>info.bytes_per_member,
        "n"=>info.n,"m"=>info.m,"degree"=>info.degree,"modulus"=>info.modulus,
        "vbf_source_sha256"=>_import_code_hash())
    mkpath(dirname(_receipt_path()))
    tmp = _receipt_path() * ".partial"
    open(io -> TOML.print(io, data; sorted=true), tmp, "w")
    mv(tmp, _receipt_path(); force=true)
    nothing
end

function cached_corpus!(target, previous_path, name, source_path)
    isfile(_receipt_path()) && isfile(source_path) && isfile(previous_path) || return false
    receipts = TOML.parsefile(_receipt_path())
    haskey(receipts, name) || return false
    receipt = receipts[name]
    receipt["vbf_source_sha256"] == _import_code_hash() || return false
    previous = load_catalog(previous_path)
    try
        info = corpus_info(previous, name)
        info === nothing && return false
        isfile(corpus_store_path(previous, name)) || return false
        receipt["source_sha256"] == bytes2hex(open(SHA.sha256, source_path)) || error("cached import original changed; use BFA_REIMPORT=1")
        receipt["members_sha256"] == info.store_sha256 == corpus_digest(previous, name) || error("cached corpus bytes changed")
        receipt["count"] == info.member_count && receipt["encoding"] == info.encoding &&
            receipt["bytes_per_member"] == info.bytes_per_member || error("cached corpus descriptor changed")
        all(key->get(receipt,key,nothing)==getproperty(info,Symbol(key)),("n","m","degree","modulus")) ||
            error("cached corpus representation changed")
        count = 0
        with_corpus_rows(previous, name) do rows
            for row in rows
                count += 1
                row.idx == count && length(row.coeffs) == info.bytes_per_member || error("cached corpus index/width mismatch")
            end
        end
        count == info.member_count || error("cached corpus count mismatch")
        # External bytes stay in place; only the authoritative descriptor is copied.
        info.store_file == "members.sqlite" || error("cached import requires the external bulk store")
        fields = (; (k => (ismissing(getproperty(info,k)) ? nothing : getproperty(info,k))
            for k in propertynames(info) if k != :id)...)
        register_corpus!(target; fields...)
        @info "Reused unchanged import" name count
        true
    finally
        close(previous)
    end
end
