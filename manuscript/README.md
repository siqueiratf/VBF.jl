# `manuscript/` — the APN catalog table and figure

This directory holds one LaTeX fragment and the script that makes its numbers.
The fragment shows the APN catalog of this repository as a table and a figure.
You paste the fragment into your own paper. There is no paper in this
repository.

## Files

| File | What it is |
|---|---|
| `apn_catalog.tex` | The deliverable. A standalone fragment. Paste it into your paper, or use `\input`. |
| `generate_catalog_table.jl` | The generator. It writes every file in `generated/`. |
| `generated/table_main.tex` | The body of Table 1. |
| `generated/table_notes.tex` | The lettered notes for Table 1. They go in their own float, immediately after Table 1. |
| `generated/facts.tex` | One `\newcommand` for each number that the prose uses. |
| `generated/heatmap.dat` | The data for Figure 1. One line for each cell. |
| `generated/heatmap_axes.tex` | The pgfplots axis style for Figure 1. |
| `generated/appendix_entries.tex` | The body of the appendix table of curated entries. |
| `generated/appendix_corpora.tex` | The body of the appendix table of bulk corpora. |
| `preview.tex` | A proofing harness. It is **not** part of the deliverable. |

Do not edit the files in `generated/`. Each one starts with a warning and with
the name of the generator. Run the generator again to change them.

## How to make the generated files again

Run this command from the top of the repository:

```
julia --project=. -t auto manuscript/generate_catalog_table.jl
```

The generator is deterministic. It reads only files in this repository. It
writes only into `manuscript/generated/`. It does not change `packages/`,
`papers/` or any database. It does not run git.

The run needs approximately 100 seconds. Most of that time goes to two
recomputations: the APN property for 229,779 corpus members, and one
EA-equivalence decision at `n = 8` (see mechanism 4 below).

## How to compile the preview

The development machine has no system TeX. Use Tectonic:

```
JULIA_PROJECT=<path-to-a-tectonic-project> julia -e 'using Tectonic; tectonic() do bin
  run(`$bin -X compile manuscript/preview.tex --outdir <build-dir>`)
end'
```

The pgfplots version in Tectonic is old. `\pgfplotsset{compat=1.17}` is the
maximum that it accepts.

## What your paper needs in its preamble

```latex
\usepackage{booktabs}
\usepackage{array}
\usepackage{amssymb}
\usepackage{tikz}
\usepackage{pgfplots}
\pgfplotsset{compat=1.17}
```

Set `\apncatgen` if you move the `generated/` directory:

```latex
\providecommand{\apncatgen}{path/to/generated/}
```

The `\cite` keys point to
`packages/VBFCatalog/data-raw/bibliography.bib`. The generator stops with an
error if the table cites a key that this file does not contain.

## What the generator reads

The generator reads these sources. All of them are in git.

| Source | What it gives |
|---|---|
| `packages/VBFCatalog/data-raw/apn_catalog/n*_apn.toml` | The 35 curated entries. This is the authority for the curated counts. |
| `packages/VBFCatalog/data-raw/bibliography.bib` | The citation keys. |
| `packages/VBFCatalog/BFA_catalog.sqlite` | The named `functions` rows, the CCZ classes, and the `bulk_corpora` registry. |
| `packages/VBFCatalog/corpora/*.sqlite` | The members of each bulk corpus. |
| `packages/VBFCatalog/data-build/*.jl` | The code that verifies each object at import. |
| `packages/VBF/src/**.jl` | The library guards, for example the design-rank guard. |
| `papers/<year>/<Paper_ID>/README.md` | The reproduction reviews. |

The generator also reads `audit/findings.yaml` when that file is present. It
uses it for one purpose only: to test the `kind` to E1--E5 mapping and to print
a count on the screen. **No emitted file changes when `audit/findings.yaml` is
absent.** `audit/findings.yaml`, `audit/readme_index.yaml` and `report.md` are
not in git. No column of the table depends on them.

## How the generator makes sure that it does not invent

There are four mechanisms.

1. **Counts come from the sources.** The generator counts entries, corpus
   members, dimensions and CCZ class members with queries. It does not hold a
   list of counts.
2. **The APN property is a recomputation.** The generator builds each function
   and computes its differential uniformity, its algebraic degree and its
   permutation flag. It does this for the 35 curated entries, for the 663 named
   `functions` rows and for all 229,779 corpus members. It stops with an error
   if any object fails.
