"""
Independently verify candidate TSVs and compare against the fresh union.

    julia --project=. check_candidates.jl OUTDIR CANDIDATES.tsv...

Accepts census `sigma_hash<TAB>coeffs` (header optional), search_b52's named
columns, or `sigma_hash<TAB>record<TAB>lut_hex`. Coefficients are the census
28-byte squarefree Boolean ANF in row order, or the catalog's 37-byte encoding.
Hashes stored in the candidate files are rechecked, not trusted.
"""
const CANDIDATE_USAGE = nothing
include("rebuild.jl")

"""Decode a candidate using its explicit column or unambiguous byte length."""
function candidate_lut(encoded)
    bytes = hex2bytes(encoded)
    length(bytes) == 256 && return bytes
    length(bytes) == 37 && return UInt8.(decode_quadratic_lut(bytes, 8, conway_polynomial(8)))
    length(bytes) == 28 || error("expected 28/37 coefficient bytes or 256 LUT bytes")
    UInt8.(VBF.QuadraticAPNTree.lut(VBF.QuadraticAPNTree.decode_coeffs(encoded,8),8))
end

"""Save public dump record pointers and exact-LUT evidence for a signature hit."""
function public_reference(rawdb, olddb, io, hash, path, line, payload)
    refs = [(Int(r.member_idx), String(r.lut_sha256)) for r in DBI.execute(rawdb,
        "SELECT member_idx,lut_sha256 FROM records WHERE sigma_hash=? ORDER BY member_idx", (hash,))]
    isempty(refs) && return
    lutsha = bytes2hex(SHA.sha256(candidate_lut(payload)))
    direct = any(r -> r[2] == lutsha, refs)
    oldhit = scalar(olddb, "SELECT COUNT(*) c FROM ccz_sigma_index WHERE n=8 AND sigma_hash=?", (hash,)) > 0
    println(io, hash, '\t', path, '\t', line, '\t', first(refs)[1], '\t', length(refs), '\t', direct, '\t', oldhit)
end

"""Check candidates against a coverage-certified fresh baseline and save matches."""
function check_candidates(outdir, paths)
    comparison = TOML.parsefile(joinpath(outdir, "comparison.toml"))
    comparison["provenance_complete"] || error("original-source rebuild incomplete")
    comparison["fresh_union_sha256"] == filehash(joinpath(outdir, "fresh_union.sqlite")) ||
        error("baseline does not match the completed comparison report")
    db = readonly(joinpath(outdir, "fresh_union.sqlite"))
    seen = Set{String}()
    checked = matches = mismatches = duplicates = distinct_matches = 0
    statuses = Dict{String,Dict{String,Int}}()
    candidate_hashes = Dict(path=>filehash(path) for path in paths)
    output = joinpath(outdir, "candidate_comparison.tsv")
    stmt = DBI.prepare(db, "SELECT 1 FROM signatures WHERE sigma_hash=? LIMIT 1")
    rawpath = joinpath(outdir, "raw_langevin_may2025.sqlite")
    rawdb = isfile(rawpath) ? readonly(rawpath) : nothing
    olddb = rawdb === nothing ? nothing : readonly(VBFCatalog.sigma_index_path())
    references = rawdb === nothing ? nothing : open(joinpath(outdir, "search_public_matches.tsv"), "w")
    references === nothing || println(references, "sigma_hash\tcandidate_file\tcandidate_line\tpublic_dump_first_record\tpublic_dump_records_with_signature\texact_lut_found\told_index_match")
    try
        open(output, "w") do io
            println(io, "file\tline\tsigma_hash\tstatus")
            for path in paths
                hashcol = 1; payloadcol = 2; statuscol = nothing
                rows = Tuple{Int,String,String,String}[]
                for (line_number, line) in enumerate(eachline(path))
                    isempty(strip(line)) && continue
                    cols = split(line, '\t')
                    if line_number == 1 && cols[1] in ("sigma", "sigma_hash")
                        hashcol = 1
                        col = findfirst(c -> c in ("coeffs", "lut", "lut_hex"), cols)
                        col === nothing && error("no candidate payload column: $path")
                        payloadcol = col
                        statuscol = findfirst(==("status"), cols)
                        continue
                    end
                    # The historical raw-only format is hash, record, LUT.
                    col = length(cols) >= 3 && length(cols[3]) == 512 ? 3 : payloadcol
                    label = statuscol === nothing ? "unlabelled" : String(cols[statuscol])
                    push!(rows, (line_number, String(cols[hashcol]), String(cols[col]), label))
                end
                workspaces = [Workspace() for _ in 1:Threads.nthreads()]
                fresh_hashes = Vector{String}(undef, length(rows))
                Threads.@threads :static for worker in eachindex(workspaces)
                    for j in worker:length(workspaces):length(rows)
                        fresh_hashes[j] = bytes2hex(signature(workspaces[worker], candidate_lut(rows[j][3])))
                    end
                end
                for (j, (line_number, stored_hash, _, label)) in enumerate(rows)
                    fresh = fresh_hashes[j]
                    checked += 1
                    counts = get!(statuses, label, Dict("checked"=>0, "matches"=>0, "absent"=>0, "hash_mismatch"=>0))
                    counts["checked"] += 1
                    if fresh != stored_hash
                        mismatches += 1
                        counts["hash_mismatch"] += 1
                        println(io, path, '\t', line_number, '\t', fresh, "\tstored_hash_mismatch")
                        continue
                    end
                    duplicate = fresh in seen
                    duplicate && (duplicates += 1)
                    push!(seen, fresh)
                    hit = !isempty(collect(DBI.execute(stmt, (fresh,))))
                    matches += hit
                    hit && !duplicate && (distinct_matches += 1)
                    counts[hit ? "matches" : "absent"] += 1
                    if hit && label == "search" && references !== nothing
                        public_reference(rawdb, olddb, references, fresh, path, line_number, rows[j][3])
                    end
                    println(io, path, '\t', line_number, '\t', fresh, '\t', hit ? "possible_equivalence_match" : "absent_from_rebuilt_inputs")
                end
            end
        end
    finally
        DBI.close!(stmt); close(db)
        rawdb === nothing || close(rawdb)
        olddb === nothing || close(olddb)
        references === nothing || close(references)
    end
    report = Dict("checked"=>checked, "distinct_candidate_signatures"=>length(seen),
        "duplicate_signatures"=>duplicates, "signature_mismatches"=>mismatches,
        "matching_records"=>matches, "absent_records"=>checked-mismatches-matches,
        "distinct_matching_signatures"=>distinct_matches,
        "distinct_absent_signatures"=>length(seen)-distinct_matches,
        "original_status"=>statuses,
        "candidate_sha256"=>candidate_hashes,
        "fresh_union_sha256"=>comparison["fresh_union_sha256"])
    all(filehash(path) == digest for (path, digest) in candidate_hashes) ||
        error("candidate file changed during verification; rerun against a frozen file")
    open(io -> TOML.print(io, report; sorted=true), joinpath(outdir, "candidate_comparison.toml"), "w")
    println(report)
    mismatches == 0 || error("candidate stored signatures disagree with independent verification")
end

if abspath(PROGRAM_FILE) == (@__FILE__)
    length(ARGS) >= 2 || error("usage: check_candidates.jl OUTDIR CANDIDATES.tsv...")
    check_candidates(abspath(ARGS[1]), ARGS[2:end])
end
