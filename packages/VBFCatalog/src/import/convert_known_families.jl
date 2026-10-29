#!/usr/bin/env julia
#
# Instantiate every known APN family VBF can construct, at every dimension where
# the family's parameters are valid, and insert the ones that are not already in
# the catalog.
#
# WHY THIS EXISTS
#
# The bulk corpora are all n = 8, because n = 8 is the one dimension where a
# *complete* enumeration is a realistic target (millions of functions). Every
# other dimension was therefore thin: at n = 9 the catalog held nine functions,
# five of them quadratic. A novelty oracle backed by that index reports `:new`
# for functions the literature already knows — demonstrably so: Yu et al. (2020)
# name f7 = x^264+x^160+x^144+x^132+x^80+x^72+x^66+x^40+x^17 as a KNOWN n=9
# function, and `classify_ccz` called it new. A σ-mismatch against an incomplete
# reference proves nothing, and treating it as proof is how four "new" APN
# functions were added to this catalog and later withdrawn (8022d09).
#
# So: for n ≠ 8, "known" means the known families instantiated at that n, plus
# the sporadic classes recorded in the literature. This script covers the first
# half systematically. The sporadic reps (e.g. Budaghyan et al. 2020 Table I
# rows 4 and 7 at n=9) are carried in the per-paper TOML.
#
# Each family constructor guards its own parameter constraints and throws
# ArgumentError, so the sweep is deliberately broad and lets the guards reject.
# Every candidate is re-verified APN (differential_uniformity == 2) before it is
# written — no function enters the catalog on the strength of a family name.
#
# Duplicates are skipped by exact LUT hash. CCZ-duplicates are NOT skipped and
# are not a mistake: the catalog is an index of *named functions*, and
# `equivalence_classes` (built by populate_ccz_equivalence_classes!, which
# confirms every σ-bucket with the complete EA decision) is what groups them
# into CCZ classes. Gold i and n-i, for instance, are the same class under two
# names, and both names are worth having.
#
# Usage:  julia --project=packages/VBFCatalog/src/import src/import/convert_known_families.jl [--max-n 12]

using VBF
using VBFCatalog
include("write.jl")
using SQLite
using DBInterface
using Dates
using Printf

const CONTRIBUTOR = "VBF.jl data-build"
const SOURCE_REPO = "VBF.jl/packages/VBF (known APN family constructors)"

