"""Decode saved graph maps and check them with VBF's affine-map and graph APIs."""
module GraphWitnesses
using VBF, SHA, TOML
using ...VBFSearch: verify_graph_witness
export verify_graph_witness, verify_ea_witness, verify_ccz_witness, verify_proposal_witnesses, verify_witness_report

function verify_ccz_witness(f,g,cols,constant; relation=:ccz)
    length(f)==length(g)>=2 && ispow2(length(f)) || return false
    n=trailing_zeros(length(f));1<=n<=16 && length(cols)==2n || return false
    mask=(1<<n)-1;ambient=(1<<2n)-1
    all(x->x isa Integer && 0<=x<=mask,f) && all(x->x isa Integer && 0<=x<=mask,g) || return false
    all(x->x isa Integer && 0<=x<=ambient,cols) && constant isa Integer && 0<=constant<=ambient || return false
    A=F2AffineMap(F2LinearMap(Int.(cols)),Int(constant))
    verify_graph_witness(SBox{n}(f),SBox{n}(g),A;relation)
end
verify_ea_witness(f,g,cols,constant)=verify_ccz_witness(f,g,cols,constant;relation=:ea)

function verify_witness_report(path)
    report=TOML.parsefile(path);verified=0;seen=Set{String}()
    for row in report["checks"]
        hash=row["sigma_hash"];hash in seen && error("duplicate candidate signature: $hash");push!(seen,hash)
        row["status"]=="ea_equivalent" || continue
        f,g=hex2bytes(row["candidate_lut_hex"]),hex2bytes(row["public_lut_hex"])
        bytes2hex(sha256(f))==row["candidate_lut_sha256"] || error("candidate LUT digest mismatch")
        bytes2hex(sha256(g))==row["public_lut_sha256"] || error("public LUT digest mismatch")
        verify_ea_witness(f,g,row["graph_map_columns"],row["graph_map_constant"]) || error("invalid EA certificate")
        verified+=1
    end
    verified==report["ea_equivalent"] || error("certificate count mismatch")
    verified
end

lut_digest(lut)=bytes2hex(sha256(UInt8[b for x in lut for b in (x & 255,x >> 8)]))
function verify_proposal_witnesses(path)
    report=TOML.parsefile(path);certificates=points=0
    for row in report["proposals"]
        F,n=row["lut"],row["n"];mask=(1<<n)-1
        @assert length(F)==1<<n && all(x->0<=x<=mask,F)
        @assert lut_digest(F)==row["sha256_uint16_le"]
        for proof in vcat(get(row,"equivalence_checks",[]),get(row,"proposal_pair_checks",[]))
            proof["status"] in ("identical_lut","ea_equivalent_witness_replayed") || continue
            G=proof["reference_lut"]
            @assert verify_ea_witness(F,G,proof["columns"],proof["constant"])
            @assert !haskey(proof,"reference_sha256_uint16_le") || lut_digest(G)==proof["reference_sha256_uint16_le"]
            certificates+=1;points+=length(F)
        end
    end
    (;certificates,points)
end
end
