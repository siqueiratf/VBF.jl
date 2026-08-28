#!/usr/bin/env julia
#
# generate_catalog_table.jl — emit every machine-derived part of
# `manuscript/apn_catalog.tex`.
#
#   julia --project=. -t auto manuscript/generate_catalog_table.jl
#
# Deterministic and re-runnable: it reads only files inside this repository and
# writes only into `manuscript/generated/`.  Nothing in `packages/` or `papers/`
# is modified, no database is rebuilt and no git command is run.
#
# ---------------------------------------------------------------------------
# DESIGN RULE: DERIVE, NEVER INVENT
# ---------------------------------------------------------------------------
# Every number that reaches the manuscript is produced here from a primary
# source.  Three mechanisms enforce that:
#
#   1. counts, dimensions and permutation flags are read out of the TOMLs and
#      out of `BFA_catalog.sqlite` / `corpora/*.sqlite`;
#   2. the APN property is RE-COMPUTED here for every catalogued object — all
#      35 curated entries, all named `functions` rows, and all 229 779 bulk
#      corpus members — rather than trusted from a stored flag;
#   3. every qualitative status symbol (A/I/E/N) is backed by an entry in
#      EVIDENCE below.  Each entry names a file and a literal substring; the
#      generator asserts that substring occurs verbatim in that file and aborts
#      if it does not.  A status symbol whose evidence string has drifted can
#      therefore never be printed.
#
# Anything that cannot be derived is printed with the "no such claim / not
# applicable" mark, never guessed.
#
# ---------------------------------------------------------------------------
# SOURCE PRECEDENCE (tracked before untracked)
# ---------------------------------------------------------------------------
# TRACKED (authoritative, everything in the emitted table rests on these):
#   packages/VBFCatalog/data-raw/apn_catalog/n*_apn.toml   curated entries
#   packages/VBFCatalog/data-raw/bibliography.bib          citation keys
#   packages/VBFCatalog/BFA_catalog.sqlite                 named entries, CCZ classes,
#                                                          bulk-corpus registry
#   packages/VBFCatalog/corpora/*.sqlite                   corpus members
#   packages/VBFCatalog/data-build/*.jl                    importer verification code
#   packages/VBF/src/**.jl                                 library guards
#   papers/<year>/<Paper_ID>/README.md                     per-paper reproduction reviews
#
# UNTRACKED (corroboration only; never the sole support for a printed symbol):
#   audit/findings.yaml, audit/readme_index.yaml, report.md
# The generator runs to completion without them.  When `audit/findings.yaml` is
# present it is read for ONE purpose: to cross-check the kind -> E1..E5 mapping
# below and print a coverage report on stdout.  No emitted .tex file changes.
#
# ---------------------------------------------------------------------------
# `kind` (audit/findings.yaml) -> E1..E5 MAPPING
# ---------------------------------------------------------------------------
# The E1..E5 taxonomy classifies ONE divergence, never a paper, a construction
# or a family.  The mapping used here:
#
#   tool_limit               -> E5  a guard or a budget in THIS implementation stops the check
#   hard_limit               -> E5  the computation does not terminate at the stated size
#   theory_limit             -> E5  no reference set exists at that dimension
#   sampling_not_exhaustion  -> E4  the published evidence covers less than the claim
#   scope_restriction        -> E4  data needed to verify the core claim is not published
#   unsound_negative         -> E3  a negative result rests on unspecified pruning
#   unproved_premise         -> E3  a step is stated as proved but only exemplified
#   wrong_condition          -> E2  a stated hypothesis is contradicted by recomputation
#   wrong_value              -> E2  when the tier is `recomputed` or `code_confirmed`
#                            -> E1  when the tier is `paper_confirmed` AND severity is low
#                                   (a transcription slip located in the text itself)
#   internal_inconsistency   -> E1  when severity is low, i.e. label/index only
#                            -> E2  otherwise (recomputation contradicts the claim)
#   inferred                 -> --  a boundary read off a table is not a divergence
#
# An E-code is attached ONLY to a cell that carries the "divergence" mark, and
# ONLY when the supporting finding reached `recomputed` or `code_confirmed`.
# `readme_only` never justifies a divergence mark.
#
# ---------------------------------------------------------------------------
# UNITS — kept apart everywhere
# ---------------------------------------------------------------------------
#   construction method  a paradigm; the group headings of the table
#   family               a named construction or infinite class; ONE TABLE ROW
#   catalog record       one concrete stored object.  Two stores:
#                          named entry     — a curated TOML entry or a `functions` row
#                          corpus instance — a member of a `bulk_corpora` side store
#   recomputed claim     one A/I/E/N assertion checked in this repository
#
# BFA-4R is deliberately absent: the rubric is not in this repository, and the
# recomputation status printed here measures only what this work verified.

import TOML
using VBF
using VBFCatalog

const SQLite = VBFCatalog.SQLite
const DBInterface = VBFCatalog.DBInterface

const REPO = normpath(joinpath(@__DIR__, ".."))
const OUT = joinpath(@__DIR__, "generated")
const GENERATOR = "manuscript/generate_catalog_table.jl"

repopath(parts...) = joinpath(REPO, parts...)

const CATALOG_DIR = repopath("packages", "VBFCatalog", "data-raw", "apn_catalog")
const BIB_FILE = repopath("packages", "VBFCatalog", "data-raw", "bibliography.bib")
const DB_FILE = repopath("packages", "VBFCatalog", "BFA_catalog.sqlite")
const FINDINGS = repopath("audit", "findings.yaml")

# ===========================================================================
# 0.  helpers
# ===========================================================================

texesc(s::AbstractString) = replace(String(s),
    "\\" => "\\textbackslash{}", "_" => "\\_", "%" => "\\%", "&" => "\\&",
    "#" => "\\#", "\$" => "\\\$", "{" => "\\{", "}" => "\\}", "^" => "\\^{}",
    "~" => "\\textasciitilde{}")

"Collapse every whitespace run to one space, so that a re-wrapped source line cannot silently drop a status symbol."
wsnorm(s::AbstractString) = strip(replace(String(s), r"\s+" => " "))

"Thousands-grouped integer, LaTeX thin space."
function grouped(x::Integer)
    s = string(x)
    length(s) <= 3 && return s
    out = IOBuffer()
    for (k, c) in enumerate(s)
        k > 1 && (length(s) - k + 1) % 3 == 0 && print(out, "\\,")
        print(out, c)
    end
    String(take!(out))
end

"Compact count for the heat-map cells: 38, 485, 12.9k, 197k."
function compact(x::Integer)
    x < 1000 && return string(x)
    x < 10_000 && return string(round(x / 1000; digits = 1), "k")
    return string(round(Int, x / 1000), "k")
end

"Contiguous integer runs as `4--10, 12`."
function dimspec(ns)
    v = sort!(unique(collect(Int, ns)))
    isempty(v) && return "--"
    parts = String[]
    i = 1
    while i <= length(v)
        j = i
        while j < length(v) && v[j+1] == v[j] + 1
            j += 1
        end
        push!(parts, j - i >= 2 ? "$(v[i])--$(v[j])" :
                     j - i == 1 ? "$(v[i]),\\,$(v[j])" : "$(v[i])")
        i = j + 1
    end
    join(parts, ",\\,")
end

# ===========================================================================
# 1.  primary sources
# ===========================================================================

println("[1/8] reading tracked primary sources")

for p in (CATALOG_DIR, BIB_FILE, DB_FILE)
    ispath(p) || error("missing primary source: $p")
end

# --- 1a. bibliography keys --------------------------------------------------
const BIB_KEYS = Set{String}()
for m in eachmatch(r"^@[A-Za-z]+\{([^,\s]+)\s*,"m, read(BIB_FILE, String))
    push!(BIB_KEYS, String(m.captures[1]))
end
length(BIB_KEYS) > 0 || error("no bib keys parsed from $BIB_FILE")
println("      bibliography.bib: $(length(BIB_KEYS)) keys")

# --- 1b. curated TOML entries (AUTHORITATIVE, per data-raw) -----------------
struct Curated
    name::String
    n::Int
    m::Int
    is_permutation::Bool
    bib_key::String
    description::String
    source::String
    algebraic_form::String
    file::String
end

curated = Curated[]
for f in sort(readdir(CATALOG_DIR))
    endswith(f, "_apn.toml") || continue
    data = TOML.parsefile(joinpath(CATALOG_DIR, f))
    haskey(data, "apn_functions") || continue
    for e in data["apn_functions"]
        push!(curated, Curated(
            e["name"], e["n"], e["m"], e["is_permutation"], e["bib_key"],
            get(e, "description", ""), get(e, "source", ""),
            get(e, "algebraic_form", ""), f))
    end
end
sort!(curated; by = c -> (c.n, c.name))
println("      curated TOML entries: $(length(curated))")

for c in curated
    c.bib_key in BIB_KEYS ||
        error("curated entry $(c.name) cites unknown bib key $(c.bib_key)")
end

# --- 1c. BFA_catalog.sqlite -------------------------------------------------
db = SQLite.DB(DB_FILE)

struct DbFn
    id::Int
    family::String
    n::Int
    canonical_name::String
    bib_key::String
    is_permutation::Bool
    is_quadratic::Bool
    algebraic_degree::Int
end

