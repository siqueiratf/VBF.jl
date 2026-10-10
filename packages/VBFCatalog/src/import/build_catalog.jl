using VBF
using VBFCatalog
import SQLite
import DBInterface
import Dates
import TOML

# Assemble the new catalog beside the committed one and swap it in only after
# it verifies. A rebuild that cannot reproduce the catalog then destroys
# nothing. VBFCatalog.catalog_path() honours BFA_CATALOG_PATH, so every importer
# that calls load_catalog() follows us to the staging file without changes.
const FINAL_CATALOG = VBFCatalog.catalog_path()
const CATALOG_FILE = FINAL_CATALOG * ".building"
ENV["BFA_CATALOG_PATH"] = CATALOG_FILE

include(joinpath(@__DIR__, "load_sources.jl"))
include(joinpath(@__DIR__, "cache.jl"))
include(joinpath(@__DIR__, "bibliography.jl"))
include(joinpath(@__DIR__, "check.jl"))

function _git_sha()
    try
        return readchomp(`git -C $(pkgdir(VBF)) rev-parse --short HEAD`)
    catch
        return "unknown"
    end
end

function _today_utc()
    string(Dates.now(Dates.UTC)) * "Z"
end

function insert_curated!(db, family, names, loader, metadata, contributor, source_repo)
    today=_today_utc()
    statement=DBInterface.prepare(db,"INSERT INTO functions (family,n,m,lut_sha256,lut_blob,algebraic_form,algebraic_degree,differential_uniformity,linearity,boomerang_uniformity,is_apn,is_permutation,is_quadratic,canonical_name,bib_key,source_repo,contributor,added_date,notes) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)")
    try
        for name in names
            meta=metadata(name); F=loader(name)
            n=inputbits(F); perm=is_permutation(F)
            du=Int(differential_uniformity(F)); degree=algebraic_degree(F)
            family=="APN" && du!=2 && error("non-APN declarative entry: $name")
            DBInterface.execute(statement,(family,n,n,lut_sha256_hex(F),canonical_lut_bytes(F),
                get(meta,"algebraic_form",nothing),degree,du,Int(linearity(F)),
                perm ? Int(boomerang_uniformity(F)) : nothing,Int(du==2),Int(perm),Int(degree<=2),
                name,meta["bib_key"],source_repo,contributor,today,meta["description"]))
        end
    finally
        DBInterface.close!(statement)
    end
    nothing
end

"""
Per-family row counts of a catalog, or an empty Dict when it does not exist.
"""
function _catalog_counts(path::AbstractString; corpora=false)
    counts = Dict{String,Int}()
    isfile(path) || return counts
    db = SQLite.DB(path)
    try
        query=corpora ? "SELECT name,member_count c FROM bulk_corpora" :
            "SELECT family name, COUNT(*) c FROM functions GROUP BY family"
        for r in DBInterface.execute(db,query)
            counts[String(r.name)] = Int(r.c)
        end
    finally
        close(db)
    end
    counts
end

"""
Refuse to start when a source the committed catalog depends on is unavailable.
Checked BEFORE create_catalog() so a doomed rebuild never destroys anything.
"""
function _preflight_required_sources()
    get(ENV, "BFA_ALLOW_PARTIAL", "") == "1" && return
    config = TOML.parsefile(joinpath(@__DIR__, "sources.toml"))
    missing_srcs = String[]
    for src in get(config, "source", [])
        get(src, "required", false) === true || continue
        get(src, "builtin", false) === true && continue      # no external data
        haskey(src, "upstream") && continue                  # auto-clones
        env_var = get(src, "env_var", "")
        env_val = _bfa_source_root(src)
        if isempty(env_val) ||
           !_bfa_check_valid(env_val, src["check_path"], get(src, "check_kind", "dir"))
            push!(missing_srcs,
                  "  $(get(src, "label", src["name"])) — set $env_var to a checkout " *
                  "containing '$(src["check_path"])'")
        end
    end
    isempty(missing_srcs) && return
    error("""
    BFA: refusing to rebuild — $(length(missing_srcs)) required source(s) unavailable:

    $(join(missing_srcs, "\n"))

    The committed catalog contains rows only these sources can produce. A
    rebuild without them would silently drop those rows and then fail the
    catalog gate. Nothing has been modified.

    Override (produces an incomplete catalog that fails the gate):
        BFA_ALLOW_PARTIAL=1
    """)
end

