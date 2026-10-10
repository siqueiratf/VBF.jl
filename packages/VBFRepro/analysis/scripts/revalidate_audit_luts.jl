# Revalidate the eight historical F060 proposals through their Julia builders.
# Run from the root project. This writes no catalog rows and proves no novelty.
using VBF, TOML, SHA
module AuditB04
include(joinpath(@__DIR__, "..", "..", "papers", "2009", "Budaghyan_200904", "helpers.jl"))
end
module AuditB10
include(joinpath(@__DIR__, "..", "..", "papers", "2009", "Budaghyan_200910", "helpers.jl"))
end
module AuditEP
include(joinpath(@__DIR__, "..", "..", "papers", "2009", "Edel_200900", "table7.jl"))
end
module AuditBr11
include(joinpath(@__DIR__, "..", "..", "papers", "2011", "Bracken_201103", "theorem1.jl"))
end

function revalidate_audit_luts()
    candidates = [
        ("n7_Budaghyan200904_x3_tr_x9", "apn_x3_tr_x9(7; modulus=131)", AuditB04.apn_x3_tr_x9(7; modulus=131)),
        ("n8_Budaghyan200904_x9_tr_x3", "gold_plus_trace(8,9,3; modulus=283)", AuditB04.gold_plus_trace(8,9,3; modulus=283)),
        ("n6_Budaghyan200910_eq6_alpha", "apn_eq6(6,2; modulus=67)", SBox{6}(AuditB10.apn_eq6(6,2; modulus=67))),
        ("n6_Edel2009_nonquadratic", "edelpott_table5(), entry 2.11", only(filter(r->r.name=="2.11", AuditEP.edelpott_table5())).sbox),
        ("n7_Edel2009_no14_3", "edelpott_table7_14_3()", AuditEP.edelpott_table7_14_3()),
        ("n12_Bracken2011_Family8", "theorem1_sbox(4,5,1,2; modulus=4179)", AuditBr11.theorem1_sbox(4,5,1,2; modulus=4179)),
        ("n12_Bracken2011_Family8W", "theorem1_sbox(4,5,1,0; modulus=4179)", AuditBr11.theorem1_sbox(4,5,1,0; modulus=4179)),
        ("n12_Bracken2011_Family7", "theorem1_sbox(4,5,0,2; modulus=4179)", AuditBr11.theorem1_sbox(4,5,0,2; modulus=4179)),
    ]
    root = normpath(joinpath(@__DIR__, "..", "..", "..", ".."))
    reference = TOML.parsefile(joinpath(root, "audit", "revalidated_luts.toml"))
    expected_by_name = Dict(row["name"] => row for row in reference["functions"])
    records = Dict{String,Any}[]
    for (name, recipe, F) in candidates
        lut = Int.(F.lut)
        bytes = UInt8[v for x in lut for v in (x & 255, x >> 8)]
        digest = bytes2hex(SHA.sha256(bytes))
        du = differential_uniformity(F)
        degree = algebraic_degree(F)
        expected = expected_by_name[name]
        digest == expected["sha256_uint16_le"] || error("Historical LUT changed: $name")
        du == 2 || error("Not APN: $name")
        degree == expected["degree"] || error("Degree changed: $name")
        push!(records, Dict("name"=>name, "recipe"=>recipe,
            "sha256_uint16_le"=>digest, "du"=>du, "degree"=>degree))
    end
    records
end

if abspath(PROGRAM_FILE) == @__FILE__
    records = revalidate_audit_luts()
    TOML.print(stdout, Dict("functions"=>records, "novelty_verified"=>false); sorted=true)
end
