# Literature and data survey: public sources of quadratic APN functions on F_2^8

Survey date: 2026-10-08. Question: does any published paper or released dataset contain
quadratic APN functions in dimension 8 (n = m = 8) that the local index does not cover?

**Local index used as the reference.** These are the corpora in
`packages/VBFCatalog/corpora/` and the `bulk_corpora` table of `BFA_catalog.sqlite`:

- `beierle2025_n8`: 3,775,599
- `beierleleander2022_n8`: 12,923
- `beierleleanderperrin2022_n8`: 6,368
- `yuperrin2022_qam_n8`: 5,412
- `yuwangli2014_qam_n8`: 8,179
- `edelpott2009_n8`: 22
- `taniguchi2019_n8`: 2
- `wengtangong2013_n8`: 10
- `simonberg_gf4_n8`: 196,863 members, which form 27 CCZ classes

The catalog also has 44 n = 8 `functions` rows. Taken together, the index holds 3,808,491
distinct CCZ classes, and its σ-signatures are stored in `corpora/ccz_sigma_index.sqlite`.

**How coverage was checked.** I recomputed the σ-hash of each external function with
`VBFCatalog.sigma_hash` and looked it up in `ccz_sigma_index`. The lookup was read-only, and
all scratch files went to `/tmp/lang`.

- A σ miss would be a rigorous proof that a function lies outside the index.
- A σ hit is a necessary condition for CCZ-equivalence but does not prove it. In this survey
  a hit is read as "covered". For bulk data from the same search as `beierle2025_n8`, that
  reading carries essentially no risk.

---

## 1. Sources examined

### 1.1 Beierle, Langevin, Leander, Polujan, Rasoolzadeh, "Millions of inequivalent quadratic APN functions in eight variables"

**arXiv:2508.04644**

- **URLs:** https://arxiv.org/abs/2508.04644 (v1 2025-08-06, v2 2026-08-27, math.CO). It was
  presented at BFA 2025 in Larnaca, 1–5 Sep 2025, and no journal reference is listed yet.
- **Content (v2):**
  - Theorem 5.1: "There exist at least 3 808 491 CCZ-inequivalent quadratic (8,8)-APN
    functions." Of these, 3,775,599 are new and 32,892 were already known.
  - The "coordinate approach" (§3.2) produced most of the functions. The "variable approach"
    (§4, Remark 4.8) produced 92,955 functions, of which ℓ = 92,253 are distinct.
  - Every class found by either method is included in the 3,775,599. The arithmetic: of the
    92,955 functions, t′ = 32,286 lie outside the M = 3,776,451 classes that were known or
    came from §3.2, and 3,808,491 − 3,776,451 = 32,040.
  - v2 adds a reference to Zenodo 22010376 (see 1.3). It reports no new (8,8) count beyond
    v1.
- **Total estimate:**
  - Inverse coupon-collector maximum-likelihood estimate with (t, ℓ) = (92,955; 92,253):
    N ≈ 6,123,206.
  - Second estimate, N = tM/(t − t′): N ≈ 5,786,151.
  - So "about six million" in total, and the authors say they hold "more than half".
- **Covered:** yes. This paper is the source of `beierle2025_n8`, and its total equals the
  local union of 3,808,491.

### 1.2 Zenodo 10.5281/zenodo.16752428

- **URL:** https://zenodo.org/records/16752428 (published 2025-08-07, v1, no newer version).
- **Files:** a single file, `new_apns.txt`, of 3,395,265,744 bytes. It holds lookup tables
  of the 3,775,599 new functions.
- **Covered:** yes. This file is the input of `beierle2025_n8` (see the `bulk_corpora`
  notes).

### 1.3 Zenodo 10.5281/zenodo.22010376, "Classification of quadratic APN functions up to EA-equivalence"

