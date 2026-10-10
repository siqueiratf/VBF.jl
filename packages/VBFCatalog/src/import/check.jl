using VBFCatalog, TOML, SHA, SQLite, DBInterface

"""Check declarative entries, bibliography, family counts and bundled records.

This checks catalog/source agreement. Mathematical properties are covered by
package tests, using VBF's implementations.
"""
function check_catalog(path=catalog_path(); entries=VBFCatalog.catalog_source_dir())
    errors=String[]
    declared=Dict("APN"=>Dict{String,Any}(), "Literature"=>Dict{String,Any}())
    for file in sort(readdir(joinpath(entries,"apn");join=true))
        endswith(file,".toml") || continue
        for entry in get(TOML.parsefile(file),"apn_functions",[])
            name=entry["name"]
            haskey(declared["APN"],name) && push!(errors,"duplicate APN name $name")
            declared["APN"][name]=entry
        end
    end
    for entry in TOML.parsefile(joinpath(entries,"literature_sboxes.toml"))["sboxes"]
        haskey(declared["Literature"],entry["name"]) && push!(errors,"duplicate literature name $(entry["name"])")
        declared["Literature"][entry["name"]]=entry
    end
    db=load_catalog(path)
    try
        rows=Dict{String,Dict{String,Any}}()
        for row in DBInterface.execute(db,"SELECT * FROM functions")
            get!(rows,String(row.family),Dict{String,Any}())[String(row.canonical_name)]=VBFCatalog._row_namedtuple(row)
        end
        bib=Set(String(row.bib_key) for row in DBInterface.execute(db,"SELECT bib_key FROM bibliography"))
        for entry in TOML.parsefile(joinpath(entries,"sporadic.toml"))["functions"]
            name=entry["canonical_name"]
            row=get(get(rows,"known-sporadic",Dict{String,Any}()),name,nothing)
            row===nothing && (push!(errors,"missing sporadic entry $name");continue)
            bytes=canonical_lut_bytes(VBFCatalog.VBF.SBox{entry["n"]}(entry["lut"]))
            bytes==row.lut_blob && row.bib_key==entry["bib_key"] || push!(errors,"$name: sporadic source disagrees")
        end
        for (family,source) in declared
            have=get(rows,family,Dict{String,Any}())
            Set(keys(source))==Set(keys(have)) || push!(errors,"$family names disagree with entries")
            for name in intersect(keys(source),keys(have))
                entry=source[name];row=have[name]
                for key in ("n","m","is_permutation","bib_key")
                    haskey(entry,key) || continue
                    entry[key]==getproperty(row,Symbol(key)) || push!(errors,"$name: $key disagrees")
                end
                haskey(entry,"bib_key") && !(entry["bib_key"] in bib) && push!(errors,"$name: missing bibliography entry")
                family=="APN" && row.is_apn!=1 && push!(errors,"$name: is_apn is false")
                if haskey(entry,"lut")
                    bytes=canonical_lut_bytes(VBFCatalog.VBF.SBox(entry["lut"]))
                    bytes==row.lut_blob && bytes2hex(SHA.sha256(bytes))==row.lut_sha256 || push!(errors,"$name: LUT bytes/hash disagree")
                end
            end
        end
        test_source=read(joinpath(@__DIR__,"..","..","test","unit","catalog_queries_test.jl"),String)
        for family in keys(rows)
            occursin('"'*family*'"',test_source) || push!(errors,"family $family is absent from catalog_queries_test totals")
        end
        importer=[row for family in ("APN-rep","CCZ-rep-GF4","known-family","known-sporadic") for row in values(get(rows,family,Dict{String,Any}()))]
        all_entries=vcat(collect(values(declared["APN"])),collect(values(declared["Literature"])))
        scalar(sql)=only(Int(row.c) for row in DBInterface.execute(db,sql))
        for n in (4,8)
            count(e->e["n"]==n,all_entries)+count(r->r.n==n,importer)==scalar("SELECT COUNT(*) c FROM functions WHERE n=$n") || push!(errors,"n=$n count mismatch")
        end
        length(all_entries)+length(importer)==scalar("SELECT COUNT(*) c FROM functions") || push!(errors,"total function count mismatch")
        length(declared["APN"])+length(importer)==scalar("SELECT COUNT(*) c FROM functions WHERE is_apn=1") || push!(errors,"APN count mismatch")
        length(declared["Literature"])==scalar("SELECT COUNT(*) c FROM functions WHERE is_apn=0") || push!(errors,"non-APN count mismatch")
        count(e->get(e,"is_permutation",false),all_entries)+count(r->r.is_permutation==1,importer)==scalar("SELECT COUNT(*) c FROM functions WHERE is_permutation=1") || push!(errors,"permutation count mismatch")
        for name in list_corpora(db)
            info=corpus_info(db,name)
            info.store_file=="catalog" || continue
            count=0
            with_corpus_rows(db,name) do members
                for row in members
                    count+=1
                    row.idx==count && length(row.coeffs)==info.bytes_per_member || push!(errors,"$name: index/record width mismatch")
                end
            end
            count==info.member_count || push!(errors,"$name: member count mismatch")
            corpus_digest(db,name)==info.store_sha256 || push!(errors,"$name: member digest mismatch")
        end
    finally
        close(db)
    end
    isempty(errors) || error(join(errors,"\n")*"\nRebuild: make -C packages/VBFCatalog/src/import catalog")
    println("catalog structure: OK")
    nothing
end
abspath(PROGRAM_FILE)==(@__FILE__) && check_catalog(isempty(ARGS) ? catalog_path() : only(ARGS))