function _chain_external_imports()
    config = TOML.parsefile(joinpath(@__DIR__, "sources.toml"))
    for src in get(config, "source", [])
        importer = joinpath(@__DIR__, src["importer"])
        isfile(importer) || error("missing registered importer: $importer")
        label    = get(src, "label", src["name"])
        required = get(src, "required", false) === true
        env_var  = get(src, "env_var", "")
        env_val  = _bfa_source_root(src)
        if get(ENV, "BFA_REIMPORT", "0") != "1" && haskey(src, "reuse_corpus")
            source_path = joinpath(env_val, src["check_path"])
            target = load_catalog()
            try
                cached_corpus!(target, FINAL_CATALOG, src["reuse_corpus"], source_path) && continue
            finally
                close(target)
            end
            continue
        end
        # Sources without an upstream URL are local-only: only include their
        # script when the env var already points to a valid path.  This avoids
        # loading optional heavy dependencies (e.g. Parquet2, JSON3) into
        # projects that don't have them just because the importer script exists.
        # Sources that declare an upstream can always be included because
        # with_source() will auto-clone when the env var is unset.
        # A builtin source constructs its functions from VBF and needs no
        # external data, so it always runs.
        if !get(src, "builtin", false) &&
           !haskey(src, "upstream") &&
           !_bfa_check_valid(env_val, src["check_path"], get(src, "check_kind", "dir"))
            @warn "BFA: skipping $label (source unavailable; set $env_var to enable)"
            continue
        end
        # Clear the no_autorun guard so main() fires when we include the script.
        # A previous include in this chain may have set it as a side-effect
        # (e.g. import_quadratic_apn_8bit.jl sets BFA_SBOXU_NO_AUTORUN=1 to
        # guard its own nested include of import_sboxu_apn.jl).
        no_autorun = get(src, "no_autorun", "")
        saved_guard = isempty(no_autorun) ? nothing : pop!(ENV, no_autorun, nothing)
        try
            @info "Chaining $label import" importer
            context = Module(gensym(:CatalogImport))
            Core.eval(context, :(include(path) = Base.include($context, path)))
            Base.include(context, importer)
        catch err
            if required && get(ENV, "BFA_ALLOW_PARTIAL", "") != "1"
                rethrow()
            end
            @warn "$label import failed; the catalog is INCOMPLETE" exception=(err, catch_backtrace())
        finally
            isempty(no_autorun) || (saved_guard === nothing ?
                delete!(ENV, no_autorun) : setindex!(ENV, saved_guard, no_autorun))
        end
    end
end

function main()
    _preflight_required_sources()
    before = _catalog_counts(FINAL_CATALOG)
    before_corpora = _catalog_counts(FINAL_CATALOG;corpora=true)

    sha = _git_sha()
    source_repo = "bfa@" * sha
    @info "Building BFA catalog" staging=CATALOG_FILE final=FINAL_CATALOG source_repo
    isfile(CATALOG_FILE) && rm(CATALOG_FILE)
    db = create_catalog(CATALOG_FILE;
                         bfa_version = "0.1.0-DEV",
                         git_sha = sha)
    insert_bibliography!(db)
    insert_curated!(db, "Literature", literature_sbox_names(), load_literature_sbox, literature_sbox_metadata, "VBF literature import", source_repo)
    insert_curated!(db, "APN", apn_catalog_names(), load_apn_function, apn_catalog_metadata, "VBF APN catalog import", source_repo)
    n_funcs = 0
    for r in DBInterface.execute(db, "SELECT COUNT(*) AS c FROM functions")
        n_funcs = r.c
    end
    @info "Catalog populated (BFA-only step)" functions=n_funcs file_size_bytes=filesize(CATALOG_FILE)
    close(db)
    _chain_external_imports()

    # --- verify before replacing the committed catalog ----------------------
    # Compare PER FAMILY, never on the total. Importers deduplicate by LUT hash,
    # so when a source goes missing the next importer absorbs the functions it
    # would have claimed: dropping simonberg takes CCZ-rep-GF4 27 -> 0 and pushes
    # known-family 69 -> 89, for a total only 7 short. A total-only check would
    # call that healthy. A family that vanishes is the signal.
    after = _catalog_counts(CATALOG_FILE)
    after_corpora = _catalog_counts(CATALOG_FILE;corpora=true)
    lost = String[]
    for (kind,previous,current) in (("family",before,after),("corpus",before_corpora,after_corpora))
        for (name,n) in sort(collect(previous);by=first)
            got=get(current,name,0)
            got<n && push!(lost,"  $kind $name: $n -> $got (lost $(n-got))")
        end
    end
    if !isempty(lost) && get(ENV, "BFA_ALLOW_PARTIAL", "") == "1"
        # The override lets a partial build finish, but it must still never
        # replace the committed catalog: that is the data loss it is overriding.
        @warn """
        BFA: PARTIAL catalog built. It was NOT installed.

        $(join(lost, "\n"))

        staging file : $CATALOG_FILE
        committed    : $FINAL_CATALOG  (unchanged)

        Inspect the staging file, then delete it. Do not commit it: it fails the
        catalog gate.
        """
        return
    end
    if !isempty(lost)
        rm(CATALOG_FILE; force = true)
        error("""
        BFA: rebuild produced a SMALLER catalog than the committed one:

        $(join(lost, "\n"))

        The committed catalog at
            $FINAL_CATALOG
        is UNCHANGED; the staging file has been deleted. A rebuild that drops
        rows is a source problem, not a result: some importer did not run, or
        ran against a source that no longer contains what it did before.

        Override (keeps the smaller catalog; it will fail the gate):
            BFA_ALLOW_PARTIAL=1
        """)
    end

    gained = ["  $f: $(get(before, f, 0)) -> $n" for (f, n) in sort(collect(after); by = first)
              if n > get(before, f, 0)]
    isempty(gained) || @info "Families that grew\n" * join(gained, "\n")

    check_catalog(CATALOG_FILE)
    mv(CATALOG_FILE, FINAL_CATALOG; force = true)
    delete!(ENV, "BFA_CATALOG_PATH")
    @info "Catalog rebuilt and verified" path=FINAL_CATALOG file_size_bytes=filesize(FINAL_CATALOG) families=length(after) functions=sum(values(after))
end

isinteractive() || main()