- **URL:** https://zenodo.org/records/22010376 (published 2026-08-19, same five authors).
- **Files:** 38 files named `QAPN-n-m`, plus a `Summary` file. I checked the list through
  the Zenodo API.
  - The largest are `QAPN-6-8` (156,831,070 B), `QAPN-6-7` (7,029,677 B) and `QAPN-7-7`
    (182,023 B).
  - The others are small (n ≤ 5).
- **Counts:** the `Summary` table gives the number of quadratic (n,m)-APN classes up to EA.
  - (5,8) = 9, (6,6) = 13, (6,7) = 38,838, (6,8) = 866,470, (7,7) = 488.
  - The n = 7 and n = 8 columns are "xxxxxxx" for m = 8, and "?" for larger m.
- **(8,8) functions:** none. The record covers only n ≤ 7, and for n = 6 it goes up to
  m = 8.
- **Covered:** not applicable, since there is no n = 8 data.

### 1.4 Project page https://langevin.univ-tln.fr/data/apns/

This is the page cited as [3] in arXiv:2508.04644v2. Directory listing as of 2026-10-08,
with no file newer than May 2025:

| file | size | date |
|---|---|---|
| `apn-11888039-may-2025-8.out` | 760,834,496 B (726 MB) | 2025-05-09 |
| `apn-11888039-may-2025-8.txt.gz` | 3.6 GB | 2025-05-09 |
| `new_apns.txt.gz` | 1,230,386,178 B (1.1 GB) | 2025-05-15 |
| `sage.tar` (8 × `apn-x0k.sage`, about 81 MB each, LUT lists) | 615 MB | 2024-08-30 |
| `sage-18-09.tar`, `sage-25-08.tar`, `sage-10-10.tar`, `sage-02-11.tar`, `sage-30-11.tar`, `sage-10-01.tar`, `sage-31-01.tar`, `sage-29-03.tar` (gzip-compressed tars) | 212–424 MB each | 2024-09 to 2025-03 |

- **apn-11888039 files.** These hold the raw search output: exactly 11,888,039 records, at
  64 bytes per record in the `.out` file.
  - Each record is 8 little-endian uint64. Each uint64 is a 28-bit mask over the quadratic
    monomials x_i·x_j in colex order (no linear part). I decoded this and confirmed that the
    records are APN.
  - The 11.9M records are not deduplicated. The number is not mentioned in the paper.
- **new_apns.txt.gz** is the compressed form of the Zenodo file `new_apns.txt`.
- **Sampled coverage checks.** Each sample was fetched with HTTP Range requests and stayed
  under 50 MB:

  | sample | functions | APN | σ-hits in the local index | misses |
  |---|---|---|---|---|
  | `apn-11888039…out`, 60 random 64 KiB blocks spread over the whole file | 2,400 | 2,400 | 2,400 | 0 |
  | `apn-11888039…txt.gz`, first 40 MB (128,499 functions), random subsample | 3,000 | 3,000 | 3,000 | 0 |
  | `sage.tar`, 40 random 64 KiB windows | 1,600 | 1,600 | 1,600 | 0 |
  | `sage-29-03.tar` (newest snapshot), first 24 MB compressed (77,050 LUTs), random subsample | 1,500 | 1,500 | 1,500 | 0 |
  | `new_apns.txt.gz`, first 10 MB (32,129 functions), random subsample | 1,000 | 1,000 | 1,000 (all `beierle2025_n8`) | 0 |

  The hits were overwhelmingly `beierle2025_n8`, with the rest in BL22, BLP22 and the QAM
  sets.
- **Rate bound.** From 0 misses in 2,400 uniformly sampled raw records, the 95% upper bound
  on the fraction of raw records outside the index is about 0.12% (rule of three).
- **Theorem 5.1 counts all classes found.** The intermediate snapshots predate the final list
  of 2025-05-15 and are subsumed by it.
- **Covered:** yes for the deduplicated list. For the raw and intermediate files: very likely
  yes, based on samples and not proved exhaustively.
