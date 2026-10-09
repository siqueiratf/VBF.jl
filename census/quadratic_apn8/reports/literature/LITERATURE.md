# Literature and data survey: quadratic APN corpora

Survey date: **2026-10-09**. Primary computational scope: quadratic maps
F₂⁸ → F₂⁸, counted up to EA/CCZ equivalence. Broader-dimensional releases are
listed separately. This survey replaces the 2026-10-08 version, whose sampling
and switching-neighbour conclusions were too strong.

## Finding: a public quadratic representative was missing

The public slides of Baudrin, Galissant and Perrin, *Exploring the Set of APN
Functions in Practice*, contain a quadratic eight-bit APN representative outside
our rebuilt comparison baseline. See the [April 3 slides, physical PDF page
88](https://314gali.github.io/files/2026-04-03_APN_exploration_C2.pdf#page=88),
logical slide 24/24, also [posted by JC2](https://jc2-2026.sciencesconf.org/686214).
The same LUT appears in the [February 17 IRIF slides](https://314gali.github.io/files/2026-02-17_APN_exploration_IRIF.pdf#page=144)
and [February 13 Inria slides](https://314gali.github.io/files/2026-02-13_APN_exploration_INRIA_seminar.pdf#page=136).
These four downloads contain **one distinct example**, not four classes.

Independent computation established:

| Check | Result |
|---|---|
| Boolean algebraic degree | 2 |
| Every nonzero polar map | rank 7, hence APN |
| LUT SHA-256 | `47b70e16a3df08f05daa87762603b83706eee4be3054276502dbbcb5131ed636` |
| Recomputed ortho-derivative signature | `a14785b8c59ec5b0f5e841aaadc627f0eb1ae2f220f84cfbac5ef6e7c278aba7` |
| Rebuilt baseline signature hits | 0 |
| Signature hits in the four checked candidate files | 0 |

Different ortho-derivative signatures separate quadratic APN EA classes; by
[Yoshiara's theorem](https://emis.muni.cz/journals/JACO/Volume35_3/p72q12l317124710.fulltext.pdf),
they also separate their CCZ classes. This example therefore requires no
millions-of-pairs equivalence search to certify its absence. Conversely, a
matching signature is only a filter and is not treated as an equivalence proof.

The slides report further new switching neighbours and say they are all
CCZ-equivalent to quadratic functions (physical page 87). The earlier survey's
assumption that this work was probably outside the quadratic scope is
incorrect. The [June 16 ALMASTY seminar](https://almasty.team.lip6.fr/seminar/20260616b_seminar/)
describes the same line of experiments.

**The complete eight-bit switching output remains an unresolved comparison
source.** I did not locate a full representative list on the authors' public
pages, the inspected sboxU Git tree, arXiv/ePrint or Zenodo. This is an availability
finding, not proof that no public copy exists. The approximate percentages in
the slides do not determine a count of distinct classes. No author has been
contacted in this survey.

## Verified additional datasets and constructions

The new reproducible check prepared **33,512 records**, independently verified
**33,510 quadratic APN records**, and explicitly excluded two occurrences of
nonquadratic Kasami x⁵⁷. It found **one distinct absent signature**, the example
above. Positive coverage uses exact LUT identity or an explicitly verified EA
map, rather than signature agreement alone.

| Source checked this time | Records | Quadratic APN records | Absences | Positive coverage evidence |
|---|---:|---:|---:|---|
| Andersen APN-Repository | 32,893 | 32,892 | 0 | 32,890 exact original LUT matches; 2 EA maps |
| Kuznetsov Gröbner-search release | 566 | 566 | 0 | 566 EA maps to existing representatives |
| Galissant slides, four downloads | 4 | 4 | 4 occurrences of one class | New supplemental representative |
| Kuznetsov trace-product rank-two release | 8 | 8 | 0 | 8 EA maps |
| Scalar trace-product switches | 3 | 3 | 0 | 3 EA maps |
| Shi–Peng–Zheng family, dimension eight | 4 | 4 | 0 | 4 EA maps |
| Xanadu eight-bit polynomial list | 12 | 11 | 0 | Exact LUTs and 11 EA maps |
| Current sboxU `reprs8.py` polynomial routine | 22 | 22 | 0 | Exact LUTs and 22 EA maps |

There are **616 saved EA witnesses**, all independently checked on all 256 graph
points. Some exact-LUT matches also have a witness, so the evidence columns are
not disjoint. The report records 32,923 exact original LUT matches in total.
Witness targets are the 22 Edel–Pott representatives followed by the two
Taniguchi representatives, in the ordering used by the rebuild scripts.

### Source-specific observations

- **[APN-Repository](https://github.com/cma029/APN-Repository):** the full eight-bit
  Parquet file was fetched again. Polynomials were decoded over GF(256) with
  modulus `0x11d`; the upstream degree and spectral metadata were not trusted.
- **[Gröbner-search data](https://github.com/KuznetsovKarazin/apn-gb-search),
  [arXiv:2606.11967](https://arxiv.org/abs/2606.11967):** all 566 examples are
  equivalent to existing functions. This independently supports the earlier
  repository review in [FINDINGS.md](../../../../papers/2026/Kuznetsov_202606/FINDINGS.md).
  A release can contain valid APNs while its novelty comparison omits older
  classes.
- **[Trace-product release](https://github.com/KuznetsovKarazin/apn-trace-product-switchings),
  [arXiv:2608.04261v1](https://arxiv.org/html/2608.04261v1),
  [Zenodo archive](https://zenodo.org/records/21797356):** this August 2026 source
  was absent from the earlier survey. Reconstructed all eight published marked
  rank-two points and three scalar switches. Used modulus `0x11b`, and the
  reference implementation's `lambda=0xbd`; all eight published LUT digests
  agree exactly. These are known global classes, as the paper itself states.
- **[Shi–Peng–Zheng, 2025](https://www.jstage.jst.go.jp/article/transfun/E108.A/9/E108.A_2025EAL2001/_pdf):**
  instantiated Theorem 1 at `m=4`, `k=1,3,5,7`, over GF(16) with modulus `0x13`.
  These values exhaust the formula in dimension eight: the Frobenius powers
  repeat modulo four and eight consecutive terms in the added sums cancel.
  Each instantiated map passes the actual APN test and matches an existing
  class by an EA witness. The paper's claimed new examples are in dimension ten.
  No assumption about its conditional root criterion was needed for these
  finite checks.
- **[QAM paper, published version](https://link.springer.com/article/10.1007/s12095-025-00851-1),
  [code](https://github.com/NIchanska/QAM):** published November 26, 2025,
  volume 18 (2026). The revised text explicitly acknowledges that its shorter
  eight-bit representation belongs to an older Weng–Tan–Gong instance. Its
  partial search with GF(16) coefficients produced no APNs; its GF(4)
  coefficient classification corresponds to the already rebuilt Simon-Berg
  corpus. Here `(8,2)` describes input dimension and coefficient subfield degree,
  not an eight-input/two-output APN corpus.
- **[Xanadu list](https://github.com/Xanadu-ins/apn-ccz-graph-framework):** its
  eight-bit section has 12 polynomials, including nonquadratic Kasami. Conway
  modulus `0x11d` gives the independently verified APN instances; the 11
  quadratic entries are existing classes.
- **[sboxU](https://github.com/lpp-crypto/sboxU):** inspected the current full
  repository tree. The five bulk literal-LUT files have identical Git blob
  digests to the originals already used in the rebuild. Checked the current
  `reprs8.py` polynomial list separately. The eight-bit switching database
  generation example reads local `8_bit_3m_apn_0` through `_37` input batches;
  these are not a release of the newly found neighbours.

## Existing baseline and older corpora

The [exhaustive rebuild report](../../rebuild_corpus/REPORT.md) binds the
comparison baseline to SHA-256
`0eed9fb5d3a70bd24b8c8c9eefa61b0b882b9cd540dd06cda0cd430444f7b603`.
It has **3,809,037 distinct signatures**: 3,808,491 from the original index plus
546 classes present in the older public raw output.

| Rebuilt registered corpus | Stored representatives/records |
|---|---:|
| Beierle–Langevin–Leander–Polujan–Rasoolzadeh 2025 | 3,775,599 |
| Beierle–Leander 2022 | 12,923 |
| Beierle–Leander–Perrin 2022 | 6,368 |
| Yu–Perrin QAM | 5,412 |
| Yu–Wang–Li QAM | 8,179 |
| Edel–Pott | 22 |
| Taniguchi | 2 |
| Weng–Tan–Gong | 10 |
| Simon-Berg GF(4) coefficients | 196,863 forms, representing 27 classes |

These counts overlap and must not be added as distinct classes. Original inputs
were verified exhaustively in the rebuild, alongside quadratic APN catalog rows.

The [2026-08-27 paper revision](https://arxiv.org/html/2508.04644v2) still gives
the published lower bound 3,808,491. Its [Zenodo LUT list](https://zenodo.org/records/16752428)
is already rebuilt. The [Langevin directory](https://langevin.univ-tln.fr/data/apns/)
contains the published list, the 11,888,039-record binary search output, its text
copy, and nine earlier Sage snapshots. The binary output has now been checked
fully, replacing the earlier samples. The [retained snapshot crosscheck](../../crosscheck_raw/REPORT.md)
checked 31,390,363 records overall and found the nine snapshots contained in
the raw-output signature union. Those snapshot results are historical evidence;
this survey did not independently download/recompute all snapshots again.

Version distinctions matter: the current [BL Zenodo version](https://zenodo.org/records/4738942)
has 12,921 functions after removing two Taniguchi classes; the older version
used for the imported list has 12,923. This is not a newly missing corpus.
The [BLP release](https://zenodo.org/records/5821018) is likewise already rebuilt.
The [Bergen instance tables](https://boolean.wiki.uib.no/Known_instances_of_APN_functions_over_GF(2%5E8))
are useful historical pointers but are not a complete current registry.

## Other releases and literature leads

| Lead | Scope and consequence |
|---|---|
| [Zenodo 22010376, classification release](https://zenodo.org/records/22010376) | New August 2026 release of quadratic `(n,m)` EA representatives. Input dimension at most seven; no `(8,8)` list. The Summary gives `(6,7)=38,838` and `(6,8)=866,470`: these are rectangular maps, not missing square eight-bit APNs. |
| [Thornburgh exclude-multiplicity dataset](https://github.com/Darrionat/dim8-quadratic-apn-exclude-multiplicities) | Previously omitted bibliographic/data lead. It records graph invariants of known quadratic APNs rather than supplying a separate newly constructed APN corpus. |
| [SageMath cryptographic-functions library](https://github.com/hoeeg/SageMath_library_for_cryptographic_functions) | May 2026 software with known-family generators and recognition routines. Useful for a parameter-by-parameter family audit; no extra released eight-bit representative list located. Not every parameter choice was instantiated here. |
| [Shi, CCZ equivalence of bivariate APNs, 2025](https://www.jstage.jst.go.jp/article/transfun/E108.A/9/E108.A_2025EAP1008/_pdf) | Studies the same generalized bivariate formula checked above, rather than supplying a separate representative corpus. |
| [Calderini–Li–Villa, bivariate families](https://arxiv.org/abs/2204.07462) | Construction-family lead, with claimed new examples in dimension twelve. A parameter-complete instantiation in dimension eight was not performed here; include it in the outstanding family audit. |
| [Göloğlu–Kölsch, arXiv:2605.17545](https://arxiv.org/abs/2605.17545) | Triprojective constructions in dimensions divisible by three; relevant to a broader-dimensional registry, not input dimension eight. |
| [Ma–Liu–Huang, arXiv:2608.11939](https://arxiv.org/abs/2608.11939) | Current primary record is *CCZ-Equivalence and Enumeration of Triprojective APN Functions*, revised September 2026; dimensions divisible by three. Search-engine metadata for this identifier was inconsistent, so it must be pinned by revision. |
| [Baudrin–Canteaut–Perrin, ePrint 2026/1012](https://eprint.iacr.org/2026/1012) | Structure and linear self-equivalences of known families; no additional released eight-bit corpus located. |
| [Quadratic APN Walsh spectra, arXiv:2510.12008](https://arxiv.org/abs/2510.12008) | Spectral theory and bounds; no additional representative dataset located. |
| [Carlet–Thornburgh, arXiv:2608.23888](https://arxiv.org/abs/2608.23888) | Gorodilova-conjecture work; no additional eight-bit corpus located. |
| [BFA 2025](https://boolean.w.uib.no/bfa-2025-program/) and [BFA 2026 abstracts](https://boolean.w.uib.no/bfa-2026-accepted-abstracts/) | Checked announcement leads as well as papers; the switching work is the material unresolved eight-bit source. Titles/abstracts alone cannot certify that every talk contains no additional example. |

The search covered primary paper revisions, Zenodo records and version histories,
GitHub trees and data files, workshop programs, author publication/talk pages,
and citation/reference trails from the main eight-bit papers. Query families
included `quadratic APN dataset 2026 8`, `8-bit APN Zenodo`, `quadratic APN corpus`,
`Galissant APN database 8`, and author/construction-specific searches. This is
an evidence-based survey, not an exhaustive search of all documents or private
results. Newly posted files or unindexed supplementary material remain possible.

## What can be counted exactly?

The public baseline plus the independently verified slide example gives a
**certified lower bound of 3,809,038 pairwise inequivalent classes represented
by these specified public inputs**. The supplemental representative is saved
separately; the hash-bound rebuild database was not modified.

The four checked candidate files still contribute **110,436 distinct signatures
absent from that extended public baseline**. Combining the specified public
inputs and those checked candidates certifies a lower bound of **3,919,474
classes**. This does not establish that every candidate was previously unknown:
the full announced switching results have not been compared. The screenshot's
110,868 count remains outside the available input manifest.

A class count is not a count of literal functions. State the dimension,
quadratic restriction, equivalence relation, and data cutoff. For quadratic
square APNs, EA and CCZ class counts coincide. With no fixed dimension, the
question does not specify a single finite classification problem.

For square quadratic APNs, the recent [classification release](https://zenodo.org/records/22010376)
reports complete EA counts of **2 in dimension five, 13 in dimension six, and
488 in dimension seven**. Dimension eight remains unclassified. Beierle et al.'s
roughly six-million total is a statistical estimate, not an exact classification
or an upper bound.

There are two distinct research deliverables:

1. **A registry of known classes:** pinned source files, field/basis conventions,
   verified LUTs, provenance, and exact duplicate/equivalence certificates. It
   can answer what is represented in a dated, documented public union.
2. **A complete mathematical classification:** enumeration with justified
   reduction/pruning and exhaustive equivalence handling. A literature survey
   and a large signature index cannot establish this.

Priority follow-up is obtaining the complete Baudrin–Galissant–Perrin eight-bit
switching representatives, including quadratic representatives for any
nonquadratic functions that are CCZ-quadratic, their claimed distinct count,
and comparison baseline/version. Then audit known-family parameters in
fixed dimension eight and record unresolved availability/novelty claims
explicitly. Avoid calling a signature an intrinsically complete invariant:
buckets with equal signatures need actual equivalence checks.

## Reproduction and evidence

[ sources.tsv ](sources.tsv) pins ten input files by URL and SHA-256. The relevant
Git revisions are:

| Repository | Inspected revision |
|---|---|
| lpp-crypto/sboxU | `bedb6d1a796c3c582572393a91270b6fd15dc9e1` |
| cma029/APN-Repository | `9971ccd938bdf005b7ba0685dd1af17175799801` |
| KuznetsovKarazin/apn-gb-search | `c63864cff55a78449397e12c78abcfaaaa7c06dc` |
| KuznetsovKarazin/apn-trace-product-switchings | `040bd424ba5de36f5fa7d17ae2633e3493f7804c` |
| NIchanska/QAM | `8c2c58f7333c096b7f4435ade3b5dc248814d358` |
| hoeeg/SageMath_library_for_cryptographic_functions | `5ccde97743db5666e0452cb034caf36b7c7fcc34` |
| Xanadu-ins/apn-ccz-graph-framework | `0fbcbc61a7aefa86bdb20b4cff697233e1a89940` |

Run from the repository root after completing the original corpus rebuild.
Python requires `pyarrow`; PDF extraction requires `pdftotext`. Fetching checks
hashes and refuses silently changed sources. No upstream code is executed.

```sh
python census/quadratic_apn8/reports/literature/fetch_sources.py census/quadratic_apn8/results/literature_20261009
python census/quadratic_apn8/reports/literature/prepare_sources.py census/quadratic_apn8/results/literature_20261009
julia --compiled-modules=no --startup-file=no --project=. -t 8 census/quadratic_apn8/reports/literature/check_sources.jl census/quadratic_apn8/results/literature_20261009 census/quadratic_apn8/results/signature_rebuild
julia --startup-file=no census/quadratic_apn8/reports/literature/verify_evidence.jl census/quadratic_apn8/results/literature_20261009
```

Generated evidence stays under `../../results/literature_20261009/`:

- `inputs.tsv`: extracted LUTs/polynomial parameters and published LUT digests.
- `checks.tsv`: every input's LUT hash, recomputed signature, degree/APN exclusion,
  exact original-LUT status, baseline lookup, and candidate-signature overlap.
- `checks.toml`: per-source totals, 616 full EA certificates, evidence/code hashes,
  original-database hashes, and the pinned baseline/candidate report identities.
- `supplemental_luts.tsv`: the one absent signature and its full 256-byte LUT.
- `verification.log`: the verification run; `independent_verification.log`: the
  VBF-free recheck of the saved maps and supplement.
- Source downloads, Git-tree metadata and fetch manifests: retained locally.
  Upstream README downloads are stored as `README.source.txt`.

PDFs, downloads and generated datasets are ignored. No catalog data or catalog
build product was changed. The relevant reusable math comes from VBF; degree,
APN, signatures and witness identity verification use the independent verifier.
