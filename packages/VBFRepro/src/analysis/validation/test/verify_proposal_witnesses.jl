#=
Independently replay all positive EA certificates in a saved proposal report.
Run `julia verify_proposal_witnesses.jl REPORT.toml`. Uses only stdlib integer
arithmetic, with no VBF rank, graph or equivalence routines.
=#
using TOML, SHA

function binary_rank(columns)
    pivots = Dict{Int,Int}()
    for column in columns
        x = Int(column)
        while x != 0
            bit = 8sizeof(x) - leading_zeros(x) - 1
            if haskey(pivots, bit)
                x ⊻= pivots[bit]
            else
                pivots[bit] = x
                break
            end
        end
    end
    length(pivots)
end

lut_digest(lut) = bytes2hex(sha256(UInt8[b for x in lut for b in (x & 255, x >> 8)]))

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
            @assert length(A) == 2n && binary_rank(A) == 2n
            @assert all(a -> a >> n == 0, A[1:n])
            @assert binary_rank(A[1:n]) == n && binary_rank(A[n+1:end] .>> n) == n
            if haskey(proof, "reference_sha256_uint16_le")
                @assert lut_digest(G) == proof["reference_sha256_uint16_le"]
            end
            seen = Set{Int}()
            for (index, f) in enumerate(F)
                q, z = ((index-1) << n) | f, c
                for (j, a) in enumerate(A)
                    isodd(q >> (j-1)) && (z ⊻= a)
                end
                y = z >> n
                @assert y ∉ seen
                push!(seen, y)
                @assert G[y+1] == z & mask
            end
            @assert length(seen) == 1 << n
            certificates += 1
            points += length(F)
        end
    end
    (; certificates, points)
end

if abspath(PROGRAM_FILE) == @__FILE__
    length(ARGS) == 1 || error("usage: julia verify_proposal_witnesses.jl REPORT.toml")
    println("Independent Julia rank/block/hash/full-graph replay: ", verify_proposal_witnesses(only(ARGS)))
end
