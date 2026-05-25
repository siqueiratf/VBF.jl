# Builds `BFA_catalog.sqlite` from human-editable sources under `data-raw/`.
#
# Run:
#     julia --project=. data-build/build_catalog.jl
#
# The script is idempotent: running it overwrites the existing catalog file.
# Statistics (DU, Lin, AlgDeg, BU, …) for every entry are computed via
# the same BFA.jl primitives the runtime queries return — so the catalog
# is internally consistent with what `ddt(s)` etc. would yield.

using BFA
import SQLite
import DBInterface
import Dates

const CATALOG_FILE = BFA.catalog_path()
const LITERATURE_PATH = normpath(joinpath(@__DIR__, "..", "data-raw", "literature_sboxes.toml"))

function _git_sha()
    try
        return readchomp(`git -C $(pkgdir(BFA)) rev-parse --short HEAD`)
    catch
        return "unknown"
    end
end

function _today_utc()
    string(Dates.now(Dates.UTC)) * "Z"
end

# Hard-coded bibliography for now; will be promoted to data-raw/bibliography.bib
# in a follow-up commit.
const BIBLIOGRAPHY = [
    (bib_key   = "FIPS197",
     year      = 2001,
     authors   = "NIST",
     doi       = "",
     url       = "https://nvlpubs.nist.gov/nistpubs/FIPS/NIST.FIPS.197.pdf",
     bibtex    = "@techreport{FIPS197, title={Advanced Encryption Standard (AES)}, institution={NIST}, year={2001}, number={FIPS 197}}"),
    (bib_key   = "BogdanovEtAl2007",
     year      = 2007,
     authors   = "Bogdanov; Knudsen; Leander; Paar; Poschmann; Robshaw; Seurin; Vikkelsoe",
     doi       = "10.1007/978-3-540-74735-2_31",
     url       = "https://link.springer.com/chapter/10.1007/978-3-540-74735-2_31",
     bibtex    = "@inproceedings{BogdanovEtAl2007, title={PRESENT: An Ultra-Lightweight Block Cipher}, booktitle={CHES}, year={2007}}"),
    (bib_key   = "BanikEtAl2017GIFT",
     year      = 2017,
     authors   = "Banik; Pandey; Peyrin; Sasaki; Sim; Todo",
     doi       = "10.1007/978-3-319-66787-4_16",
     url       = "https://link.springer.com/chapter/10.1007/978-3-319-66787-4_16",
     bibtex    = "@inproceedings{BanikEtAl2017GIFT, title={GIFT: A Small Present}, booktitle={CHES}, year={2017}}"),
    (bib_key   = "BanikEtAl2015Midori",
     year      = 2015,
     authors   = "Banik; Bogdanov; Isobe; Shibutani; Hiwatari; Akishita; Regazzoni",
     doi       = "10.1007/978-3-662-48800-3_17",
     url       = "https://link.springer.com/chapter/10.1007/978-3-662-48800-3_17",
     bibtex    = "@inproceedings{BanikEtAl2015Midori, title={Midori: A Block Cipher for Low Energy}, booktitle={ASIACRYPT}, year={2015}}"),
    (bib_key   = "BeierleEtAl2016SKINNY",
     year      = 2016,
     authors   = "Beierle; Jean; Kölbl; Leander; Moradi; Peyrin; Sasaki; Sasdrich; Sim",
     doi       = "10.1007/978-3-662-53008-5_5",
     url       = "https://link.springer.com/chapter/10.1007/978-3-662-53008-5_5",
     bibtex    = "@inproceedings{BeierleEtAl2016SKINNY, title={The SKINNY Family of Block Ciphers}, booktitle={CRYPTO}, year={2016}}"),
    (bib_key   = "ShibutaniEtAl2011Piccolo",
     year      = 2011,
     authors   = "Shibutani; Isobe; Hiwatari; Mitsuda; Akishita; Shirai",
     doi       = "10.1007/978-3-642-23951-9_23",
     url       = "https://link.springer.com/chapter/10.1007/978-3-642-23951-9_23",
     bibtex    = "@inproceedings{ShibutaniEtAl2011Piccolo, title={Piccolo: An Ultra-Lightweight Blockcipher}, booktitle={CHES}, year={2011}}"),
    (bib_key   = "AndersonBihamKnudsen1998Serpent",
     year      = 1998,
     authors   = "Anderson; Biham; Knudsen",
     doi       = "",
     url       = "https://www.cl.cam.ac.uk/~rja14/Papers/serpent.pdf",
     bibtex    = "@misc{AndersonBihamKnudsen1998Serpent, title={Serpent: A Proposal for the Advanced Encryption Standard}, year={1998}, note={NIST AES proposal}}"),
]