dbfns = DbFn[]
for r in DBInterface.execute(db, """
        SELECT id, family, n, COALESCE(canonical_name,'') cn, COALESCE(bib_key,'') bk,
               is_permutation, is_quadratic, COALESCE(algebraic_degree,-1) deg
        FROM functions WHERE is_apn = 1 ORDER BY n, family, cn""")
    push!(dbfns, DbFn(Int(r.id), String(r.family), Int(r.n), String(r.cn),
                      String(r.bk), r.is_permutation == 1, r.is_quadratic == 1,
                      Int(r.deg)))
end
println("      BFA_catalog.sqlite APN `functions` rows: $(length(dbfns))")

# CCZ classes decided in-repo: strategy is the complete EA decision applied
# inside each ortho-derivative sigma bucket (packages/VBFCatalog/src/data/sigma.jl).
ccz_decided = Set{Int}()
for r in DBInterface.execute(db,
        "SELECT DISTINCT function_id FROM class_members WHERE strategy = 'ortho-derivative-sigma-confirmed'")
    push!(ccz_decided, Int(r.function_id))
end
function scalarq(db, sql)
    for r in DBInterface.execute(db, sql)
        return first(r)
    end
    error("query returned no row: $sql")
end
n_ccz_classes = Int(scalarq(db, "SELECT COUNT(*) FROM equivalence_classes WHERE kind='CCZ'"))
println("      CCZ classes decided in-repo: $n_ccz_classes over $(length(ccz_decided)) members")

struct Corpus
    name::String
    n::Int
    members::Int
    modulus::Int
    bib_key::String
    notes::String
end

corpora = Corpus[]
for r in DBInterface.execute(db, """
        SELECT name, n, member_count, modulus, COALESCE(bib_key,'') bk,
               COALESCE(notes,'') notes FROM bulk_corpora ORDER BY name""")
    push!(corpora, Corpus(String(r.name), Int(r.n), Int(r.member_count),
                          Int(r.modulus), String(r.bk), String(r.notes)))
end
println("      bulk corpora: $(length(corpora)), " *
        "$(sum(c.members for c in corpora)) instances")

# ===========================================================================
# 2.  RE-COMPUTATION — the APN property, from scratch, for every object
# ===========================================================================

println("[2/8] recomputing the APN property (threads = $(Threads.nthreads()))")

# 2a. curated entries.  `load_apn_function` materialises monomial-form entries
# from `monomial_exponent` + modulus and reads data-raw directly.
curated_apn = Dict{String,Bool}()
curated_perm = Dict{String,Bool}()
curated_deg = Dict{String,Int}()
curated_sha = Dict{String,String}()
for c in curated
    F = load_apn_function(c.name)
    curated_apn[c.name] = differential_uniformity(F) == 2
    curated_perm[c.name] = is_permutation(F)
    curated_deg[c.name] = algebraic_degree(F)
    curated_sha[c.name] = lut_sha256_hex(F)
end
n_curated_apn = count(values(curated_apn))
n_curated_apn == length(curated) ||
    error("recomputation: $(length(curated) - n_curated_apn) curated entries are NOT APN")
for c in curated
    curated_perm[c.name] == c.is_permutation ||
        error("recomputation: is_permutation disagrees with the TOML for $(c.name)")
end
println("      curated: $n_curated_apn/$(length(curated)) APN re-verified, " *
        "is_permutation agrees on all")

# 2b. named `functions` rows.
db_sha = Dict{Int,String}()
for r in DBInterface.execute(db, "SELECT id, lut_sha256 FROM functions WHERE is_apn = 1")
    db_sha[Int(r.id)] = String(r.lut_sha256)
end

db_apn_ok = 0
for f in dbfns
    blob = scalarq(db, "SELECT lut_blob FROM functions WHERE id = $(f.id)")
    s = VBFCatalog._sbox_from_blob(Vector{UInt8}(blob), f.n)
    differential_uniformity(s) == 2 && (global db_apn_ok += 1)
end
db_apn_ok == length(dbfns) ||
    error("recomputation: $(length(dbfns) - db_apn_ok) DB rows flagged APN are not APN")
println("      named DB rows: $db_apn_ok/$(length(dbfns)) APN re-verified")

# 2c. every bulk-corpus member.
struct CorpusCheck
    total::Int
    apn::Int
    quadratic::Int
    permutation::Int
    distinct::Int        # distinct lookup tables among the members
    also_named::Int      # members whose LUT is also stored as a named entry
end

# Content addresses of every named entry, for the cross-store overlap below.
named_sha = Set{String}(values(db_sha))
union!(named_sha, values(curated_sha))

corpus_checks = Dict{String,CorpusCheck}()
corpus_sha = Dict{String,Vector{String}}()
for c in corpora
    isfile(corpus_store_path(c.name)) || error(
        "corpus $(c.name): side store $(corpus_store_path(c.name)) is absent. " *
        "This table re-derives every figure from the members, so it cannot be " *
        "generated without them. Rebuild the store: " *
        "`make -C packages/VBFCatalog/data-build $(c.name == "beierle2025_n8" ? "beierle2025" : c.name)`.")
    store = SQLite.DB(corpus_store_path(c.name))
    coeffs = Vector{UInt8}[]
    for r in DBInterface.execute(store, "SELECT coeffs FROM members ORDER BY idx")
        push!(coeffs, Vector{UInt8}(r.coeffs))
    end
    close(store)
    length(coeffs) == c.members ||
        error("corpus $(c.name): side store holds $(length(coeffs)) rows, " *
              "bulk_corpora says $(c.members)")
    napn = Threads.Atomic{Int}(0)
    nquad = Threads.Atomic{Int}(0)
    nperm = Threads.Atomic{Int}(0)
    shas = Vector{String}(undef, length(coeffs))
    Threads.@threads for k in eachindex(coeffs)
        F = SBox{c.n}(VBFCatalog.decode_quadratic_lut(coeffs[k], c.n, c.modulus))
        differential_uniformity(F) == 2 && Threads.atomic_add!(napn, 1)
        algebraic_degree(F) == 2 && Threads.atomic_add!(nquad, 1)
        is_permutation(F) && Threads.atomic_add!(nperm, 1)
        shas[k] = lut_sha256_hex(F)
    end
    corpus_sha[c.name] = shas
    nnamed = count(h -> h in named_sha, shas)
    ndist = length(Set(shas))
    corpus_checks[c.name] = CorpusCheck(c.members, napn[], nquad[], nperm[], ndist, nnamed)
    println("      corpus $(rpad(c.name, 30)) $(c.members) members: " *
            "APN $(napn[]), quadratic $(nquad[]), permutations $(nperm[]), " *
            "distinct $(ndist), also named $(nnamed)")
end

# ===========================================================================
# 2d. RE-COMPUTATION — the one equivalence question the catalog leaves open
# ===========================================================================
#
# `papers/2009/Budaghyan_200910/README.md` records, under "Open questions",
# that the ortho-derivative mugshot of Budaghyan--Carlet--Leander 2009 eq. (6)
# with a = alpha over GF(2^8) is byte-identical to the catalog entry
# `n8_Taniguchi2025_ex4_2`, states in terms that this is "very strong evidence
# ... though not a proof", and asks for `are_ea_equivalent` to be run.  A
# mugshot match is a NECESSARY condition, so the earlier draft of this table
# printed a divergence that its own source declined to assert.
#
# The generator therefore decides it, rather than quoting the conjecture.  Eq.
# (6) is x^3 + a^-1 * tr_n(a^3 x^9) (Budaghyan--Carlet--Leander 2009,
# Corollary 3), built here on VBF's field primitives so that no script outside
# `packages/` has to be `include`d; the construction is cross-checked against
# the ortho-derivative differential spectrum quoted in the tracked review
# before it is used.  Both functions are quadratic APN, so CCZ and EA coincide
# (Yoshiara) and `are_ea_equivalent` routes through the ortho-derivative path,
# which is a complete decision on that class.

println("[2d/8] deciding the BCL-2009 eq. (6) / Taniguchi-2025 Ex. 4.2 collision")

function bcl09_eq6(n::Int, a::Int; modulus::Int)
    ai = gf_inv(a, n; modulus)
    a3 = gf_pow(a, 3, n; modulus)
    lut = Vector{Int}(undef, 1 << n)
    for x in 0:(1<<n)-1
        t = gf_trace(gf_mul(a3, gf_pow(x, 9, n; modulus), n; modulus), n; modulus)
        lut[x+1] = gf_pow(x, 3, n; modulus) ⊻ gf_mul(ai, t, n; modulus)
    end
    lut
end

const TPPA_ENTRY = "n8_Taniguchi2025_ex4_2"
const BCL09_REVIEW = "papers/2009/Budaghyan_200910/README.md"

# alpha = 2 is a root of `primitive_polynomial(8)` = 283, hence primitive; this
# is the same convention the reproduction uses.
const EQ6_MODULUS = primitive_polynomial(8)
EQ6_MODULUS == 283 || error("primitive_polynomial(8) changed; the review quotes modulus 283")

eq6_F = SBox{8}(bcl09_eq6(8, 2; modulus = EQ6_MODULUS))
tppa_G = load_apn_function(TPPA_ENTRY)

differential_uniformity(eq6_F) == 2 && algebraic_degree(eq6_F) == 2 ||
    error("BCL 2009 eq. (6) at n=8, a=alpha did not rebuild as a quadratic APN function")

