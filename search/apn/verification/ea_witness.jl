"""Check saved EA graph maps using only Julia's standard library."""
module IndependentEAWitness
using SHA, TOML
export verify_ea_witness, verify_ccz_witness, verify_witness_report

function apply_columns(cols, x)
    y = 0
    for i in eachindex(cols)
        isodd(x >> (i-1)) && (y ⊻= cols[i])
    end
    y
end

"""Verify a bijective affine map of the full 16-bit ambient space on all graph points."""
function verify_ccz_witness(f,g,cols,constant)
    length(f) == length(g) == 256 || return false
    length(cols) == 16 || return false
    all(x -> x isa Integer && 0 <= x <= 255,f) || return false
    all(x -> x isa Integer && 0 <= x <= 255,g) || return false
    all(x -> x isa Integer && 0 <= x <= 65535,cols) || return false
    constant isa Integer && 0 <= constant <= 65535 || return false
    pivots = zeros(Int,16)
    for col in cols
        v = Int(col)
        for bit in 15:-1:0
            iszero(v & (1<<bit)) && continue
            if iszero(pivots[bit+1])
                pivots[bit+1] = v
                break
            end
            v ⊻= pivots[bit+1]
        end
    end
    all(!iszero,pivots) || return false
    images = Set{Int}()
    for x in 0:255
        q = apply_columns(cols,(x<<8)|Int(f[x+1])) ⊻ constant
        Int(g[(q>>8)+1]) == (q & 255) || return false
        push!(images,q>>8)
    end
    length(images)==256
end

"""
Verify an affine graph map from candidate F to public G, packed (x << 8)|F(x).
Check preservation of the output subspace, bijective input/output blocks,
and the graph identity at all 256 points. No VBF equivalence API is used.
"""
function verify_ea_witness(f, g, cols, constant)
    verify_ccz_witness(f,g,cols,constant) || return false
    length(f) == length(g) == 256 || return false
    length(cols) == 16 || return false
    all(x -> x isa Integer && 0 <= x <= 255, f) || return false
    all(x -> x isa Integer && 0 <= x <= 255, g) || return false
    all(x -> x isa Integer && 0 <= x <= 65535, cols) || return false
    constant isa Integer && 0 <= constant <= 65535 || return false
    all(iszero(c >> 8) for c in cols[1:8]) || return false
    length(Set(apply_columns(cols[1:8], x) for x in 0:255)) == 256 || return false
    length(Set(apply_columns(cols[9:16], x) >> 8 for x in 0:255)) == 256 || return false
    for x in 0:255
        q = apply_columns(cols, (x << 8) | Int(f[x+1])) ⊻ constant
        Int(g[(q >> 8)+1]) == (q & 255) || return false
    end
    true
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
end

if abspath(PROGRAM_FILE) == (@__FILE__)
    length(ARGS) == 1 || error("usage: ea_witness.jl equivalence_checks.toml")
    IndependentEAWitness.verify_witness_report(ARGS[1])
end
