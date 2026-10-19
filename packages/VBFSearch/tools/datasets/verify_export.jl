"""Fresh deterministic VBF checks of a standalone APN export; never writes it."""
module VerifyAPNExport
using VBF, SQLite, JSON3, SHA, Dates
const DBI = SQLite.DBInterface

function verify(path; sample_size=128)
    db=SQLite.DB("file:"*abspath(path)*"?mode=ro")
    SQLite.execute(db,"PRAGMA query_only=ON")
    SQLite.execute(db,"PRAGMA busy_timeout=10000")
    try
        ids=Int[r.class_id for r in DBI.execute(db,"SELECT class_id FROM classes ORDER BY class_id")]
        isempty(ids) && error("empty dataset")
        sample_size>0 || error("sample_size must be positive")
        count=min(sample_size,length(ids))
        positions=count==1 ? [1] : unique(round.(Int,range(1,length(ids);length=count)))
        checked=Int[]
        for pos in positions
            id=ids[pos]
            rows=[(lut=Vector{UInt8}(r.lut),sha=String(r.lut_sha256),sigma=String(r.sigma_hash))
                  for r in DBI.execute(db,"SELECT lut,lut_sha256,sigma_hash FROM classes WHERE class_id=?",(id,))]
            row=only(rows)
            bytes2hex(SHA.sha256(row.lut))==row.sha || error("LUT hash differs for class $id")
            F=SBox{8}(row.lut)
            algebraic_degree(F)==2 || error("nonquadratic class $id")
            differential_uniformity(F)==2 || error("non-APN class $id")
            VBF.sigma_hash(F)==row.sigma || error("signature differs for class $id")
            push!(checked,id)
        end
        Dict("passed"=>true,"sample_size"=>length(checked),"total_classes"=>length(ids),
             "class_ids"=>checked,"selection"=>"Evenly spaced positions in class-ID order, including both endpoints",
             "checks"=>["SHA256 of LUT","VBF algebraic degree = 2","VBF differential uniformity = 2","VBF sigma_hash"],
             "julia_version"=>string(VERSION),"vbf_source_sha256"=>bytes2hex(open(SHA.sha256,pathof(VBF))),
             "verified_utc"=>string(now(UTC))*"Z")
    finally
        close(db)
    end
end
end
if abspath(PROGRAM_FILE)==(@__FILE__)
    length(ARGS)==1 || error("usage: verify_export.jl DATASET.sqlite")
    println(VerifyAPNExport.JSON3.write(VerifyAPNExport.verify(only(ARGS))))
end