# Cross-check the rebuilt eq. (6) against the spectrum the tracked review prints.
let od = ortho_derivative(eq6_F)
    od === nothing && error("eq. (6) at n=8 has no ortho-derivative")
    spec = differential_spectrum(od).counts
    txt = "{" * join(["$k:$(spec[k])" for k in sort(collect(keys(spec))) if spec[k] > 0], ", ") * "}"
    occursin(txt, wsnorm(read(repopath(split(BCL09_REVIEW, "/")...), String))) ||
        error("the rebuilt eq. (6) has OD differential spectrum $txt, which the tracked " *
              "review $BCL09_REVIEW does not report; the reconstruction is wrong")
    println("      eq. (6) OD differential spectrum $txt matches the tracked review")
end

eq6_luts_identical = eq6_F.lut == tppa_G.lut

# `on_inconclusive = :throw`: an undecided query must never be read as a result.
eq6_decided, eq6_equivalent = try
    (true, are_ea_equivalent(eq6_F, tppa_G; on_inconclusive = :throw))
catch err
    err isa VBF.InconclusiveEquivalence || rethrow()
    (false, false)
end
println("      LUTs byte-identical: $eq6_luts_identical; " *
        "EA decision: " * (eq6_decided ? string(eq6_equivalent) : "INCONCLUSIVE"))

# ===========================================================================
# 3.  TAXONOMY — construction methods, families, and the assignment rules
# ===========================================================================
#
# Assignment is by pattern on the stored identifier, never by a hand-written
# list of counts.  Every catalogued object must match exactly one rule; an
# unmatched object aborts the run, so a later catalog addition cannot silently
# vanish from the table.

println("[3/8] classifying catalog objects into families")

struct Group
    key::String
    code::String       # printed label, ties the table to the figure
    top::String        # top-level construction method
    title::String      # sub-heading printed in the table
    short::String      # row label in the figure
    unit::String       # WHAT ONE ROW OF THIS GROUP IS.  Not every row is a
    unitp::String      # family: C holds representative populations produced by
end                    # a classification tool, D holds individual functions.
                       # Conflating the three would inflate "families" — the
                       # figure this table offers as its diversity measure.

const GROUPS = Group[
    Group("A1", "A1", "Algebraic constructions", "Monomial (power) families",
          "Monomial (power)", "family", "families"),
    Group("A2", "A2", "Algebraic constructions", "Polynomial and multinomial families",
          "Polynomial / multinomial", "family", "families"),
    Group("A3", "A3", "Algebraic constructions", "Bivariate and biprojective constructions",
          "Bivariate / biprojective", "family", "families"),
    Group("A4", "A4", "Algebraic constructions", "Isotopic-shift, switching and coset modification",
          "Isotopic shift / switching", "family", "families"),
    Group("B1", "B1", "Computational search", "QAM-based search", "QAM search", "family", "families"),
    Group("B2", "B2", "Computational search", "Recursive tree and trim/extension search",
          "Tree / trim search", "family", "families"),
    Group("B3", "B3", "Computational search", "Restricted-coefficient exhaustive classification",
          "Restricted-coeff.\\ sweep", "family", "families"),
    Group("B4", "B4", "Computational search", "Published targeted enumerations",
          "Published lists", "family", "families"),
    Group("C", "C", "Equivalence classification", "CCZ-class representative sets",
          "CCZ representatives", "representative set", "representative sets"),
    Group("D", "D", "Sporadic results", "Individual case studies", "Sporadic cases", "case study", "case studies"),
]
const GROUP_ORDER = [g.key for g in GROUPS]

# family key => (group key, display name, bib keys)
struct Family
    key::String
    group::String
    name::String
    cites::Vector{String}
end

const FAMILIES = Family[
    Family("gold", "A1", "Gold \$x^{2^i+1}\$", ["Gold_196801"]),
    Family("kasami", "A1", "Kasami \$x^{2^{2i}-2^i+1}\$", ["Kasami_197105", "Nyberg_199400"]),
    Family("welch", "A1", "Welch \$x^{2^t+3}\$", ["Dobbertin_199905b"]),
    Family("niho", "A1", "Niho", ["Dobbertin_199905"]),
    Family("welchniho", "A1", "Welch\\,\$\\equiv\$\\,Niho at \$n=9\$", ["Dobbertin_199905", "Dobbertin_199905b"]),
    Family("inverse", "A1", "Inverse \$x^{2^n-2}\$, \$n\$ odd", ["Nyberg_199400"]),
    Family("dobbertin", "A1", "Dobbertin, \$n=5i\$", ["Dobbertin_200100"]),
    Family("bclbin", "A2", "Budaghyan--Carlet--Leander binomial, \$n=4k\$", ["Budaghyan_200809"]),
    Family("bcpbin", "A2", "Budaghyan--Carlet--Pott binomial, \$n=3k\$", ["Budaghyan_200603"]),
    Family("bcl09", "A2", "Budaghyan--Carlet--Leander 2009 trace polynomial", ["Budaghyan_200910"]),
    Family("taniguchi", "A2", "Taniguchi quadratic family", ["Taniguchi_201909"]),
    Family("kim", "A2", "Kim function and Dillon permutation", ["Browning_201000"]),
    Family("cbc21", "A3", "Calderini--Budaghyan--Carlet 2021, Thm.\\,6.2", ["Calderini_202100"]),
    Family("clv23f1", "A3", "Calderini--Li--Villa 2023, family \$F_1\$", ["Calderini_202306"]),
    Family("clv23f2", "A3", "Calderini--Li--Villa 2023, family \$F_2\$", ["Calderini_202306"]),
    Family("tppa25", "A4", "Taniguchi et al.\\ 2025, Ex.\\,4.2 (codim.\\,2)", ["Taniguchi_202501"]),
    Family("qam14", "B1", "Yu--Wang--Li 2014 QAM search", ["Yu_201411"]),
    Family("qam22", "B1", "Yu--Perrin 2022 QAM search", ["Yu_202211"]),
    Family("bl22", "B2", "Beierle--Leander 2022 tree search", ["Beierle_202201"]),
    Family("blp22", "B2", "Beierle--Leander--Perrin 2022 trims/extensions", ["Beierle_202201"]),
    Family("blp25", "B2", "Beierle et al.\\ 2025 large-scale search", ["Beierle_202508"]),
    Family("sb", "B3", "Simon--Berg \$\\mathrm{GF}(4)\$-coefficient sweep", String[]),
    Family("ep09list", "B4", "Edel--Pott 2009 quadratic list", ["Edel_200900"]),
    Family("wtg13", "B4", "Weng--Tan--Gong 2013 list", ["WengTanGong_201300"]),
    Family("sboxu", "C", "\\texttt{sboxU} quadratic-APN CCZ representatives", String[]),
    Family("sbreps", "C", "Simon--Berg \$\\mathrm{GF}(4)\$ CCZ representatives", String[]),
    Family("yu20", "D", "Yu et al.\\ 2020 representatives", ["Yu_202012"]),
    Family("bcl08sp", "D", "Budaghyan--Carlet--Leander 2008 rep., \$n=9\$", ["Budaghyan_200809"]),
    Family("ep09sp", "D", "Edel--Pott 2009 rep., \$n=9\$", ["Edel_200900"]),
]
# Short, math-free labels, used where a tall superscript would make the row
# heights uneven (the appendix).
const FAMSHORT = Dict(
    "gold" => "Gold", "kasami" => "Kasami", "welch" => "Welch", "niho" => "Niho",
    "welchniho" => "Welch/Niho", "inverse" => "Inverse", "dobbertin" => "Dobbertin",
    "bclbin" => "Budaghyan--Carlet--Leander binomial",
    "bcpbin" => "Budaghyan--Carlet--Pott binomial",
    "bcl09" => "Budaghyan--Carlet--Leander 2009 trace polynomial",
    "taniguchi" => "Taniguchi quadratic family",
    "kim" => "Kim / Dillon",
    "cbc21" => "Calderini--Budaghyan--Carlet 2021, Thm.\\,6.2",
    "clv23f1" => "Calderini--Li--Villa 2023, family F1",
    "clv23f2" => "Calderini--Li--Villa 2023, family F2",
    "tppa25" => "Taniguchi et al.\\ 2025, Ex.\\,4.2",
    "qam14" => "Yu--Wang--Li 2014 QAM search",
    "qam22" => "Yu--Perrin 2022 QAM search",
    "bl22" => "Beierle--Leander 2022 tree search",
    "blp22" => "Beierle--Leander--Perrin 2022 trims/extensions",
    "blp25" => "Beierle et al.\\ 2025 large-scale search",
    "sb" => "Simon--Berg GF(4) sweep",
    "ep09list" => "Edel--Pott 2009 quadratic list",
    "wtg13" => "Weng--Tan--Gong 2013 list",
    "sboxu" => "sboxU CCZ representatives",
    "sbreps" => "Simon--Berg GF(4) CCZ representatives",
    "yu20" => "Yu et al.\\ 2020 representatives",
    "bcl08sp" => "Budaghyan--Carlet--Leander 2008 rep.",
    "ep09sp" => "Edel--Pott 2009 rep.",
)

const FAMKEYS = [f.key for f in FAMILIES]
const FAMBY = Dict(f.key => f for f in FAMILIES)

for f in FAMILIES, k in f.cites
    k in BIB_KEYS || error("family $(f.key) cites unknown bib key $k")
end
for f in FAMILIES
    haskey(FAMSHORT, f.key) || error("family $(f.key) has no short label")
end

