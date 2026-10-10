@isdefined(_BIBIMPORT_LOADED) && return
const _BIBIMPORT_LOADED = true
using VBFCatalog
import SQLite, DBInterface

function _bibtex(entry)
    io=IOBuffer()
    print(io,"@",entry.entry_type,"{",entry.bib_key)
    for (key,value) in sort(collect(entry.fields);by=first)
        print(io,",\n    ",key," = {",value,"}")
    end
    print(io,"\n}")
    String(take!(io))
end

function insert_bibliography!(db; key=nothing)
    entries=load_bibliography()
    if key!==nothing
        entries=filter(e->e.bib_key==key,entries)
        isempty(entries) && error("bibliography key $key not found")
    end
    statement=DBInterface.prepare(db,"INSERT OR IGNORE INTO bibliography (bib_key,bibtex,doi,url,year,authors) VALUES(?,?,?,?,?,?)")
    try
        for entry in entries
            DBInterface.execute(statement,(entry.bib_key,_bibtex(entry),get(entry,"doi",""),
                get(entry,"url",""),parse(Int,strip(get(entry,"year","0"))),get(entry,"author","")))
        end
    finally
        DBInterface.close!(statement)
    end
    nothing
end
ensure_bib!(db,key)=insert_bibliography!(db;key)
