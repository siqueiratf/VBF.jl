"""Final normalized output preserves observed non-APN failure certificates."""
module RAMClosureOutputTests
using Test,VBF,VBFSearch,SQLite,TOML
include(joinpath(@__DIR__,"..","tools","ram_closure_search.jl"))
include(joinpath(@__DIR__,"..","tools","ram_closure_output.jl"))
const FP=VBFSearch
const R=RAMClosureSearch
const O=RAMClosureOutput

@testset "RAM output retains actual candidate diagnostics" begin
    mktempdir() do directory
        db=SQLite.DB(joinpath(directory,"diagnostics.sqlite"))
        lease=FP._closure_lease(directory)
        store=FP.ClosureStore(db,directory,lease,Dict{String,Any}(),0,UInt64(0))
        try
            FP._closure_create_schema(db;normalized=true)
            for lut in (zeros(UInt8,256),gold_apn(8).lut,gf_monomial_lut(8,57))
                full=FP.properties(lut)
                p=R.S.compact_record_properties(full)
                row=(;id=p["lut_sha256"],lut_hex=p["lut_hex"],apn=p["apn"],degree=p["algebraic_degree"],sigma=get(p,"sigma_hash",nothing))
                FP._closure_insert_candidate!(store,O.compact_properties(row))
                before=only(FP._closure_rows(store,"SELECT properties FROM candidates WHERE id=?",(row.id,)))["properties"]
                O.diagnostics!(store,p)
                saved=TOML.parse(only(FP._closure_rows(store,"SELECT properties FROM candidates WHERE id=?",(row.id,)))["properties"])
                @test saved["lut_hex"]==p["lut_hex"]
                @test saved["apn"]==p["apn"] && saved["algebraic_degree"]==p["algebraic_degree"]
                if !p["apn"] || !p["quadratic"]
                    @test saved["differential_uniformity"]==full["differential_uniformity"]
                    if !isempty(get(full,"non_apn_witness",Dict()))
                        @test saved["non_apn_witness"]==full["non_apn_witness"]
                    end
                    bad=copy(p);bad["lut_sha256"]=repeat("0",64)
                    @test_throws ErrorException O.diagnostics!(store,bad)
                else
                    @test FP._closure_text(saved)==before
                end
            end
            @test isempty(FP._closure_rows(store,"PRAGMA foreign_key_check"))
        finally
            FP._closure_close(store)
        end
    end
end
end