3. **Each status mark has a quotation.** The generator holds an evidence ledger.
   Each item gives a file and a literal text. The generator tests that this
   text occurs in that file, after it makes all runs of space equal to one
   space. If the text is not there, the generator stops. A mark whose evidence
   changed can thus not go into the table.
4. **The one open equivalence question is decided, not quoted.** The
   reproduction review of `Budaghyan_200910` recorded that the ortho-derivative
   mugshot of eq. (6) with `a = alpha` over GF(2^8) is the same as the mugshot
   of the catalog entry `n8_Taniguchi2025_ex4_2`. A mugshot match is a
   necessary condition. It is not a decision. That review put the question in
   its "Open questions" list. The generator now builds eq. (6) from the
   published formula, tests the result against the ortho-derivative spectrum
   that the review prints, and then runs `are_ea_equivalent`, which is a
   complete test on the quadratic APN class. The answer is `true`. If the test
   does not give an answer, the generator prints the weaker "partly recomputed"
   mark instead. It never prints the divergence mark on the strength of the
   mugshot alone.

The current run verifies 93 quotations across 20 files.

## The classification rules

The generator puts each catalog object into one family with a pattern rule on
its stored name. If no rule agrees with a name, the generator stops. A new
catalog entry can thus not disappear from the table without a warning.

Each family goes into one of 10 groups. The 10 groups go into 4 construction
methods:

- **A** Algebraic constructions: A1 monomial families, A2 polynomial and
  multinomial families, A3 bivariate and biprojective constructions, A4
  isotopic shift, switching and coset modification.
- **B** Computational search: B1 QAM search, B2 tree and trim search, B3
  restricted-coefficient exhaustive classification, B4 published targeted
  enumerations.
- **C** Equivalence classification.
- **D** Sporadic results.

## The `kind` to E1--E5 mapping

`audit/findings.yaml` gives a `kind`, a `verification_tier` and a `severity` to
each finding. The generator maps them to the E1--E5 taxonomy with these rules:

| `kind` | E-code | Reason |
|---|---|---|
| `tool_limit` | E5 | A guard or a budget in this implementation stops the check. |
| `hard_limit` | E5 | The computation does not stop at the given size. |
| `theory_limit` | E5 | No reference set exists at that dimension. |
| `sampling_not_exhaustion` | E4 | The published evidence covers less than the claim. |
| `scope_restriction` | E4 | Data that is necessary for the core claim is not published. |
| `unsound_negative` | E3 | A negative result comes from pruning that the text does not give. |
| `unproved_premise` | E3 | A step is stated as proved but is only shown by example. |
| `wrong_condition` | E2 | A recomputation contradicts a stated hypothesis. |
| `wrong_value` | E2 | Tier is `recomputed` or `code_confirmed`. |
| `wrong_value` | E1 | Tier is `paper_confirmed` and severity is `low`. |
| `internal_inconsistency` | E2 | Severity is `medium` or `high`. |
| `internal_inconsistency` | E1 | Severity is `low`, that is, a label or an index only. |
| `inferred` | none | A limit that is read off a table is not a divergence. |

Three rules control the use of an E-code:

- An E-code goes only on a cell that has the divergence mark.
- A finding at tier `readme_only` never gives a divergence mark.
- All five codes speak about a claim in a **publication**. A divergence against
  the provenance record of this catalog is a different object. Such a cell gets
  the divergence mark and a note, and no code.

On the current data this mapping gives E1 = 1, E2 = 17, E3 = 6, E4 = 4, E5 = 6,
and 2 findings with no code.

Table 1 shows two divergences. Both rest on files that are in git:

- Row `Taniguchi et al. 2025, Ex. 4.2`, column E. **No E-code.** The generator
  decides on each run that this catalog entry is EA-equivalent, and thus
  CCZ-equivalent, to Budaghyan--Carlet--Leander 2009 eq. (6) with `a = alpha`
  over GF(2^8). The catalog gives the entry to a 2025 paper and holds no
  prior-art key, so the two disagree. The 2025 paper is not at fault: it claims
  only EA-inequivalence to `x^3`, and it claims no novelty. The divergence is
  against the catalog, so no code applies.
- **E4**, row `Yu et al. 2020 representatives`, column N. The reproduction
  review of `Yu_202012` reports rows 4 and 10 of the source table as the same
  polynomial. The result is that one of the 15 classes is absent from the
  published table, and an exhaustive search had to find it again. E1 is for a
  defect that changes only the readability of a paper. This defect removes data
  that the paper needs to show its own result, which is what E4 says.

## The status marks