- **Not done:** the full 3.6 GB file and the sage tars were not downloaded, because of the
  50 MB limit.

### 1.5 Kuznetsov, "Quadratic APN Functions in Dimension 8 via Gröbner Basis Search in a Self-Equivalence Subspace"

**arXiv:2606.11967**

- **URLs:**
  - https://arxiv.org/abs/2606.11967 (v1 2026-06-10, v2 2026-06-19)
  - Code and data: https://github.com/KuznetsovKarazin/apn-gb-search (last commit 2026-06-11)
  - Zenodo 10.5281/zenodo.20626047 (v1.0.1, a 605 kB zip of the repository)
- **Claim:** 566 quadratic APN functions in 6 CCZ classes, of which 4 classes (500
  functions) are "new". The claim was checked only against Beierle 2025 (3,775,599 functions)
  and BL22 (12,921 functions).
- **Check:**
  - I checked all 566 functions from `data/apn_all.json`: every one gives a σ-hit.
  - Classes A–D match `edelpott2009_n8` (and also `yuwangli2014_qam_n8` and
    `simonberg_gf4_n8`). Classes E and F are Gold x³ and x⁹.
  - The repository's own review reaches the same result:
    `papers/2026/Kuznetsov_202606/FINDINGS.md`. It identifies the four classes as Edel–Pott
    (2009) Table 9 functions 2.1, 1.3, 1.2 and 1.11, confirmed by exact code-equivalence.
  - The catalog cites this work as `Kuznetsov_202600`.
- **Covered:** yes. There are no new classes.

### 1.6 Ichanska, Berg, Kaleyski, Yu, "Pushing the QAM method for finding APN functions further"

**IACR ePrint 2024/1838**

- **URL:** https://eprint.iacr.org/2024/1838 (Nov 2024).
- **Claim:** it classifies (n,m) = (8,2) (QAM over subfield coefficients) and reports "a new
  APN function in dimension 8" in Table 5.
- **Check:** the repository review `papers/2024/Ichanska_202400/README.md` found that the
  function is EA-equivalent to `wengtangong2013_n8` member 9, to `reprs8_34` and to
  `SimonBerg_GF4_n8_class_10`.
- **Covered:** yes. The catalog cites it as `Ichanska_202400`.

### 1.7 Simon Berg (thesis) – GF(2²)-coefficient quadratic APN on GF(2⁸)

- The thesis classifies these functions completely: 27 CCZ classes.
- Quadratic APN functions with coefficients in F₂ (Yu, Li, Ichanska, Kaleyski: ePrint
  2024/1778, and AAECC 2025 for n = 10) are a subset at n = 8.
- **Covered:** yes, as `simonberg_gf4_n8`.

### 1.8 Pre-2025 literature (the "32,892 known")

- **Sources:** Edel–Pott 2009; Weng–Tan–Gong 2013; Yu–Wang–Li 2014 (8,157 functions in the
  paper, 8,179 in the sboxU file); Taniguchi 2019; Beierle–Leander 2022 (12,921 or 12,923);
  Beierle–Leander–Perrin 2022 (6,368, Zenodo 5821018); Yu–Perrin 2022 (5,412).
- Families: Gold, Kasami, Budaghyan–Carlet, Bracken et al., Edel–Kyureghyan–Pott and others.
- **Covered:** yes. These are exactly the local corpora and the catalog rows, and the
  independent check in 1.9 confirms it.

### 1.9 APN-Repository (C. Andersen)

- **URL:** https://github.com/cma029/APN-Repository (last commit 2025-08-20). The catalog
  cites it as `Andersen_202500`.
- **Data:** `database/apn/apn_data_8.parquet` (8.9 MB) has 32,893 rows: 32,892 quadratic
  plus Kasami x⁵⁷. By citation:
  - BL22: 12,921
  - YWL14: 8,157
  - BLP21: 6,368
  - YP21: 5,412
  - BBMM07: 13
  - WTG13: 10
  - BCL09: 3
  - Gold, BC08, Tan19: 2 each
  - EKP06, EP09, Kasami: 1 each
