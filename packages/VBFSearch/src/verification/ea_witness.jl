"""Check saved EA graph maps using only Julia's standard library."""
module IndependentEAWitness
using SHA, TOML
export verify_ea_witness, verify_ccz_witness, verify_witness_report, verify_proposal_witnesses

function apply_columns(cols, x)
    y = 0
    for i in eachindex(cols)
        isodd(x >> (i-1)) && (y ⊻= cols[i])
    end
    y
end

"""Verify a full affine graph certificate independently, using only integer arithmetic.
Square LUTs of dimensions 1:16 are supported; every graph point is checked.
"""
function verify_ccz_witness(f,g,cols,constant)
    length(f)==length(g) || return false
    length(f)>=2 && ispow2(length(f)) || return false
    n=trailing_zeros(length(f));1<=n<=16 || return false
    length(cols)==2n || return false
    mask=(1<<n)-1;ambient=(1<<2n)-1
    all(x->x isa Integer && 0<=x<=mask,f) || return false
    all(x->x isa Integer && 0<=x<=mask,g) || return false
    all(x->x isa Integer && 0<=x<=ambient,cols) || return false
    constant isa Integer && 0<=constant<=ambient || return false
    pivots=zeros(Int,2n)
    for column in cols
        v=Int(column)
        for bit in (2n-1):-1:0
            iszero(v & (1<<bit)) && continue
            if iszero(pivots[bit+1]);pivots[bit+1]=v;break;end
            v ⊻= pivots[bit+1]
        end
    end
    all(!iszero,pivots) || return false
    seen=falses(length(f))
    for x in 0:mask
        q=apply_columns(cols,(x<<n)|Int(f[x+1])) ⊻ constant;y=q>>n
        seen[y+1] && return false
        seen[y+1]=true
        Int(g[y+1])==q & mask || return false
    end
    all(seen)
end

"""Verify a graph certificate preserving the output subspace (EA equivalence).
The full ambient invertibility and graph checks also imply invertible diagonal blocks.
"""
function verify_ea_witness(f,g,cols,constant)
    verify_ccz_witness(f,g,cols,constant) || return false
    n=trailing_zeros(length(f))
    all(iszero(c>>n) for c in cols[1:n])
end

"""Verify all positive certificates and LUT digests in a saved report."""
function verify_witness_report(path)
    report = TOML.parsefile(path)
    verified = 0
    seen = Set{String}()
    for row in report["checks"]
        hash = row["sigma_hash"]
        hash in seen && error("duplicate candidate signature: $hash")
        push!(seen, hash)
        row["status"] == "ea_equivalent" || continue
        f = hex2bytes(row["candidate_lut_hex"])
        g = hex2bytes(row["public_lut_hex"])
        bytes2hex(SHA.sha256(f)) == row["candidate_lut_sha256"] || error("candidate LUT digest mismatch")
        bytes2hex(SHA.sha256(g)) == row["public_lut_sha256"] || error("public LUT digest mismatch")
        verify_ea_witness(f, g, row["graph_map_columns"], row["graph_map_constant"]) ||
            error("invalid EA certificate: $hash")
        verified += 1
    end
    verified == report["ea_equivalent"] || error("certificate count mismatch")
    println("Independently verified EA witnesses: ", verified)
    verified
end

lut_digest(lut)=bytes2hex(sha256(UInt8[b for x in lut for b in (x & 255,x >> 8)]))

function verify_proposal_witnesses(path)
    report = TOML.parsefile(path)
    certificates = points = 0
    for row in report["proposals"]
        F, n = row["lut"], row["n"]
        mask = (1 << n) - 1
        @assert length(F) == 1 << n && all(x -> 0 <= x <= mask, F)
        @assert lut_digest(F) == row["sha256_uint16_le"]
        for proof in vcat(get(row, "equivalence_checks", []), get(row, "proposal_pair_checks", []))
            proof["status"] in ("identical_lut", "ea_equivalent_witness_replayed") || continue
            G, A, c = proof["reference_lut"], proof["columns"], proof["constant"]
            @assert length(G) == 1 << n && all(x -> 0 <= x <= mask, G)
            @assert 0 <= c < 1 << 2n && all(x -> 0 <= x < 1 << 2n, A)
            @assert verify_ea_witness(F,G,A,c)
            if haskey(proof, "reference_sha256_uint16_le")
                @assert lut_digest(G)==proof["reference_sha256_uint16_le"]
            end
            certificates += 1
            points += length(F)
        end
    end
    (; certificates, points)
end


end

if abspath(PROGRAM_FILE) == (@__FILE__)
    length(ARGS) == 1 || error("usage: ea_witness.jl equivalence_checks.toml")
    IndependentEAWitness.verify_witness_report(ARGS[1])
end