| Mark | Meaning |
|---|---|
| check | The work recomputed the claim and it agrees. |
| half disc | The work recomputed part of the claim. |
| `!` | The work recomputed the claim and found a divergence. An E-code follows the mark when the divergence is against the cited publication. |
| circle with slash | The claim is outside the reach of the current implementation. |
| open circle | The claim exists, but no recomputation of it is on record. |
| en dash | There is no such claim, or it does not apply. |

The marks are shapes. No mark uses colour. All of them stay clear in a
greyscale print.

## Limits of the derived data

Read this section before you use the table.

1. **Table 1 has no column for the APN property, and this is on purpose.** The
   generator computes that property itself, for every catalogued object, on
   each run. It stops with an error if one object fails. A column for it could
   thus never show anything but "confirmed", and a column that cannot change
   tells the reader nothing. The caption of Table 1 gives the claim instead,
   with the number of objects that it covers. The three columns that stay,
   I, E and N, are weaker: for them the generator reports what the repository
   records. It runs no new invariant or novelty computation. It runs one new
   equivalence computation, and only one: see mechanism 4 above. Keep this
   difference in mind. Do not read a check mark in I, E or N as the same
   quality of evidence as the APN result in the caption.

2. **The catalog database is one row behind its own sources.** The commit that
   added `n8_Taniguchi2025_ex4_2` to `n8_apn.toml` did not build
   `BFA_catalog.sqlite` again. The TOML files declare 35 curated entries; the
   database holds 34 `APN` rows. The generator takes the curated counts from
   `data-raw`, which is the authority. One effect is visible in Figure 1: the
   cell A4 at `n = 8` shows `1/0`, because that entry has no database row and
   thus no CCZ class. This is a defect at `HEAD`. This work does not correct
   it.

3. **The CCZ numerator of Figure 1 is narrow.** The in-repository CCZ decision
   accepts only quadratic APN functions. It runs only on named entries. A
   corpus member gets an ortho-derivative signature but no class. A power map
   of degree 3 or more gets neither. A low numerator therefore shows the reach
   of the tool. It does not show a defect in the source. For this reason a cell
   that holds only corpus instances prints no ratio at all. It prints the count
   alone. A `0` after a slash in such a cell would look like a check that
   failed, and no check applies there.

4. **68 functions are in both stores.** A function can be a named entry and a
   member of a bulk corpus at the same time. The 27 Simon--Berg class
   representatives are one example. Table 1 keeps `Ent.` and `Inst.` apart for
   this reason. Do not add the two columns. The appendix table of corpora gives
   the overlap corpus by corpus.

5. **A cell of Figure 1 counts distinct functions.** The generator addresses
   each function by the SHA-256 of its lookup table. A function held in two
   stores counts once in a cell. But a function that two different methods
   reach counts once in each method row. The cells therefore sum to a number a
   little above the count of distinct functions in the catalog. The figure
   caption gives both numbers.

6. **One corpus holds duplicate members.** `simonberg_gf4_n8` holds 196,863
   members but only 196,855 distinct lookup tables. Eight members repeat a
   lookup table that the same corpus already holds. No other corpus repeats
   one. The appendix table of corpora shows this in the `Distinct` column. The
   generator found this; the repository does not record it anywhere else.

7. **Six reproduction reviews ran without a Julia toolchain.** Their own text
   says so. The generator never treats a number from those six as a
   recomputation. The rows that they support carry the open-circle mark.

8. **The Taniguchi 2025 divergence is now decided, and it is against this
   catalog.** An earlier draft of this fragment printed the E2 code on that
   cell. That was wrong for two reasons. First, the evidence at the time was
   two matched ortho-derivative mugshots. A mugshot match is a necessary
   condition. It is not a decision. The source review said so. It also put the
   question in its "Open questions" list. Second, E2 says that a claim in a
   paper is false. The 2025 paper makes no such claim. It claims only
   EA-inequivalence to `x^3`.
   The generator now runs the complete EA test and gets `true`. The cell keeps
   the divergence mark, drops the code, and note *i* names the catalog as the
   party that disagrees. **The catalog itself is not corrected here.** The
   entry `n8_Taniguchi2025_ex4_2` still needs a prior-art cross-reference to
   Budaghyan--Carlet--Leander 2009 in `n8_apn.toml`. That is a change to
   `data-raw`, and this work does not make it.

9. **Group C is 556 of the 664 named entries.** The `Ent.` column is therefore
   a measure of population, not of provenance. The two CCZ representative sets
   are populations that a classification tool returned. They are not
   constructions, and they hold no source. Only 23 of the 28 rows are
   construction families. The 35 curated entries of the appendix are the tier
   that holds a source and a verification record. Weigh that tier, not the
   total.