- **Check:** I converted all rows to LUTs (GF(2⁸) mod x⁸+x⁴+x³+x²+1).
  - All 32,892 quadratic rows give a σ-hit and none misses.
  - The single non-quadratic Kasami row has no ortho-derivative, so it was skipped.
- The repository has no Beierle 2025 data.
- **Covered:** yes.

### 1.10 sboxU (L. Perrin et al.)

- **URL:** https://github.com/lpp-crypto/sboxU (last commit 2026-10-08).
- **Data:** the n = 8 data files in `sboxU/scripts/apnDB/` are `BeierleLeander.py`,
  `apn_8bit_BLP22.py`, `firstQAM.py`, `secondQAM.py`, `eightBitAPN.py` and `reprs8.py`. These
  are the sources the local corpora were imported from (`sboxu@7066b82`).
- `sboxU/apn/biblio_dict.py` (biblio_8) lists only Yu–Wang–Li, Yu–Perrin, BL22, BLP22,
  Weng–Tan–Gong and Beierle et al. 2025 (Zenodo 16752428), plus a placeholder "TO SOURCE
  NICE POLYNOMIALS LIST".
- `tests/switching_neighbours/8_bits/db_gen.py` reads 38 private batches named
  `8_bit_3m_apn_k` (the 3.8M set). Those batches are not in the repository.
- **Covered:** yes.

### 1.11 "Exploring the Set of APN Functions in Practice" (LIP6 ALMASTY seminar, 2026-06-16)

The BFA 2025 abstract "Structures in the Set of APN Functions" by Baudrin, Galissant and
Perrin appears to be the same line of work.

- **URL:** https://almasty.team.lip6.fr/seminar/20260616b_seminar/
- **Content:**
  - The authors built EA-class databases for 6- and 7-bit functions.
  - They "exhaustively compute all switching neighbors of the 3.8 million 8-bit quadratic
    functions in less than a day ... among which we report new functions."
  - The code is in sboxU (`sboxU/cpp/apn/sn.cpp`).
- **n = 8 data:** no public list of the "new functions" was found, whether on ePrint, arXiv,
  the sboxU repository or Zenodo.
  - These are switching neighbours, so they are most likely non-quadratic APN functions,
    which would be outside the scope of a quadratic index.
  - It cannot be ruled out that some are quadratic.
- **Covered:** unknown. The functions are unpublished and, as far as can be determined,
  most likely not quadratic. **This is the one open item to watch.**

### 1.12 Boolean Functions Wiki (Bergen)

- **URLs:** https://boolean.wiki.uib.no/Tables (last modified 2024-10-16) and
  https://boolean.wiki.uib.no/Known_instances_of_APN_functions_over_GF(2%5E8).
- **Content:** tables of the known 8-bit APN instances: the matrix method (YWL14) about
  8,180 functions, plus Edel–Pott, WTG13 and Taniguchi; `File:Quadratic_apn_polynomials_8.txt`;
  and switching-class tables. Beierle 2025 is not mentioned.
- **Covered:** yes, since everything there is pre-2021 data already in the local corpora.

### 1.13 Other works checked (no new n = 8 quadratic APN data)

- **Taniguchi, Polujan, Pott, Arshad,** arXiv:2501.03922 (2025). Example 4.2 on F₂⁸ is
  already in the catalog as `n8_Taniguchi2025_ex4_2`; the only claim is non-equivalence to
  x³. See `papers/2025/Taniguchi_202501/README.md`.
- **Göloğlu–Kölsch,** arXiv:2111.04197 (2025). This is the biprojective equivalence theory;
  its new family is at n = 12.