# --- pattern rules, most specific first ------------------------------------
const NAME_RULES = Pair{Regex,String}[
    r"_Taniguchi2025_"          => "tppa25",
    r"_Calderini2021_thm62"     => "cbc21",
    r"_CalderiniLiVilla2023_F1" => "clv23f1",
    r"_CalderiniLiVilla2023_F2" => "clv23f2",
    r"_Budaghyan2009_eq"        => "bcl09",
    r"_Welch_Niho_"             => "welchniho",
    r"_Gold_"                   => "gold",
    r"_Kasami_"                 => "kasami",
    r"_Welch"                   => "welch",
    r"_Niho"                    => "niho",
    r"_Inverse"                 => "inverse",
    r"_Dobbertin"               => "dobbertin",
    r"_BCL_k\d"                 => "bclbin",
    r"_BCP_k\d"                 => "bcpbin",
    r"_Taniguchi_m\d"           => "taniguchi",
    r"_Kim$"                    => "kim",
    r"_Dillon_permutation"      => "kim",
    r"^reprs\d+_"               => "sboxu",
    r"^eightBitAPN_"            => "sboxu",
    r"^SimonBerg_GF4_"          => "sbreps",
    r"_Yu2020_"                 => "yu20",
    r"_BCL2008_"                => "bcl08sp",
    r"_EdelPott2009_"           => "ep09sp",
]

function family_of_name(name::AbstractString)
    for (re, key) in NAME_RULES
        occursin(re, name) && return key
    end
    error("no family rule matches catalog name $(repr(name)) — " *
          "add a rule to NAME_RULES rather than dropping the object")
end

const CORPUS_RULES = Dict(
    "yuwangli2014_qam_n8"         => "qam14",
    "yuperrin2022_qam_n8"         => "qam22",
    "beierleleander2022_n8"       => "bl22",
    "beierleleanderperrin2022_n8" => "blp22",
    "beierle2025_n8"              => "blp25",
    "simonberg_gf4_n8"            => "sb",
    "edelpott2009_n8"             => "ep09list",
    "wengtangong2013_n8"          => "wtg13",
    # Registered under `bulk_corpora`, but it is a family instantiation, not a
    # search: the two a != 0 CCZ classes generated by `taniguchi_apn`.
    "taniguchi2019_n8"            => "taniguchi",
)
function family_of_corpus(name::AbstractString)
    haskey(CORPUS_RULES, name) ||
        error("no family rule for corpus $(repr(name))")
    CORPUS_RULES[name]
end

# --- apply ------------------------------------------------------------------
const CURATED_NAMES = Set(c.name for c in curated)

fam_curated = Dict(k => Curated[] for k in FAMKEYS)
for c in curated
    push!(fam_curated[family_of_name(c.name)], c)
end

# A `functions` row whose canonical_name is a curated TOML name is the SAME
# object; it is counted once, as curated.
fam_indexed = Dict(k => DbFn[] for k in FAMKEYS)
for f in dbfns
    isempty(f.canonical_name) && error("APN `functions` row $(f.id) has no canonical_name")
    f.canonical_name in CURATED_NAMES && continue
    push!(fam_indexed[family_of_name(f.canonical_name)], f)
end

fam_corpora = Dict(k => Corpus[] for k in FAMKEYS)
for c in corpora
    push!(fam_corpora[family_of_corpus(c.name)], c)
end

# named entries whose CCZ class was decided in-repo
db_by_name = Dict(f.canonical_name => f for f in dbfns)
function ccz_decided_count(key)
    n = 0
    for c in fam_curated[key]
        haskey(db_by_name, c.name) && db_by_name[c.name].id in ccz_decided && (n += 1)
    end
    for f in fam_indexed[key]
        f.id in ccz_decided && (n += 1)
    end
    n
end

fam_named(key) = length(fam_curated[key]) + length(fam_indexed[key])
fam_inst(key) = isempty(fam_corpora[key]) ? 0 : sum(c.members for c in fam_corpora[key])
function fam_dims(key)
    d = Set{Int}()
    for c in fam_curated[key]; push!(d, c.n); end
    for f in fam_indexed[key]; push!(d, f.n); end
    for c in fam_corpora[key]; push!(d, c.n); end
    d
end
function fam_perms(key)
    n = count(c -> curated_perm[c.name], fam_curated[key])
    n += count(f -> f.is_permutation, fam_indexed[key])
    n += sum(Int[corpus_checks[c.name].permutation for c in fam_corpora[key]]; init = 0)
    n
end

for k in FAMKEYS
    fam_named(k) + fam_inst(k) > 0 ||
        error("family $k has no catalogued object — remove the row or fix the rules")
end

# ===========================================================================
# 4.  EVIDENCE LEDGER — every status symbol is backed by a verbatim quotation
# ===========================================================================

println("[4/8] verifying the evidence ledger against tracked sources")

# status marks
const CONF = :conf   # recomputed here and confirmed
const PART = :part   # partially recomputed
const DIVG = :divg   # recomputed, divergence found (E-code required)
const BEY  = :bey    # outside the reach of the current reference implementation
const OPEN = :open   # claim exists, no in-repo recomputation recorded
const NA   = :na     # no such claim / not applicable

struct Evidence
    file::String       # repo-relative
    quote_::String     # literal substring that must occur in that file
end

struct Cell
    mark::Symbol
    ecode::String              # "" unless mark == DIVG against a publication
    ev::Vector{Evidence}
    note::String               # footnote text, "" for none
    against::Symbol            # :paper | :catalog — only meaningful when mark == DIVG
end

cell(mark; ecode = "", ev = Evidence[], note = "", against = :paper) =
    Cell(mark, ecode, ev, note, against)

# Evidence reused across many rows -------------------------------------------
const EV_LOADER = Evidence(
    "packages/VBFCatalog/data-raw/apn_catalog/README.md",
    "the loader verifies APN-ness and refuses entries that fail")
const EV_KNOWNFAM = Evidence(
    "packages/VBFCatalog/data-build/import_known_families.jl",
    "differential_uniformity(s) == 2 || return          # never trust the name")
const EV_SPORADIC = Evidence(
    "packages/VBFCatalog/data-build/import_sporadic_known.jl",
    "Every candidate is re-verified differential_uniformity == 2 before writing")
const EV_REPS = Evidence(
    "packages/VBFCatalog/data-build/import_apn_reps.jl",
    "if differential_uniformity(s) != 2")
const EV_BULKAPN = Evidence(
    "packages/VBFCatalog/data-build/import_quadratic_apn_8bit.jl",
    "if differential_uniformity(F) == 2 && algebraic_degree(F) == 2")
const EV_SIGMA = Evidence(
    "packages/VBFCatalog/src/data/sigma.jl",
    "split each multi-member bucket into true CCZ classes")
const EV_SBREP = Evidence(
    "packages/VBFCatalog/data-build/import_simonberg.jl",
    "error(\"simonberg: class \$class representative not APN\")")
const EV_GUARD = Evidence(
    "packages/VBF/src/invariants/design_ranks.jl",
    "design ranks need a 2^\$(2N) × 2^\$(2N) matrix; n ≤ 7 supported")

# Per-family status.  A/I/E/N in that order.
#   A  the APN property itself
#   I  published invariants
#   E  equivalence / classification claims
#   N  novelty claims
const STATUS = Dict{String,NTuple{4,Cell}}()

# --- A1 monomial families ---------------------------------------------------
# A: recomputed by this generator for every entry (section 2), and re-verified
#    at catalog build time by the loader and the family importer.
# I/N: the catalog records attach no published-invariant and no novelty claim to
#    these classical families.
# E: the in-repo CCZ decision only accepts quadratic APN functions, so the power
#    maps of odd algebraic degree lie outside it — a mechanical, derived fact.
monomial_E(key) = ccz_decided_count(key) == fam_named(key) ? CONF :
                  ccz_decided_count(key) == 0 ? BEY : PART

for k in ("gold", "kasami", "welch", "niho", "welchniho", "inverse", "dobbertin")
    STATUS[k] = (
        cell(CONF; ev = [EV_LOADER, EV_KNOWNFAM]),
        cell(NA),
        cell(monomial_E(k); ev = [EV_SIGMA, EV_GUARD],
             note = k == "kasami" ?
                 "kasami-n6" : ""),
        cell(NA),
    )
end

# --- A2 polynomial / multinomial families -----------------------------------
STATUS["bclbin"] = (cell(CONF; ev = [EV_KNOWNFAM]), cell(NA),
                    cell(monomial_E("bclbin"); ev = [EV_SIGMA]), cell(NA))
STATUS["bcpbin"] = (cell(CONF; ev = [EV_KNOWNFAM]), cell(NA),
                    cell(monomial_E("bcpbin"); ev = [EV_SIGMA]), cell(NA))

STATUS["bcl09"] = (
    cell(CONF; ev = [Evidence("packages/VBFCatalog/data-raw/apn_catalog/n9_apn.toml",
        "Re-verified APN (differential uniformity 2, algebraic degree 2)")]),
    cell(NA),
    cell(PART; ev = [Evidence("packages/VBFCatalog/data-raw/apn_catalog/n9_apn.toml",
        "exhaustive in-repo CCZ is intractable at n=9"), EV_SIGMA], note = "bcl09-E"),
    cell(PART; ev = [Evidence("papers/2009/Budaghyan_200910/README.md",
        "an under-verified novelty claim")], note = "bcl09-N"),
)

STATUS["taniguchi"] = (
    cell(CONF; ev = [EV_KNOWNFAM, EV_BULKAPN]),
    cell(NA),
    cell(monomial_E("taniguchi"); ev = [EV_SIGMA]),
    cell(OPEN; ev = [Evidence("papers/2019/Taniguchi_201909/README.md",
        "these are provenance gaps, not world-novelty")], note = "taniguchi-N"),
)

