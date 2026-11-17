# Catalog proof of concept (stage S0)

Question: can a browser query the catalog and the corpus members over HTTP Range requests,
well enough to replace a custom binary format?

Result: **yes for SQLite over HTTP; the custom binary format brings no benefit that matters.**
The open decision is where to host the query database (section 5).

## 1. Method

- Data: the real local catalog (prebuilt key `95e15324…`), 11 corpora, 4,005,925 members.
- `poc/build_dbs.jl` builds the variants: `catalog.sqlite` and `members.sqlite` with page
  size 1024 and 4096, and a **query database** in which each member has its full LUT SHA-256
  (the function key) and its full signature (`sigma_hash` from the signature index), with
  indexes on both. A copy with 16-byte hashes measures the effect of shorter keys on size.
- `poc/measure.mjs` runs each query in headless Chrome 153 (Playwright), in a new browser
  context per run, first cold and then warm. `poc/server.mjs` serves the files with Range
  support and no COOP/COEP headers, as GitHub Pages does, and counts requests and bytes.
- Two network profiles: **local** (no delay) and **remote** (60 ms per request, 2.5 MB/s).
  Measured from here: GitHub Pages ≈ 0.09 s per Range request; Zenodo ≈ 0.75–0.8 s.
- Libraries: sql.js-httpvfs 0.8.12 (last release 2022) and sqlite-wasm-http 1.2.0
  (official SQLite WASM; "sync" backend, because GitHub Pages cannot send COOP/COEP).
- Memory: resident memory of the renderer process (page and workers).

## 2. Sizes

| File | Size |
|---|---|
| `catalog.sqlite` (page 4096) | 9.6 MiB |
| `members.sqlite` (page 4096) | 220 MiB |
| query database, full hashes (page 4096) | 759 MiB |
| query database, full hashes (page 1024) | 816 MiB |
| query database, 16-byte hashes (page 4096) | 513 MiB |
| fixed-width members file (Beierle et al. only) | 133 MiB |

## 3. Results (page size 4096, cold cache)

| Query | Library | Local: ms / requests / KiB | Remote: ms |
|---|---|---|---|
| open the database | sql.js-httpvfs | 60 / 3 / 8 | 241 |
| | sqlite-wasm-http | 365 / 4 / 9 | 623 |
| Q1 member by (corpus, idx) | sql.js-httpvfs | 19 / 6 / 40 | 395 |
| | sqlite-wasm-http | 23 / 6 / 24 | 391 |
| | fixed-width file | 3 / 1 / 0.04 | 64 |
| Q2 page of 50 members | both | 16–19 / 5 / 24–28 | 323–326 |
| Q3 filtered functions + bibliography (catalog) | both | 41–47 / 14 / 104–120 | 928 |
| Q4 corpora of a function (by content hash) | sql.js-httpvfs | 8 / 3 / 12 | 193 |
| | sqlite-wasm-http | 14 / 5 / 28 | 323 |
| Q5 count of members with a signature (12,794 rows) | both | 31–34 / 10–11 / 1,028–1,032 | 1,055–1,116 |
| Q5b first 50 members with a signature | both | < 1 after Q5 | < 1 after Q5 |
| Q6 count of the whole Beierle corpus (full scan) | sql.js-httpvfs | 2,272 / 111 / 474,122 | > 120 s (stopped) |
| | sqlite-wasm-http | 7,965 / 1,704 / 942,678 | > 120 s (stopped) |

Warm repeats of Q1–Q5 take 0.4–6 ms with no request. The fixed-width file answers only Q1.

Memory (renderer resident set): 145–170 MiB with sql.js-httpvfs and 160–300 MiB with
sqlite-wasm-http for Q1–Q5. The full scan Q6 raised it to 968 MiB (sql.js-httpvfs keeps every
page it read) and 433 MiB (sqlite-wasm-http has a bounded page cache).

## 4. Analysis

- **Q4 and Q5 are the deciding queries, and SQLite answers both.** Q4 (where does this
  concrete function occur?) needs 3–5 requests and 12–28 KiB. Q5 (which members share this
  invariant key?) needs about 1 MiB for a class of 12,794 members, because the count reads the
  whole index range; listing the first 50 needs only a few pages. The fixed-width file cannot
  answer Q4 or Q5 without a second, home-made index, that is, without rebuilding a database.
- **The binary format's only gain is Q1 latency** (64 ms against about 390 ms remote, one
  request against six). A member view needs Q1 once per page view, so 0.4 s is acceptable.
  This gain does not justify a second format with its own encoder, decoder and tests.
  Decision: no custom binary format.
- **Whole-corpus aggregates (Q6) are not online queries.** They read hundreds of MiB. Counts,
  class sizes and other aggregates are computed at build time and stored as small tables;
  the online interface allows only indexed queries, and the later SQL console needs a byte limit.
- **Page size 4096** needs fewer round trips than 1024 (Q1 remote 395 ms vs 516 ms; Q3 928 ms vs
  1,433 ms) for slightly more bytes. With remote latency, 4096 is better. It is also SQLite's default.
- **Library.** Both meet the needs. sql.js-httpvfs opens faster and uses less memory, but it has
  had no release since 2022 and keeps every page it reads. sqlite-wasm-http uses the official
  SQLite build, has a bounded cache and is maintained, but opens about 0.3 s slower.
  Recommendation: sqlite-wasm-http, behind one small module so that it can be replaced.
- **Snapshots.** Zenodo answers Range requests with CORS (`access-control-allow-headers: range`),
  so an uncompressed query database in each Zenodo version can be queried online for
  historical snapshots. It is slow (≈ 0.8 s per request; a cold Q1 ≈ 5 s) and limited to
  133 requests per minute per IP, so it suits occasional historical references, not the
  current catalog.

## 5. Decision (2026-11-17)

- **Format:** SQLite over HTTP Range, page size 4096; no custom binary format.
- **Library:** sqlite-wasm-http, behind one small module of the portal.
- **Hosting:** the query database of the current snapshot is served from GitHub Pages
  (759 MiB with full hashes; about 200 MiB of headroom under the 1 GB limit). Each Zenodo
  data version also stores its query database uncompressed, so a historical snapshot can be
  queried online from Zenodo (slower: about 0.8 s per request, 133 requests per minute).
  When the current database outgrows Pages, it moves to an external host with Range and CORS.
- **Limits of the online interface:** indexed queries only; aggregates over a whole corpus
  are computed at build time.
