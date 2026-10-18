"""Write a small closure campaign that the dashboard can show.

Run from the repository root:
  julia --project=. packages/VBFSearch/tools/closure_demo.jl DIR [ROOTS] [CORPUS]

The tool takes the first ROOTS (default 3) functions of the published catalog
corpus CORPUS (default `yuwangli2014_qam_n8`) with P6 bminK b6 = 52 and pairwise
different sigma hashes. Different quadratic signatures separate EA classes, so
the root audit needs no positive witness. Then it calls `closure_init` and
writes the campaign into DIR. This is a demo scope. It does not replace the
audit of the 24,294 published roots of the real campaign.
"""
module ClosureDemo
using VBF, VBFCatalog, VBFSearch, TOML, SHA
const QP = VBF.QuadraticProfiles

hash(path) = bytes2hex(open(SHA.sha256, path))
profile_text(profile) = join(("$b,$K" for (b, K) in profile), ':')

function main(directory; roots=3, corpus="yuwangli2014_qam_n8")
    dir = abspath(directory)
    isdir(dir) && !isempty(readdir(dir)) && error("$dir must be empty or absent")
    mkpath(dir)
    db = load_catalog()
    rows = String[]; seen = Set{String}()
    for i in 1:corpus_length(db, corpus)
        length(rows) == roots && break
        lut = collect(corpus_function(db, corpus, i).lut)
        p = VBFSearch.properties(lut)
        p["apn"] && p["quadratic"] && !(p["sigma_hash"] in seen) || continue
        alpha = QP.component_alphas(QP.component_ranks(QP.coeff_matrix_from_lut(lut)))
        profile = first(QP.profile_pk(alpha, 6; order=:bminK))
        last(profile)[1] == 52 || continue
        push!(seen, p["sigma_hash"])
        push!(rows, join((p["sigma_hash"], p["lut_hex"], "$corpus:$i", p["lut_sha256"], profile_text(profile)), '\t'))
        @info "root" index=i sigma=p["sigma_hash"]
    end
    length(rows) == roots || error("$corpus has fewer than $roots roots with b6 = 52")
    file(name, text) = (path = joinpath(dir, name); write(path, text); path)
    toml(name, value) = (path = joinpath(dir, name); open(io -> TOML.print(io, value), path, "w"); path)
    verified = file("verified.tsv", "sigma_hash\tlut_hex\tcatalog_id\tlut_sha256\tP6_bminK\n" * join(rows, '\n') * "\n")
    selected = file("selected_roots.tsv", read(verified, String))
    certificates = file("EA_certificates.tsv", "# demo: the roots have pairwise different sigma hashes\n")
    toml("qualification.toml", Dict("complete"=>true, "inconclusive"=>0, "processed"=>roots, "total"=>roots,
        "selected_roots_sha256"=>hash(selected)))
    toml("equivalence.toml", Dict("complete"=>true, "all_encoded_positive_witnesses_replayed"=>true,
        "verified_roots_sha256"=>hash(verified), "verified_seed_classes"=>roots,
        "certificate_sha256"=>hash(certificates)))
    toml("pool.toml", Dict("demo"=>true, "corpus"=>corpus))
    campaign = toml("campaign.toml", Dict("schema"=>"vbfsearch-literature-closure-plan-v2",
        "roots"=>Dict("n"=>8, "m"=>8, "profile_order"=>"bminK", "profile_b6"=>52,
            "historical_discoveries_as_roots"=>false, "qualified_root_file"=>"verified.tsv",
            "equivalence_evidence"=>"equivalence.toml", "qualification_evidence"=>"qualification.toml",
            "source_inventory"=>"pool.toml", "qualified_root_count"=>roots, "sources"=>[corpus]),
        "methods"=>Dict("v5"=>Dict("target_b6"=>52, "bent"=>"max", "heuristic_histogram_pruning"=>false)),
        "promotion"=>Dict("global_b6_filter"=>"none", "p6_profile_filter"=>"none")))
    println(VBFSearch.closure_init(campaign; output=joinpath(dir, "run")))
end

if abspath(PROGRAM_FILE) == @__FILE__
    isempty(ARGS) && error("usage: closure_demo.jl DIR [ROOTS] [CORPUS]")
    main(ARGS[1]; roots=length(ARGS) > 1 ? parse(Int, ARGS[2]) : 3,
        corpus=length(ARGS) > 2 ? ARGS[3] : "yuwangli2014_qam_n8")
end
end
