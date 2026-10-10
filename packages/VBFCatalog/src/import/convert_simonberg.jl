using VBF
using VBFCatalog
import SQLite
import DBInterface
import Dates

include("load_sources.jl")
include("write.jl")

# --- parsing ----------------------------------------------------------------

# The polynomial strings of one `repN.txt`. The file is a single flat list `[ p1, p2, … ]` with no nested brackets, so top-level commas separate the polynomials.
function _class_polynomials(path::AbstractString)
    body = strip(read(path, String))
    (startswith(body, "[") && endswith(body, "]")) ||
        error("simonberg: $path is not a `[ … ]` list")
    body = strip(body[nextind(body, firstindex(body)):prevind(body, lastindex(body))])
    out = String[]
    for p in split(body, ','; keepempty = false)
        s = strip(replace(p, '\n' => ' '))
        isempty(s) || push!(out, s)
    end
    out
end

# --- catalog access ---------------------------------------------------------

# sha => row id for every existing `functions` row (snapshot before import).
function _existing_function_shas(db::SQLite.DB)
    d = Dict{String, Int}()
    for r in DBInterface.execute(db, "SELECT id, lut_sha256 FROM functions")
        d[String(r.lut_sha256)] = Int(r.id)
    end
    d
end

# --- import -----------------------------------------------------------------

struct ClassStats
    class::Int
    members::Int          # polynomials in the file
    rep_inserted::Bool    # representative added as a new row (vs merged)
end

function _human(io::IO, st::ClassStats)
    println(io, "[simonberg:class $(st.class)] members=$(st.members) ",
                "rep=$(st.rep_inserted ? "inserted" : "merged")")
end

# Process one class file: insert/merge its representative (first member) as a first-class row, and return that class' compact `quadratic-coeffs-v1` encodings for ALL members (for the bulk-corpus side store).
function import_one_class!(db::SQLite.DB, path::AbstractString, class::Int;
                           source_tag::AbstractString, bfa_repo::AbstractString,
                           contributor::AbstractString, added_date::AbstractString,
                           existing::Dict{String, Int}, powtab::Vector{Vector{Int}},
                           n::Int, modulus::Int)
    polys = _class_polynomials(path)
    isempty(polys) && error("simonberg: class $class has no polynomials")

    encodings = Vector{Vector{UInt8}}(undef, length(polys))
    rep_terms = nothing
    for (k, p) in enumerate(polys)
        terms = polynomial_terms(p, n, modulus)
        encodings[k] = encode_quadratic(terms, n)
        k == 1 && (rep_terms = terms)
    end

    # representative = first member; assert it is APN (a cheap validation that the parser + Conway field reproduce a genuine quadratic-APN function).
    rep = SBox{n}(terms_to_lut(rep_terms, n, modulus; powtab = powtab))
    differential_uniformity(rep) == 2 || error("simonberg: class $class representative not APN")
    rep_sha = lut_sha256_hex(rep)
    notes_str = "Simon-Berg thesis: representative of CCZ class $(class) of " *
                "GF(2²)-coefficient quadratic APN over GF(2⁸); $(length(polys)) members " *
                "(full membership in bulk corpus simonberg_gf4_n8)"
    rep_inserted = false
    if haskey(existing, rep_sha)
        row_id = existing[rep_sha]
        merge_source_repo!(db, row_id, bfa_repo)
        merge_source_repo!(db, row_id, source_tag)
        # Promote the existing row to CCZ-rep-GF4 so it appears in family queries.
        SQLite.execute(db,
            "UPDATE functions SET family = " * VBFCatalog._sql_quote("CCZ-rep-GF4") *
            ", canonical_name = " * VBFCatalog._sql_quote("SimonBerg_GF4_n8_class_$(class)") *
            ", notes = " * VBFCatalog._sql_quote(notes_str) *
            " WHERE id = $(row_id) AND family != " * VBFCatalog._sql_quote("CCZ-rep-GF4"))
    else
        insert_function!(db, rep; family="CCZ-rep-GF4",
            canonical_name = "SimonBerg_GF4_n8_class_$(class)",
            source_repo = bfa_repo * "|" * source_tag,
            contributor = contributor, added_date = added_date,
            notes = notes_str)
        rep_inserted = true
    end

    (ClassStats(class, length(polys), rep_inserted), encodings)
end

function main()
    with_source("simonberg") do dir
    sha = source_short_sha(dir)
    tag = "simonberg@" * sha
    bfa_sha = try
        readchomp(`git -C $(pkgdir(VBF)) rev-parse --short HEAD`)
    catch
        "unknown"
    end
    bfa_repo = "bfa@" * bfa_sha
    contributor = "BFA Simon-Berg import (automated)"
    added = string(Dates.now(Dates.UTC)) * "Z"
    n = 8
    modulus = conway_polynomial(n)
    @info "Simon-Berg thesis import" dir sha bfa_sha

    powtab = monomial_power_table(n, modulus)
    db = load_catalog()
    try
        existing = _existing_function_shas(db)
        all_encodings = Vector{UInt8}[]
        total_members = total_inserted = 0
        for class in 1:27
            path = joinpath(dir, "rep$(class).txt")
            isfile(path) || (@warn "skipping (missing)" path; continue)
            st, encodings = import_one_class!(db, path, class;
                source_tag = tag, bfa_repo = bfa_repo,
                contributor = contributor, added_date = added,
                existing = existing, powtab = powtab, n = n, modulus = modulus)
            _human(stdout, st)
            append!(all_encodings, encodings)
            total_members += st.members
            total_inserted += st.rep_inserted ? 1 : 0
        end

        # bulk-corpus side store: all members as quadratic-coeffs-v1 encodings
        corpus = "simonberg_gf4_n8"
        store = build_corpus_store!(corpus, all_encodings)
        register_corpus!(db;
            name = corpus, n = n, m = n, member_count = store.count, degree = 2,
            modulus = modulus, encoding = "quadratic-coeffs-v1",
            bytes_per_member = store.bytes_per_member,
            store_file = store.store_file, store_sha256 = store.sha256,
            family = "CCZ-rep-GF4", bib_key = nothing,
            source_repo = bfa_repo * "|" * tag, contributor = contributor,
            added_date = added,
            notes = "Simon Berg thesis: all CCZ classes of GF(2²)-coefficient quadratic " *
                    "APN over GF(2⁸); 27 class representatives are first-class CCZ-rep-GF4 rows")
        println("[simonberg] TOTAL members=$(total_members) rep_rows_inserted=$(total_inserted) ",
                "corpus=$(corpus) stored=$(store.count) bytes/member=$(store.bytes_per_member)")
    finally
        close(db)
    end
    end  # with_source
    return nothing
end

if abspath(PROGRAM_FILE)==(@__FILE__)
    main()
end