STATUS["kim"] = (
    cell(CONF; ev = [Evidence("packages/VBFCatalog/data-raw/apn_catalog/n6_apn.toml",
        "CCZ-inequivalent to n6_Gold_x3 and n6_Kasami_x48 (verified via are_ccz_equivalent)")]),
    cell(NA),
    cell(monomial_E("kim"); ev = [Evidence(
        "packages/VBFCatalog/data-raw/apn_catalog/n6_apn.toml",
        "verified via are_ccz_equivalent"), EV_SIGMA], note = "kim-E"),
    cell(NA),
)

# --- A3 bivariate / biprojective --------------------------------------------
STATUS["cbc21"] = (
    cell(CONF; ev = [Evidence("packages/VBFCatalog/data-raw/apn_catalog/n8_apn.toml",
        "Re-verified APN (differential_uniformity=2, algebraic_degree=2)")]),
    cell(NA),
    cell(CONF; ev = [Evidence("papers/2021/Calderini_202100/README.md",
        "The 10 APN pairs form **exactly one** EA class by ortho-derivative signature")]),
    cell(PART; ev = [Evidence("papers/2021/Calderini_202100/README.md",
        "of inequivalence to the external n=8 tables of [52] and [53] is **unverifiable** here")],
        note = "cbc21-N"),
)

for (k, invq) in ("clv23f1" => "N_F invariant [1365, 100100, 140664] (matches paper Table 3)",
                  "clv23f2" => "N_F invariant [1365, 100100, 144198, 192] (matches paper Table 3)")
    STATUS[k] = (
        cell(CONF; ev = [Evidence("packages/VBFCatalog/data-raw/apn_catalog/n12_apn.toml",
            "APN (differential_uniformity=2, algebraic_degree=2) re-verified")]),
        cell(CONF; ev = [Evidence("packages/VBFCatalog/data-raw/apn_catalog/n12_apn.toml", invq)]),
        cell(CONF; ev = [Evidence("packages/VBFCatalog/data-raw/apn_catalog/n12_apn.toml",
            "establishing CCZ/EA-inequivalence"), EV_SIGMA]),
        cell(CONF; ev = [Evidence("papers/2023/Calderini_202306/README.md",
            "including all 11 known-family rows of Table 3, the two new rows for F1 and\nF2, and the novelty argument that rests on them")],
            note = "clv23-N"),
    )
end

# --- A4 isotopic shift / coset modification ---------------------------------
# E carries the only divergence mark in the table, and it is decided at [2d/8]
# above rather than quoted.  The divergence is against THIS CATALOG's provenance
# record — which attributes the entry to the 2025 paper alone and carries no
# prior-art key — and not against the 2025 paper, which claims only
# EA-inequivalence to x^3 and asserts no novelty.  It therefore carries no
# E-code: that taxonomy classifies claims made in a publication.
const EV_EQ6 = Evidence("papers/2009/Budaghyan_200910/README.md",
    "**byte-identical**\nto the existing catalog entry `n8_Taniguchi2025_ex4_2`")

STATUS["tppa25"] = (
    cell(CONF; ev = [Evidence("packages/VBFCatalog/data-raw/apn_catalog/n8_apn.toml",
        "Re-verified in-repo: differential_uniformity = 2, algebraic_degree = 2")]),
    cell(BEY; ev = [Evidence("packages/VBFCatalog/data-raw/apn_catalog/n8_apn.toml",
        "Gamma-rank is refused by the n>=8 design-rank guard"), EV_GUARD],
        note = "tppa25-I"),
    # If the decision does not terminate, fall back to what a mugshot match on
    # its own supports: a necessary condition, i.e. a partial recomputation.
    (eq6_decided && eq6_equivalent) ?
        cell(DIVG; against = :catalog, ev = [EV_EQ6], note = "tppa25-E") :
        cell(PART; ev = [EV_EQ6], note = "tppa25-E-open"),
    cell(NA; note = "tppa25-N"),
)

# --- B1 QAM search ----------------------------------------------------------
STATUS["qam14"] = (
    cell(CONF; ev = [EV_BULKAPN]),
    cell(OPEN; note = "qam14-I"),
    cell(PART; ev = [Evidence("packages/VBFCatalog/src/data/sigma.jl",
        "bucket by (n, σ) — a necessary condition, cheap")], note = "sigma-only"),
    cell(OPEN),
)
STATUS["qam22"] = (
    cell(CONF; ev = [EV_BULKAPN, Evidence("papers/2022/Yu_202211d/README.md",
        "All 5412 members are APN")]),
    cell(CONF; ev = [Evidence("papers/2022/Yu_202211d/README.md",
        "W₁ = 5084, W₂ = 324, W₃ = 4** —\n    *exactly* the paper's Section 3.2 multiplicities")]),
    cell(CONF; ev = [Evidence("papers/2022/Yu_202211d/README.md",
        "5412 distinct\n    (Walsh, differential) pairs**, exactly the paper's \"5412 new EA-equivalence classes\"")]),
    cell(OPEN; note = "qam22-N"),
)

# --- B2 tree / trim search --------------------------------------------------
STATUS["bl22"] = (
    cell(CONF; ev = [EV_BULKAPN]),
    cell(CONF; ev = [Evidence("papers/2022/Beierle_202201/README.md",
        "**exactly six** distinct extended Walsh spectra — exactly the paper's 𝒲₀…𝒲₅")]),
    cell(PART; ev = [Evidence("papers/2022/Beierle_202201/README.md",
        "**pairwise distinct ortho-derivative differential spectra**, so they are pairwise\n  CCZ-inequivalent")],
        note = "bl22-E"),
    cell(OPEN; ev = [Evidence("papers/2022/Beierle_202201/README.md",
        "not separable from the corpus without the authors' provenance labels")],
        note = "bl22-N"),
)
STATUS["blp22"] = (
    cell(CONF; ev = [EV_BULKAPN]),
    cell(OPEN),
    cell(PART; ev = [Evidence("packages/VBFCatalog/src/data/sigma.jl",
        "bucket by (n, σ) — a necessary condition, cheap")], note = "sigma-only"),
    cell(OPEN),
)

# --- B3 restricted-coefficient exhaustive -----------------------------------
STATUS["sb"] = (
    cell(CONF; ev = [EV_SBREP]),
    cell(NA),
    cell(PART; ev = [EV_SBREP, EV_SIGMA], note = "sb-E"),
    cell(NA),
)

# --- B4 published targeted enumerations -------------------------------------
STATUS["ep09list"] = (
    cell(CONF; ev = [EV_BULKAPN]),
    cell(OPEN; ev = [Evidence("papers/2009/Edel_200900/README.md",
        "**could not run**: no `julia` on this host")], note = "nojulia"),
    cell(PART; ev = [Evidence("packages/VBFCatalog/src/data/sigma.jl",
        "bucket by (n, σ) — a necessary condition, cheap")], note = "sigma-only"),
    cell(OPEN; ev = [Evidence("papers/2009/Edel_200900/README.md",
        "**could not run**: no `julia` on this host")], note = "nojulia"),
)
STATUS["wtg13"] = (
    cell(CONF; ev = [EV_BULKAPN]),
    cell(OPEN),
    cell(PART; ev = [Evidence("packages/VBFCatalog/src/data/sigma.jl",
        "bucket by (n, σ) — a necessary condition, cheap")], note = "sigma-only"),
    cell(OPEN),
)

# --- C equivalence classification -------------------------------------------
STATUS["sboxu"] = (
    cell(CONF; ev = [EV_REPS]),
    cell(NA),
    cell(monomial_E("sboxu"); ev = [EV_SIGMA], note = "sboxu-E"),
    cell(NA),
)
STATUS["sbreps"] = (
    cell(CONF; ev = [EV_SBREP]),
    cell(NA),
    cell(monomial_E("sbreps"); ev = [EV_SIGMA]),
    cell(NA),
)

# --- D sporadic -------------------------------------------------------------
STATUS["yu20"] = (
    cell(CONF; ev = [EV_SPORADIC]),
    cell(NA),
    cell(monomial_E("yu20"); ev = [EV_SIGMA]),
    # E4, not E1.  The duplicated row is the mechanism; the consequence is that
    # one of the fifteen class representatives is absent from the published
    # table altogether and had to be recovered by exhaustive search.  E1 is
    # explicitly reserved for a defect that touches "only readability", which
    # this does not: part of the reported classification cannot be read off the
    # paper at all.
    cell(DIVG; ecode = "E4", ev = [Evidence("papers/2020/Yu_202012/README.md",
        "Rows 4 and 10 of Table 2 are both `x³+x⁹+x¹⁸+x⁶⁶`")], note = "yu20-N"),
)
STATUS["bcl08sp"] = (cell(CONF; ev = [EV_SPORADIC]), cell(NA),
                     cell(monomial_E("bcl08sp"); ev = [EV_SIGMA]), cell(NA))
STATUS["ep09sp"] = (cell(CONF; ev = [EV_SPORADIC]), cell(NA),
                    cell(monomial_E("ep09sp"); ev = [EV_SIGMA]),
                    cell(OPEN; ev = [Evidence("papers/2009/Edel_200900/README.md",
                        "**could not run**: no `julia` on this host")], note = "nojulia"))

for k in FAMKEYS
    haskey(STATUS, k) || error("family $k has no A/I/E/N status")
end

# Footnote attached to the reference column of a row whose source carries no
# `bib_key` anywhere in the catalog.
const REFNOTE = Dict("sb" => "nobib", "sboxu" => "nobib", "sbreps" => "nobib")