function insert_bibliography!(db::SQLite.DB)
    for entry in BIBLIOGRAPHY
        sql = string(
            "INSERT INTO bibliography (bib_key, bibtex, doi, url, year, authors) VALUES (",
            BFA._sql_quote(entry.bib_key), ", ",
            BFA._sql_quote(entry.bibtex), ", ",
            BFA._sql_quote(entry.doi), ", ",
            BFA._sql_quote(entry.url), ", ",
            entry.year, ", ",
            BFA._sql_quote(entry.authors), ")")
        SQLite.execute(db, sql)
    end
end

function insert_literature_sboxes!(db::SQLite.DB, contributor::AbstractString,
                                    source_repo::AbstractString)
    today = _today_utc()
    for name in literature_sbox_names()
        meta = literature_sbox_metadata(name)
        s = load_literature_sbox(name)
        n = inputbits(s)
        is_perm = is_permutation(s)

        # Compute statistics
        du = differential_uniformity(s)
        lin = linearity(s)
        algdeg = algebraic_degree(s)
        bu = is_perm ? boomerang_uniformity(s) : nothing
        is_quad = algdeg ≤ 2

        # BLOB serialisation + content hash
        bytes = BFA.canonical_lut_bytes(s)
        sha = BFA.lut_sha256_hex(s)

        # SQLite BLOB literal: X'...'  (uppercase hex preferred but we use lowercase)
        blob_literal = "X'" * bytes2hex(bytes) * "'"
        bu_literal = bu === nothing ? "NULL" : string(Int(bu))

        sql = string(
            "INSERT INTO functions (",
            "family, n, m, lut_sha256, lut_blob, algebraic_form, ",
            "algebraic_degree, differential_uniformity, linearity, boomerang_uniformity, ",
            "is_apn, is_permutation, is_quadratic, canonical_name, bib_key, ",
            "source_repo, contributor, added_date, notes) VALUES (",
            BFA._sql_quote("Literature"), ", ", n, ", ", n, ", ",
            BFA._sql_quote(sha), ", ", blob_literal, ", NULL, ",
            algdeg, ", ", Int(du), ", ", Int(lin), ", ", bu_literal, ", ",
            Int(du == 2), ", ",
            Int(is_perm), ", ",
            Int(is_quad), ", ",
            BFA._sql_quote(name), ", ",
            BFA._sql_quote(meta["bib_key"]), ", ",
            BFA._sql_quote(source_repo), ", ",
            BFA._sql_quote(contributor), ", ",
            BFA._sql_quote(today), ", ",
            BFA._sql_quote(meta["description"]), ")")
        SQLite.execute(db, sql)
    end
end

function main()
    sha = _git_sha()
    source_repo = "bfa@" * sha
    @info "Building BFA catalog" path=CATALOG_FILE source_repo
    db = create_catalog(CATALOG_FILE;
                         bfa_version = "0.1.0-DEV",
                         git_sha = sha)
    insert_bibliography!(db)
    insert_literature_sboxes!(db, "BFA literature import (automated)", source_repo)
    n_funcs = 0
    for r in DBInterface.execute(db, "SELECT COUNT(*) AS c FROM functions")
        n_funcs = r.c
    end
    @info "Catalog populated" functions=n_funcs file_size_bytes=filesize(CATALOG_FILE)
    close(db)
end

isinteractive() || main()