# (canonical_name, sbox, bib_key, notes) for every family instance at dimension n
function known_family_instances(n::Int)
    out = Tuple{String,SBox,String,String}[]
    push_ok!(name, f, bib, note) = begin
        try
            s = f()
            differential_uniformity(s) == 2 || return          # never trust the name
            push!(out, (name, s, bib, note))
        catch e
            e isa ArgumentError || rethrow()                   # guard rejected the params
        end
    end

    # --- monomial families ---------------------------------------------------
    for i = 1:(n-1)
        gcd(i, n) == 1 || continue
        push_ok!("n$(n)_Gold_i$(i)", () -> gold_apn(n, i), "Gold_196801",
                 "Gold x^(2^$i+1) over GF(2^$n); gcd($i,$n)=1.")
        i >= 2 && push_ok!("n$(n)_Kasami_i$(i)", () -> kasami_apn(n, i), "Kasami_197105",
                 "Kasami x^(2^(2*$i)-2^$i+1) over GF(2^$n); gcd($i,$n)=1.")
    end
    if isodd(n)
        # Dobbertin_199905b is the Welch case, Dobbertin_199905 the Niho case.
        push_ok!("n$(n)_Welch", () -> welch_apn(n), "Dobbertin_199905b",
                 "Welch x^(2^t+3), n=2t+1=$n.")
        push_ok!("n$(n)_Niho", () -> niho_apn(n), "Dobbertin_199905",
                 "Niho exponent, n=2t+1=$n.")
        push_ok!("n$(n)_Inverse", () -> inverse_apn(n), "Nyberg_199400",
                 "Inverse x^(2^$n-2), n odd.")
    end
    n % 5 == 0 && push_ok!("n$(n)_Dobbertin", () -> dobbertin_apn(n), "Dobbertin_200100",
                 "Dobbertin, n=5k=$n.")

    # --- quadratic polynomial families --------------------------------------
    if n % 3 == 0
        k = n ÷ 3
        for s = 1:(n-1)
            # "BCP" is a historical name kept for compatibility; the n=3k binomial
            # is Budaghyan-Carlet-Felke-Leander (ISIT 2006), Theorem 1 / Corollary 1.
            push_ok!("n$(n)_BCP_k$(k)_s$(s)", () -> bcp_apn(k, s), "Budaghyan_200607",
                     "Budaghyan-Carlet-Felke-Leander binomial (ISIT 2006, Thm. 1), n=3k=$n, k=$k, s=$s.")
        end
    end
    if n % 4 == 0
        k = n ÷ 4
        for s = 1:(4k-1)
            push_ok!("n$(n)_BCL_k$(k)_s$(s)", () -> bcl_apn(k, s), "Budaghyan_200809",
                     "Budaghyan-Carlet-Leander binomial, n=4k=$n, k=$k, s=$s.")
        end
    end
    if iseven(n)
        half = n ÷ 2
        # taniguchi_apn_representatives sweeps (m,a,b) and returns CCZ-distinct reps
        try
            for r in taniguchi_apn_representatives(half)
                differential_uniformity(r.sbox) == 2 || continue
                push!(out, ("n$(n)_Taniguchi_m$(r.m)_a$(r.a)_b$(r.b)", r.sbox,
                            "Taniguchi_201909",
                            "Taniguchi quadratic APN, half=$half, m=$(r.m), a=$(r.a), b=$(r.b)."))
            end
        catch e
            e isa ArgumentError || rethrow()
        end
    end
    if n == 6
        push_ok!("n6_Kim_family", () -> kim_apn(), "Browning_201000",
                 "Kim function; quadratic source of the Dillon APN permutation.")
        push_ok!("n6_Dillon_permutation", () -> dillon_apn_permutation(), "Browning_201000",
                 "Dillon APN permutation (the only known even-dimension APN permutation).")
    end
    out
end

function _sha_exists(db::SQLite.DB, sha::AbstractString)
    for _ in DBInterface.execute(db,
            "SELECT id FROM functions WHERE lut_sha256 = " * VBFCatalog._sql_quote(sha) * " LIMIT 1")
        return true
    end
    false
end

function main(; max_n::Int = _parse_max_n(ARGS), min_n::Int = 4)
    db = SQLite.DB(VBFCatalog.catalog_path())
    today = ""
    total_new = 0
    println("dimension | candidates | already present | INSERTED")
    println("----------+------------+-----------------+---------")
    for n = min_n:max_n
        insts = known_family_instances(n)
        nnew = 0
        nold = 0
        SQLite.transaction(db) do
            for (name, s, bib, notes) in insts
                if _sha_exists(db, VBFCatalog.lut_sha256_hex(s))
                    nold += 1
                else
                    insert_function!(db, s; family="known-family", canonical_name=name, bib_key=bib, notes,
                        source_repo=SOURCE_REPO, contributor=CONTRIBUTOR, added_date=today)
                    nnew += 1
                end
            end
        end
        total_new += nnew
        @printf("    n=%-2d |    %4d    |      %4d       |   %4d\n", n, length(insts), nold, nnew)
    end
    println("\ninserted $total_new new known-family functions")
    for r in DBInterface.execute(db, "SELECT count(*) c FROM functions")
        println("functions now: ", r.c)
    end
    close(db)
end

function _parse_max_n(args)
    m = 12
    for (i, a) in enumerate(args)
        a == "--max-n" && i < length(args) && (m = parse(Int, args[i+1]))
    end
    m   # returned, not assigned to a captured local — avoids the soft-scope trap
end

abspath(PROGRAM_FILE)==(@__FILE__) && main()