# --- footnotes --------------------------------------------------------------
const FOOTNOTES = Dict(
    "nobib" => "These sets carry no \\texttt{bib\\_key} in the catalog: \\texttt{bulk\\_corpora.bib\\_key} and \\texttt{functions.bib\\_key} are \\textsc{null} for every one of their rows, so no citation is printed rather than one invented. The upstream sources are named in \\texttt{data-build/sources.toml} as the Simon--Berg thesis and the \\texttt{sboxU} repository.",
    "kasami-n6" => "\\texttt{n6\\_Kasami\\_x48} is not a distinct CCZ class: \$48 \\equiv 3\\cdot 2^4 \\bmod 63\$, and the catalog records \\texttt{are\\_ea\\_equivalent} and \\texttt{are\\_ccz\\_equivalent} both returning true against \\texttt{n6\\_Gold\\_x3}. The in-repo CCZ index places both, and four further \$n=6\$ entries, in one class.",
    "bcl09-E" => "The two \$n=9\$ entries sit in distinct in-repo CCZ classes, and in classes distinct from every \$n=9\$ Gold entry. Inequivalence to the non-quadratic AB power maps at \$n=9\$ is taken from the source paper's \$\\Gamma\$-rank argument; the catalog states that an exhaustive in-repo CCZ decision is intractable at \$n=9\$.",
    "bcl09-N" => "The reproduction review of this paper records that its own test suite could not be executed for want of a Julia toolchain, so the novelty comparison it reports is not an in-repo recomputation.",
    "taniguchi-N" => "The reproduction review reports \\texttt{classify\\_ccz} returning \\texttt{:known} for all three \$n=8\$ representatives, so no novelty is asserted for them here.",
    "kim-E" => "CCZ-inequivalence of the Kim function to both \$n=6\$ power entries is recorded as verified in-repo. The Dillon permutation itself has algebraic degree 4 and therefore lies outside the quadratic-only in-repo CCZ decision.",
    "cbc21-N" => "Inequivalence to Gold, hexanomial, Taniguchi and Zhou--Pott at \$n=8\$ was confirmed independently; the paper's further claim of inequivalence to two external \$n=8\$ tables is recorded as unverifiable here because those corpora are not in the repository.",
    "clv23-N" => "Novelty is established against the eleven known-family rows of the paper's own Table 3, all of which were recomputed. The check is not exercised by the reproduction's test suite.",
    "tppa25-I" => "The published \$\\Gamma\$-ranks are refused by the library's \$n\\ge 8\$ design-rank guard. The repository is inconsistent on this point: the reproduction review first records the value as verified, then reverses that in a later re-review, while the catalog entry states it is not verified. The guard in \\texttt{packages/VBF} is unchanged.",
    "tppa25-E" => "This entry is EA-equivalent, hence CCZ-equivalent, to Budaghyan--Carlet--Leander 2009 eq.\\,(6) with \$a=\\alpha\$ over \$\\mathrm{GF}(2^8)\$. The generator decides this on every run with \\texttt{are\\_ea\\_equivalent}, which is complete on the quadratic APN class; the two lookup tables are not identical, because the constructions use different moduli. The reproduction review of the 2009 paper had established only that the two ortho-derivative mugshots agree --- a necessary condition --- and had left the decision open. \\emph{The divergence is against this catalog's provenance record}, which attributes the entry to 2025 alone and carries no prior-art key. It is not a divergence against the 2025 paper, which claims only EA-inequivalence to \$x^3\$ and asserts no novelty; that is why the cell carries no E-code. The catalog entry needs a cross-reference to the 2009 construction. This table reports the collision and does not change the catalog.",
    "tppa25-E-open" => "The ortho-derivative mugshot of this entry agrees with that of Budaghyan--Carlet--Leander 2009 eq.\\,(6) with \$a=\\alpha\$ over \$\\mathrm{GF}(2^8)\$, which is a necessary condition for EA-equivalence and not a decision. The complete EA test did not terminate on this run, so the collision is not asserted.",
    "tppa25-N" => "The entry itself states that absence from this catalog is not a claim of novelty in the literature, and that the paper claims only EA-inequivalence to \$x^3\$.",
    "sigma-only" => "Every member is indexed by its ortho-derivative signature, which this repository computes from the function. That signature is a necessary condition for CCZ-equivalence, not a decision, and the members are not partitioned into confirmed CCZ classes.",
    "qam14-I" => "The corpus registry labels this set ``8{,}157 APN functions'' while the side store holds \\corpusYWL{} members after one non-quadratic member was excluded at import. The repository carries no analysis that reconciles the two figures.",
    "qam22-N" => "The count of pairwise distinct EA classes reproduces exactly; that the classes are new relative to the earlier corpora is not recomputed here.",
    "bl22-E" => "Four members were shown pairwise CCZ-inequivalent by their ortho-derivative differential spectra. The remaining members carry ortho-derivative signatures only.",
    "bl22-N" => "The reproduction records the switching sub-family as not separable from the corpus without the authors' provenance labels, and the paper's \$n=9\$ and \$n=10\$ instances as absent from the repository.",
    "sb-E" => "The 27 class representatives are named entries with an in-repo confirmed CCZ class. The assignment of all \\corpusSB{} members to those 27 classes is taken from the source and is not recomputed here.",
    "sboxu-E" => "Two of the imported representatives are not quadratic and therefore lie outside the in-repo CCZ decision.",
    "yu20-N" => "The reproduction reports rows 4 and 10 of the source table as the same polynomial, so the table lists 14 distinct entries where the classification has 15 classes; the missing class was recovered by exhaustive search in the reproduction.",
    "nojulia" => "The reproduction review of this source records that its test suite could not be executed for want of a Julia toolchain, so no figure it reports is an in-repo recomputation.",
)

# --- verify every quotation --------------------------------------------------
# Quotations are matched after collapsing every whitespace run to one space, so
# that a re-wrapped line in a source file cannot silently drop a status symbol
# while a genuine wording change still fails the check.
const FILE_CACHE = Dict{String,String}()
readsrc(p) = get!(FILE_CACHE, p) do
    f = repopath(split(p, "/")...)
    isfile(f) || error("evidence file missing: $p")
    wsnorm(read(f, String))
end

n_ev = 0
n_ev_files = Set{String}()
for k in FAMKEYS, c in STATUS[k]
    for e in c.ev
        occursin(wsnorm(e.quote_), readsrc(e.file)) ||
            error("EVIDENCE FAILED for family $k: the string\n  $(repr(e.quote_))\n" *
                  "does not occur in $(e.file)")
        global n_ev += 1
        push!(n_ev_files, e.file)
    end
    # An E-code classifies a divergence against a PUBLICATION.  A divergence
    # against this catalog's own provenance record is a different object and
    # must not borrow the taxonomy: it carries no E-code and must explain
    # itself in a note.
    if c.mark == DIVG
        if c.against === :paper
            isempty(c.ecode) &&
                error("family $k: divergence against the publication with no E-code")
        elseif c.against === :catalog
            isempty(c.ecode) ||
                error("family $k: a divergence against the catalog record must not " *
                      "carry an E-code (the taxonomy classifies published claims)")
            isempty(c.note) &&
                error("family $k: a divergence against the catalog record needs a note")
        else
            error("family $k: unknown divergence target $(c.against)")
        end
    end
    isempty(c.note) || haskey(FOOTNOTES, c.note) ||
        error("family $k references undefined footnote $(c.note)")
end
println("      $n_ev quotations verified across $(length(n_ev_files)) tracked files")

# marks that must be supported by at least one quotation
for k in FAMKEYS, c in STATUS[k]
    if c.mark in (CONF, PART, DIVG, BEY) && isempty(c.ev)
        error("family $k has mark $(c.mark) with no evidence")
    end
end

# ===========================================================================
# 5.  kind -> E1..E5 mapping, cross-checked against audit/findings.yaml
# ===========================================================================

const KIND_TO_ECODE = Dict(
    "tool_limit" => "E5", "hard_limit" => "E5", "theory_limit" => "E5",
    "sampling_not_exhaustion" => "E4", "scope_restriction" => "E4",
    "unsound_negative" => "E3", "unproved_premise" => "E3",
    "wrong_condition" => "E2",
    "wrong_value" => "E2",              # E1 only at tier paper_confirmed + low severity
    "internal_inconsistency" => "E2",   # E1 only at low severity
    "inferred" => "--",
)

function ecode_for(kind::AbstractString, tier::AbstractString, severity::AbstractString)
    kind == "inferred" && return "--"
    kind == "wrong_value" && return (tier == "paper_confirmed" && severity == "low") ? "E1" : "E2"
    kind == "internal_inconsistency" && return severity == "low" ? "E1" : "E2"
    get(KIND_TO_ECODE, kind, "--")
end

findings_summary = ""
if isfile(FINDINGS)
    txt = read(FINDINGS, String)
    ids = [m.captures[1] for m in eachmatch(r"^  - id: (\S+)"m, txt)]
    kinds = [m.captures[1] for m in eachmatch(r"^    kind: (\S+)"m, txt)]
    tiers = [m.captures[1] for m in eachmatch(r"^    verification_tier: (\S+)"m, txt)]
    sevs = [m.captures[1] for m in eachmatch(r"^    severity: (\S+)"m, txt)]
    if length(ids) == length(kinds) == length(tiers) == length(sevs)
        tally = Dict{String,Int}()
        for i in eachindex(ids)
            e = ecode_for(kinds[i], tiers[i], sevs[i])
            tally[e] = get(tally, e, 0) + 1
        end
        findings_summary = join(["$k=$(tally[k])" for k in sort(collect(keys(tally)))], " ")
        println("      audit/findings.yaml (UNTRACKED, cross-check only): " *
                "$(length(ids)) findings -> $findings_summary")
    else
        println("      audit/findings.yaml present but field counts disagree; skipped")
    end