- **Yu, Li, Ichanska, Kaleyski,** AAECC 2025. Covers n = 10 only, and the authors claim no
  new functions.
- **Carlet–Thornburgh,** arXiv:2608.23888 (Aug 2026). Theory: Gorodilova's conjecture and
  semi-bent components. No new functions.
- **Gillot–Langevin,** "Observation of known APNs", arXiv:2601.11247 (Jan 2026). Covers
  n = 6 only.
- **Nonvanishing k-flats,** arXiv:2603.28266, and "On different notions related to APN
  mappings", arXiv:2609.22394. Theory only.
- **IACR ePrint 2025–2026 APN papers:**
  - 2026/1012: linear self-equivalence of the known APN families
  - 2026/1393: Galois rings
  - 2026/1662 and 2026/1663: degree-sum-freedom and 5-bit subspace DU
  - 2025/2144: butterfly structure

  None contains new 8-bit quadratic APN functions.
- **BFA 2025 accepted abstracts** (https://boolean.w.uib.no/bfa-2025-accepted-abstracts/).
  The only n = 8 data source is the Beierle et al. abstract. "A unified software framework
  for classification of VBFs" (Kaleyski and Matre) is software, and no dataset was found.
- **BFA 2026 accepted abstracts** (https://boolean.w.uib.no/bfa-2026-accepted-abstracts/,
  Sogndal, 7–11 Sep 2026). There are 18 abstracts, and none concerns quadratic APN functions
  in dimension 8.
- **Xanadu-ins/apn-ccz-graph-framework** (GitHub, 2026). Its n = 8 list holds known
  sporadic and family representatives only: Gold, Kasami, Edel–Pott and similar.
- **Citing works of arXiv:2508.04644** (Semantic Scholar, 2026-10-08):
  2609.22394, 2608.23888, 2606.11967, 2603.28266 and 2408.04218. All are covered above.

## 2. Independent estimates of the total number of classes

- No work since 2025 gives an independent estimate of the number of quadratic APN CCZ
  classes in dimension 8.
- The only estimates are in Beierle et al. 2025 itself: about 6.12 M (MLE) and about
  5.79 M.
- Kuznetsov (2606.11967) only quotes "approximately 6 million".
- Earlier conjectures, now superseded: more than 50,000 (Yu–Perrin), and more than 92,515,
  the number of quadratic (8,4)-bent classes (Polujan–Pott).

## 3. Verdict

**No public source of quadratic APN functions on F₂⁸ is known that the local index does not
cover.**

- **Deduplicated published lists.** Every one of them is fully contained in the local
  corpora or catalog:
  - Beierle et al. 2025 (Zenodo 16752428, and `new_apns.txt.gz` on the Langevin page)
  - BL22, BLP22, YWL14, YP22, Edel–Pott, Weng–Tan–Gong, Taniguchi
  - Simon Berg's GF(4) classes
  - the APN-Repository (all 32,892 checked)
  - sboxU
  - the Bergen wiki tables
- **Later "new" claims.** These turned out to be already covered:
  - Kuznetsov 2026: all 566 functions checked, and they are Edel–Pott classes.
  - Ichanska et al. 2024: a Weng–Tan–Gong class.
- **Zenodo 22010376** contains no (8,8) data. It stops at n ≤ 7, and for n = 6 it covers
  m ≤ 8.
- **Raw and intermediate Langevin files.** These are 11,888,039 raw records and the 2024–25
  snapshots. 8,500 sampled records gave 100% σ-hits. That supports the paper's statement
  that 3,808,491 is the total of all classes they found, and the local union equals that
  number exactly.
- **Residual uncertainties:**
  1. The "new functions" from exhaustive switching-neighbour computation on the 3.8M set
     (Baudrin, Galissant, Perrin; LIP6 talk 2026-06-16) are unpublished. They are probably
     non-quadratic.
  2. The 3.6 GB raw file and the sage snapshots were checked by sampling only, not
     exhaustively.