10. **Table 1 and its notes are two floats, and a figure can come between
   them.** Together they are taller than one page, so they cannot share one
   float. LaTeX never puts a float in front of an earlier float of the same
   type, so the notes always follow Table 1. That rule does not work across
   types. Figure 1 is a `figure*` and can go between the table and the notes.
   Move the `figure*` block below the appendix tables if your pagination does
   this and you do not want it.

11. **Two sources have no citation.** The Simon--Berg thesis and the `sboxU`
   repository have no `bib_key` in the catalog. Table 1 prints an em dash for
   them. The generator does not invent a key.

12. **One corpus count does not agree with its own label.** The registry text
   for `yuwangli2014_qam_n8` says "8,157 APN functions". The side store holds
   8179 members, after the import removed one member that is not quadratic. The
   repository holds no analysis that makes the two figures agree. Note *k*
   under Table 1 records this.

13. **Dimension 11 has no curated file.** There is no `n11_apn.toml`. The 22
   entries at `n = 11` come from the family import only. The curated tier and
   the imported tier of the catalog therefore cover different dimensions.

14. **BFA-4R is a separate artifact.** `apn_catalog.tex` shows no BFA-4R column
    and no BFA-4R value, and it must stay that way. Recomputation status
    measures what this work verified. BFA-4R measures the quality of the
    evidence that the original publication gave. The two are different axes.
    `bfa4r.tex` holds the BFA-4R table. Keep the two fragments apart.


# `bfa4r.tex` — the BFA-4R table

BFA-4R grades a **publication** on the computational evidence that the
publication itself gave. It does not grade whether that evidence is correct.
The catalog table grades a different thing: what this work verified again.
Do not merge the two axes into one status.

A clear example is in the data. `Kuznetsov_202606` gets a full mark on R1, R2
and R3, but this repository refutes its central novelty claim. Good evidence
and a correct result are different properties. This is why the two axes stay
apart.

## Files

- `bfa4r.tex` — the fragment. Paste it into your paper.
- `generate_bfa4r_table.jl` — the generator.
- `generated/bfa4r_table.tex` — the 42 rows, in two panels.
- `generated/bfa4r_evidence.tex` — the raw evidence for each cell.
- `generated/bfa4r_facts.tex` — the counts that the caption uses.
- `preview_bfa4r.tex` — a proofing harness. It is not part of your paper.

## How to make the files again

```bash
julia --project=. manuscript/generate_bfa4r_table.jl
```

Use `--report` to print the result and write no file.

## What your paper needs in its preamble

`booktabs`, `array`, `tikz`. The fragment defines `\gf`, `\gh` and `\go` with
`\providecommand`, so your own definitions win. The marks differ by fill
geometry, so they stay correct in grayscale.

## The four rules

| Mark | R1 | R2 | R3 | R4 |
|---|---|---|---|---|
| full | a pseudocode or parameter signal is present, and the review records no underspecification | 2 or more tables and 3 or more invariant mentions | a persistent archive: Zenodo, figshare, a tagged release, a data DOI | two outside signals |
| half | structure is present, but the review records an underspecification | some table or invariant evidence | a repository or a proprietary-tool script only | one outside signal |
| open | neither signal | no table and no invariant mention | no artifact | no outside signal |

## CAUTION: the marks are proposals, not an expert reading

Each mark comes from a stated rule over the tracked files. A rule is a proxy.
Read the evidence table before you trust a cell, and change any cell that the
evidence does not support.

One limit dominates. The files under `papers/<id>/input/` are automatic
conversions from PDF to LaTeX. The `algorithm` environment and the `theorem`
environment both occur 0 times in all 42 papers, so the conversion destroys the
structural signal for R1. R1 therefore uses a text proxy and the review of the
reproduction. The `tabular` environment survives the conversion 142 times, so
the R2 table signal is sound. The URLs survive, so R3 is the most reliable
column. R4 is the weakest: this repository can only see part of the outside
world, and it does not detect a shared author between two papers.

## Known gap in the sources

`Gologlu_202503` has no entry in `packages/VBFCatalog/data-raw/bibliography.bib`.
The table prints a dagger for it instead of a citation. Two more paper
directories need an alias, and the generator records both in `BIB_ALIAS`:
`Yu_202211d` resolves to `Yu_202211`, and `Kuznetsov_202606` resolves to
`Kuznetsov_202600`. Each alias was confirmed by a title match.