else
    println("      audit/findings.yaml absent — mapping cross-check skipped " *
            "(no emitted file depends on it)")
end

# ===========================================================================
# 6.  emit the table body
# ===========================================================================

println("[5/8] writing manuscript/generated/table_main.tex")

const MARKSYM = Dict(CONF => "\\apnConf", PART => "\\apnPart", DIVG => "\\apnDiv",
                     BEY => "\\apnBey", OPEN => "\\apnOpen", NA => "\\apnNA")

# footnote letters, allocated in first-print order so the table reads top-down
const FN_ORDER = String[]
function fnmark(key::AbstractString)
    isempty(key) && return ""
    key in FN_ORDER || push!(FN_ORDER, key)
    "\\tnote{" * string('a' + findfirst(==(key), FN_ORDER) - 1) * "}"
end

function cellsym(c::Cell)
    s = MARKSYM[c.mark]
    # Only a divergence against a PUBLICATION carries an E-code; a divergence
    # against the catalog's own record has none, and must not emit an empty box.
    isempty(c.ecode) ||
        (s *= "\\,\\textsc{\\scriptsize " * lowercase(c.ecode) * "}")
    s * fnmark(c.note)
end

function citefield(f::Family)
    isempty(f.cites) && return "\\textemdash" * fnmark(get(REFNOTE, f.key, ""))
    "\\cite{" * join(f.cites, ",") * "}"
end

function permfield(key)
    total = fam_named(key) + fam_inst(key)
    p = fam_perms(key)
    p == 0 && return "\\textendash"
    p == total && return "all"
    string(p)
end

header = """
% !!! GENERATED FILE — DO NOT EDIT !!!
% Produced by $GENERATOR from, in order of authority:
%   packages/VBFCatalog/data-raw/apn_catalog/n{4,5,6,7,8,9,10,12}_apn.toml
%   packages/VBFCatalog/data-raw/bibliography.bib
%   packages/VBFCatalog/BFA_catalog.sqlite   (functions, bulk_corpora,
%                                             equivalence_classes, class_members)
%   packages/VBFCatalog/corpora/*.sqlite
%   packages/VBFCatalog/data-build/*.jl, packages/VBF/src/**.jl
%   papers/<year>/<Paper_ID>/README.md
% Regenerate with:  julia --project=. -t auto $GENERATOR
"""

io = IOBuffer()
print(io, header)
# 10 columns: name | n | entries | instances | permutations | reference | A I E N
# NINE columns.  There is no column A.  The APN property is recomputed for
# every catalogued object (section 2) and the run ABORTS if one fails, so an
# A column could not take any value but "confirmed" on any row: a column that
# cannot vary carries no information.  The claim is not lost — it is stated in
# the caption, with the number of objects it covers, where it is stronger than
# 28 identical ticks and where it cannot be mistaken for the weaker evidence
# behind I, E and N.
println(io, "\\begin{tabular}{@{}l c r r c l ccc@{}}")
println(io, "\\toprule")
println(io, "\\textbf{Family or construction} & \\textbf{\$n\$} & \\textbf{Ent.} & " *
            "\\textbf{Inst.} & \\textbf{Perm.} & \\textbf{Ref.} & " *
            "\\multicolumn{3}{c}{\\textbf{Claim status}}\\\\")
println(io, "\\cmidrule(l){7-9}")
println(io, " & & & & & & \\textbf{I} & \\textbf{E} & \\textbf{N}\\\\")

plural(n, sing, plur) = "$(grouped(n)) " * (n == 1 ? sing : plur)
plural(n, w) = w == "entry" ? plural(n, "entry", "entries") :
                              plural(n, "instance", "instances")

lasttop = ""
for g in GROUPS
    keys_in = [f.key for f in FAMILIES if f.group == g.key]
    isempty(keys_in) && continue
    nent = sum(fam_named(k) for k in keys_in)
    ninst = sum(fam_inst(k) for k in keys_in)
    if g.top != lasttop
        println(io, "\\midrule")
        println(io, "\\multicolumn{9}{@{}l}{\\textbf{$(g.top)}}\\\\[1pt]")
        global lasttop = g.top
    else
        println(io, "\\addlinespace[2pt]")
    end
    println(io, "\\multicolumn{9}{@{}l}{\\quad\\emph{$(g.code)\\enspace $(g.title)} " *
                "\\hfill{\\footnotesize $(plural(length(keys_in), g.unit, g.unitp)), " *
                "$(plural(nent, "entry")), $(plural(ninst, "instance"))}}\\\\")
    println(io, "\\addlinespace[1pt]")
    for k in keys_in
        f = FAMBY[k]
        st = STATUS[k]
        ne = fam_named(k)
        ni = fam_inst(k)
        println(io, "\\quad $(f.name) & $(dimspec(fam_dims(k))) & " *
                    "$(ne == 0 ? "\\textendash" : grouped(ne)) & " *
                    "$(ni == 0 ? "\\textendash" : grouped(ni)) & " *
                    "$(permfield(k)) & $(citefield(f)) & " *
                    "$(cellsym(st[2])) & $(cellsym(st[3])) & $(cellsym(st[4]))\\\\")
    end
end

tot_ent = sum(fam_named(k) for k in FAMKEYS)
tot_inst = sum(fam_inst(k) for k in FAMKEYS)
println(io, "\\midrule")
println(io, "\\textbf{Total} & \\textbf{$(dimspec(union([fam_dims(k) for k in FAMKEYS]...)))} & " *
            "\\textbf{$(grouped(tot_ent))} & \\textbf{$(grouped(tot_inst))} & " *
            "\\textbf{$(grouped(sum(fam_perms(k) for k in FAMKEYS)))} & " *
            "& & & \\\\")
# The two count columns address two overlapping stores.  Printing their totals
# side by side on a row called "Total" invites exactly the addition the caption
# forbids, so the true combined figure goes on the next line, where it cannot be
# separated from the numbers it corrects.
println(io, "\\multicolumn{9}{@{}l}{\\footnotesize \\textbf{Ent.} and \\textbf{Inst.} " *
            "count two overlapping stores and do not add: the catalog holds " *
            "\\apnDistinct{} distinct functions.}\\\\")
println(io, "\\bottomrule")
println(io, "\\end{tabular}")
write(joinpath(OUT, "table_main.tex"), String(take!(io)))

# ===========================================================================
# 7.  footnotes, legend counts, heat-map data, appendix
# ===========================================================================

println("[6/8] writing manuscript/generated/table_notes.tex")
io = IOBuffer()
print(io, header)
for key in FN_ORDER
    println(io, "\\item[" * string('a' + findfirst(==(key), FN_ORDER) - 1) * "] " *
                FOOTNOTES[key])
end
write(joinpath(OUT, "table_notes.tex"), String(take!(io)))

# --- heat map ---------------------------------------------------------------
println("[7/8] writing manuscript/generated/heatmap.dat")

alldims = sort!(collect(union([fam_dims(k) for k in FAMKEYS]...)))
grouprow(gkey) = findfirst(==(gkey), GROUP_ORDER)

# A cell counts DISTINCT FUNCTIONS, addressed by the SHA-256 of the LUT, not
# stored rows: the same function is held in both stores 59 times over (a Simon
# --Berg class representative, for instance, is a named entry AND a member of
# the corpus it represents), and counting rows would inflate those cells.
cellset = Dict{Tuple{String,Int},Set{String}}()
decided = Dict{Tuple{String,Int},Int}()
# The CCZ decision runs on NAMED ENTRIES ONLY.  A cell holding nothing but
# corpus instances therefore has a numerator of zero by construction, which is
# not the same statement as "the decision was attempted and reached nothing".
# Printing a computed-looking `0` for a structural not-applicable is the same
# error as printing one glyph for two meanings, so the label below omits the
# ratio entirely where the decision does not apply.
namedcount = Dict{Tuple{String,Int},Int}()
addsha!(g, n, h) = push!(get!(cellset, (g, n), Set{String}()), h)
bumpnamed!(g, n) = (namedcount[(g, n)] = get(namedcount, (g, n), 0) + 1)
for f in FAMILIES
    for c in fam_curated[f.key]
        addsha!(f.group, c.n, curated_sha[c.name])
        bumpnamed!(f.group, c.n)
        if haskey(db_by_name, c.name) && db_by_name[c.name].id in ccz_decided
            decided[(f.group, c.n)] = get(decided, (f.group, c.n), 0) + 1
        end
    end
    for d in fam_indexed[f.key]
        addsha!(f.group, d.n, db_sha[d.id])
        bumpnamed!(f.group, d.n)
        d.id in ccz_decided && (decided[(f.group, d.n)] = get(decided, (f.group, d.n), 0) + 1)
    end
    for c in fam_corpora[f.key]
        for h in corpus_sha[c.name]
            addsha!(f.group, c.n, h)
        end
    end
end
records = Dict(k => length(v) for (k, v) in cellset)

io = IOBuffer()
print(io, header)
println(io, "% one row per (construction group, dimension) cell of Figure 1.")
println(io, "% col   dimension n")
println(io, "% row   construction group, 1 = top row of the figure")
println(io, "% logc  log10(1 + records); the greyscale fill")
println(io, "% lbl   printed cell text.  `--` when the cell is empty; `t/d` when the")
println(io, "%        cell holds named entries, t distinct functions of which d have an")
println(io, "%        in-repo CCZ class; the bare count `t` when the cell holds corpus")
println(io, "%        instances only, for which the CCZ decision is not defined.")
println(io, "col row logc lbl")
for (ri, g) in enumerate(GROUPS)
    for d in alldims
        r = get(records, (g.key, d), 0)
        k = get(decided, (g.key, d), 0)
        lbl = r == 0 ? "--" :
              get(namedcount, (g.key, d), 0) == 0 ? compact(r) :
              "$(compact(r))/$(compact(k))"
        println(io, "$d $(length(GROUPS) - ri + 1) $(round(log10(1 + r); digits = 4)) $lbl")
    end
end
write(joinpath(OUT, "heatmap.dat"), String(take!(io)))

io = IOBuffer()
print(io, header)
println(io, "% pgfplots axis style for Figure 1: grid size and tick labels,")
println(io, "% derived from the same classification that produced heatmap.dat.")
labels = String[]
for g in reverse(GROUPS)
    push!(labels, "{\\scriptsize\\textbf{" * g.code * "}\\,\\ " * g.short * "}")
end
println(io, "\\pgfplotsset{apn heat axis/.style={")
println(io, "  mesh/cols=" * string(length(alldims)) * ",")
println(io, "  xtick={" * join(string.(alldims), ",") * "},")
println(io, "  ytick={" * join(string.(1:length(GROUPS)), ",") * "},")
println(io, "  yticklabels={" * join(labels, ",") * "},")
println(io, "  xmin=" * string(minimum(alldims) - 0.5) * ", xmax=" *
            string(maximum(alldims) + 0.5) * ",")
println(io, "  ymin=0.5, ymax=" * string(length(GROUPS)) * ".5,")
println(io, "}}")
write(joinpath(OUT, "heatmap_axes.tex"), String(take!(io)))

# --- appendix ---------------------------------------------------------------
println("[8/8] writing manuscript/generated/appendix_{entries,corpora}.tex")
io = IOBuffer()
print(io, header)
println(io, "% Two plain tabulars, so the fragment needs no longtable and works")
println(io, "% inside a one- or two-column document alike.")
println(io, "\\begin{tabular}{@{}l c c c c l@{}}")
println(io, "\\toprule")
println(io, "\\textbf{Curated entry} & \$n\$ & \$\\delta\$ & \$\\deg\$ & \\textbf{Perm.} & \\textbf{Family / reference}\\\\")
println(io, "\\midrule")
lastn = 0
for c in curated
    fk = family_of_name(c.name)
    c.n != lastn && lastn != 0 && println(io, "\\addlinespace[2pt]")
    global lastn = c.n
    println(io, "\\texttt{$(texesc(c.name))} & $(c.n) & 2 & $(curated_deg[c.name]) & " *
                "$(curated_perm[c.name] ? "yes" : "no") & " *
                "$(FAMSHORT[fk])~\\cite{$(c.bib_key)}\\\\")
end
println(io, "\\bottomrule")
println(io, "\\end{tabular}")
write(joinpath(OUT, "appendix_entries.tex"), String(take!(io)))

io = IOBuffer()
print(io, header)
println(io, "\\begin{tabular}{@{}l c r r r r r r l@{}}")
println(io, "\\toprule")
println(io, "\\textbf{Bulk corpus} & \$n\$ & \\textbf{Members} & \\textbf{Distinct} & " *
            "\\textbf{APN} & \\textbf{Quad.} & \\textbf{Perm.} & \\textbf{Named} & " *
            "\\textbf{Ref.}\\\\")
println(io, "\\midrule")
for c in corpora
    ck = corpus_checks[c.name]
    println(io, "\\texttt{$(texesc(c.name))} & $(c.n) & $(grouped(c.members)) & " *
                "$(grouped(ck.distinct)) & " *
                "$(grouped(ck.apn)) & $(grouped(ck.quadratic)) & $(grouped(ck.permutation)) & " *
                "$(grouped(ck.also_named)) & " *
                "$(isempty(c.bib_key) ? "\\textemdash" : "\\cite{$(c.bib_key)}")\\\\")
end
println(io, "\\midrule")
println(io, "\\textbf{Total} & 8 & \\textbf{$(grouped(sum(c.members for c in corpora)))} & " *
            "\\textbf{$(grouped(sum(corpus_checks[c.name].distinct for c in corpora)))} & " *
            "\\textbf{$(grouped(sum(corpus_checks[c.name].apn for c in corpora)))} & " *
            "\\textbf{$(grouped(sum(corpus_checks[c.name].quadratic for c in corpora)))} & " *
            "\\textbf{$(grouped(sum(corpus_checks[c.name].permutation for c in corpora)))} & " *
            "\\textbf{$(grouped(sum(corpus_checks[c.name].also_named for c in corpora)))} & \\\\")
println(io, "\\bottomrule")
println(io, "\\end{tabular}")
write(joinpath(OUT, "appendix_corpora.tex"), String(take!(io)))

# --- scalar facts used in prose ---------------------------------------------
io = IOBuffer()
print(io, header)
macros = [
    "apnCurated" => string(length(curated)),
    "apnCuratedFiles" => string(count(f -> endswith(f, "_apn.toml"), readdir(CATALOG_DIR))),
    "apnNamed" => grouped(tot_ent),
    "apnInstances" => grouped(tot_inst),
    "apnFamilies" => string(length(FAMILIES)),
    # Not every row is a family.  These three add up to `apnFamilies`; only the
    # first is a count of construction families, and only that one answers
    # "how much construction diversity does the catalog hold?".
    "apnConstrFamilies" => string(count(f -> f.group != "C" && f.group != "D", FAMILIES)),
    "apnRepSets" => string(count(f -> f.group == "C", FAMILIES)),
    "apnRepEntries" => grouped(sum(fam_named(f.key) for f in FAMILIES if f.group == "C")),
    "apnCaseStudies" => string(count(f -> f.group == "D", FAMILIES)),
    "apnGroups" => string(length(GROUPS)),
    "apnTopGroups" => string(length(unique(g.top for g in GROUPS))),
    "apnDims" => dimspec(alldims),
    "apnNDims" => string(length(alldims)),
    "apnCorpora" => string(length(corpora)),
    "apnCCZclasses" => grouped(n_ccz_classes),
    "apnCCZmembers" => grouped(length(ccz_decided)),
    "apnDbApnRows" => grouped(length(dbfns)),
    "apnReverified" => grouped(length(curated) + length(dbfns) + tot_inst),
    "corpusSB" => grouped(only(c.members for c in corpora if c.name == "simonberg_gf4_n8")),
    "corpusYWL" => grouped(only(c.members for c in corpora if c.name == "yuwangli2014_qam_n8")),
    "apnStoreOverlap" => grouped(sum(corpus_checks[c.name].also_named for c in corpora)),
    "apnCellTotal" => grouped(sum(values(records))),
    "apnCorpusDupes" => grouped(sum(c.members - corpus_checks[c.name].distinct for c in corpora)),
    "apnDupCorpus" => join([texesc(c.name) for c in corpora
                            if c.members != corpus_checks[c.name].distinct], ", "),
    "apnDistinct" => grouped(length(union(Set{String}(values(curated_sha)),
                                          Set{String}(values(db_sha)),
                                          [h for c in corpora for h in corpus_sha[c.name]]))),
    "apnBibKeys" => string(length(BIB_KEYS)),
    "apnEvidenceQuotes" => string(n_ev),
    "apnEvidenceFiles" => string(length(n_ev_files)),
    "apnNEIGHT" => grouped(sum(get(records, (g.key, 8), 0) for g in GROUPS)),
    # computed from the same deduplicated cells the figure prints
    "apnSearchRecords" => grouped(sum(v for ((g, _), v) in records if startswith(g, "B"); init = 0)),
    "apnSearchShare" => string(round(100 * sum(v for ((g, _), v) in records if startswith(g, "B"); init = 0) /
                                     sum(values(records)); digits = 1)),
    "apnSearchDecided" => grouped(sum(ccz_decided_count(k)
                                      for k in FAMKEYS if startswith(FAMBY[k].group, "B"))),
    "apnGroupsAtEleven" => join([g.code for g in GROUPS if get(records, (g.key, 11), 0) > 0], ", "),
    "apnGroupsAtTwelve" => join([g.code for g in GROUPS if get(records, (g.key, 12), 0) > 0], ", "),
    "apnCuratedAtEleven" => string(count(c -> c.n == 11, curated)),
    "apnNotEIGHT" => grouped(sum(get(records, (g.key, d), 0) for g in GROUPS, d in alldims if d != 8)),
]
for (k, v) in macros
    println(io, "\\newcommand{\\$k}{$v}")
end
write(joinpath(OUT, "facts.tex"), String(take!(io)))

close(db)

println()
println("done. records: $(grouped(tot_ent)) named entries + $(grouped(tot_inst)) " *
        "corpus instances across $(length(FAMILIES)) rows " *
        "($(count(f -> f.group != "C" && f.group != "D", FAMILIES)) construction " *
        "families) / $(length(GROUPS)) groups")
println("      dimensions covered: $(join(alldims, ", "))")
println("      APN re-verified here: $(length(curated)) curated + $(length(dbfns)) " *
        "named DB rows + $(grouped(tot_inst)) corpus members")
