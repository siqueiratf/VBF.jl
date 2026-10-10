# The metrics for the paper

This document defines what the analysis brings to the paper, and what it leaves
out. It is the specification that `packages/VBFRepro/analysis/reproductions/metrics.jl` implements. Each metric
gives one CSV in `data/repro/analysis/reproductions/`. The CSV files hold data only. They carry
no comment line and no header line other than the column names, so a
spreadsheet, R or pandas reads them without a filter. `PROVENANCE.md` beside
them records the source of every file.

## The rule

A number earns a place in the paper when it can change what a reader believes.
A number that only repeats a definition does not. Three questions decide it.

1. Can the number come out differently? If the answer is known before the
   measurement, the measurement is decoration.
2. Does the number bound a claim? A cost that says which dimensions are out of
   reach bounds every "we found no more" statement in the paper.
3. Does the number compare two things that a reader must choose between?

## What the analysis leaves out, and why

| Rejected | Why |
|---|---|
| A cost table that ranks the library tiers against each other | CCZ equivalence costs more than linear algebra by definition. The ordering carries no information. |
| A growth slope that confirms a textbook exponent | The DDT holds 2^{2n} cells. A measurement that agrees adds nothing. Two exceptions stay, and the next section names them. |
| The cost of a "yes" answer against a "no" answer, as a result | It is a caution about how to read a benchmark, not a finding about APN functions. It stays as one sentence in the method section. |
| The member count of a corpus as a measure of its contribution | 196,863 members of `simonberg_gf4_n8` carry 27 σ-classes. The count of members measures the file, not the mathematics. Metric B3 replaces it. |
| One percentage for "papers reproduced" | The number hides the only interesting axis, which is *which kind* of paper fails. Metric A2 replaces it. |

Two timing results survive, because they meet question 2 or 3.

- **The reach limits.** The largest `n` that one hour and 4 GiB reach, for each
  operation. Every negative claim in the paper rests on these. They come from
  `data/perf/archive/generated/crossing_growth.csv`.
- **The Gamma-rank guard.** The in-repo guard refuses `n > 7` and says the cost
  is "hours". The measurement is 166.8 s. This one number withdraws a limit
  that six paper reproductions cite as their blocker.

Everything else from the benchmark suite enters the paper only as the cost
column of metric C1, where it divides a quantity of evidence.

---

## Group A — the literature and how well it reproduces

### A1. `papers.csv` — the join table

One row for each of the 42 papers. It carries no conclusion. Every other table
of group A aggregates this one, so a reader can rebuild them.

| Column | Type | Source |
|---|---|---|
| `paper_id`, `year` | text, integer | `audit/readme_index.yaml` |
| `topic` | one of seven values | `packages/VBFRepro/analysis/reproductions/taxonomy.toml` |
| `catalog_bib_key`, `method_group` | text, `A1`..`D` or empty | `packages/VBFRepro/analysis/reproductions/taxonomy.toml` |
| `tex_lines`, `jl_files`, `test_files`, `test_assertions` | integer | `audit/readme_index.yaml` |
| `results_dir`, `cited_by_core_src` | 0 or 1 | `audit/readme_index.yaml` |
| `readme_verdict`, `verdict_class`, `readme_test_claim` | text | `audit/readme_index.yaml`, `packages/VBFRepro/analysis/reproductions/taxonomy.toml` |
| `findings_primary`, `findings_implicated`, `findings_high`, `findings_medium`, `findings_recomputed`, `findings_readme_only` | integer | `audit/findings.yaml` |
| `catalog_functions`, `corpus_members` | integer | `BFA_catalog.sqlite` |
| `r1`..`r4` | `full`/`half`/`open` | `data/repro/analysis/reproductions/bfa4r_grades.csv` |

`findings_primary` counts the defects whose `paper_id` is this paper.
`findings_implicated` counts the defects that name it in `also_implicated`, so a
defect that spans three papers is not counted three times as a primary one.

### A2. `reproduction_by_method.csv` — the headline table

**Question.** Which kind of paper reproduces, and which kind does not?

**Axes.** The topic of the paper (rows: `construction`, `modification`,
`search`, `classification`, `equivalence`, `four_uniform`, `theory`) against the
reproduction outcome (columns: the verdict class, the defect counts by severity
and by tier, the defect counts of the two kinds that matter most, and the mean
number of test assertions).

The topic is the right row axis, and not the catalog method group. Only 11 of
the 42 papers put a function into the catalog, so a method-group axis would
leave 31 papers in one bucket. `method_by_dimension.csv` uses the method group
instead, where every object has one.

**The measured result.** The `search` papers hold 5 of the 42 papers and 7 of
the 18 high-severity defects. The `theory` papers hold none. This is the axis
that carries the discussion.

**Why it is not trivial.** The expected answer is that algebraic families
reproduce and computational searches do not. The data can contradict it, and it
partly does: the defects of group A papers are wrong constants, which a test
catches, while the defects of group B papers are unsound negatives, which no
test catches. That difference is the discussion.

**The discussion it opens.** A paper that states a family reproduces from its
text. A paper that reports a search reproduces only with its artifact. This is
the argument for the artifact requirement, made with counts and not with
opinion.

### A3. `reproduction_by_year.csv`

**Question.** Does a paper get easier to reproduce over time?

**Axes.** The publication year, bucketed, against the same outcome columns as
A2, plus the mean of `test_assertions`.

**Why it is not trivial.** Two forces pull against each other. A newer paper
more often ships an artifact. A newer paper also makes a larger computational
claim, which needs more evidence. The data says which force wins.

### A4. `defect_kind_by_tier.csv`

**Question.** Which defects does reading find, and which need a recomputation?

**Axes.** The defect kind (`wrong_value`, `wrong_condition`,
`unsound_negative`, `sampling_not_exhaustion`, `internal_inconsistency`,
`scope_restriction`, `hard_limit`, `tool_limit`, `theory_limit`,
`unproved_premise`, `inferred`) against the strongest verification tier
(`readme_only`, `paper_confirmed`, `code_confirmed`, `recomputed`).

**Why it is not trivial.** It measures the cost of finding each class of error.
A defect that only `recomputed` reaches is a defect that peer review cannot
see. That is the strongest statement this collection can make about the review
of computational mathematics.

**The measured result.** Of the 8 `wrong_value` defects, 6 needed a
recomputation and 5 of those are high severity. Every one of the 5
`unsound_negative` defects needed the code or a recomputation; not one of them
is visible in the text alone.

### A5. `evidence_vs_outcome.csv`

**Question.** Does a paper that supplies better evidence reproduce better?

**Axes.** The BFA-4R grade of the publication (R1 disclosure, R2 verification
metadata, R3 artifact, R4 corroboration; each `full`, `half` or `open`) against
the reproduction outcome.

**Why it is not trivial.** The two axes are independent by construction. BFA-4R
grades what the publication supplied. The outcome grades what this work
verified. A paper can supply an exemplary artifact for a claim that
recomputation refutes.

**The measured result, and its confound.** The six papers that score `full` on
R3 (an open, reusable artifact) carry 2.0 defects each, the highest of any
group, and none of them reproduces completely. The ten papers that score `open`
on R3 carry 0.3 defects each. The paper must NOT read this as "an artifact
causes defects". The direction is the other way: a paper ships an artifact when
its claim is computational, and a computational claim is the only kind that
this work can check at all. State the confound in the same sentence as the
number, and use the topic axis of A2 to separate the two effects.

---

## Group B — the catalog: where the APN functions are

### B1. `method_by_dimension.csv`

**Question.** Where does each construction method reach?

**Axes.** The method group against the dimension `n`, in three measures: the
curated entries, the corpus members, and the distinct σ-classes.

**Why it is not trivial.** The existing figure of the catalog paper counts
records. Records and classes are different quantities, and the difference is
the point of B3. The same figure with a σ-class fill shows a different picture
of the same catalog.

**Format.** Long, one row for each (group, n) cell. A heatmap reads it directly.
Columns: `method_group`, `n`, `curated_functions`, `curated_quadratic`,
`corpus_members`, `corpus_sigma_classes`.

**CAUTION:** the sigma index covers QUADRATIC APN functions only, because the
ortho-derivative signature is defined for them. `curated_quadratic` is the
denominator that sigma saw; `curated_functions` is the whole cell.
`corpus_sigma_classes` counts the classes of the bulk corpora of that group, so
it is zero for a group that has no corpus. The curated functions are indexed
under one source name and cannot be split by group, so their classes appear in
`corpus_sigma.csv` under the source `functions` instead.

### B2. `evidence_depth.csv`

**Question.** How strong is a novelty verdict at each dimension?

**Axes.** The dimension `n` against the depth of the evidence: curated entries,
the number of bulk corpora, the members, the distinct σ-classes, and a flag for
whether a novelty verdict can be certified at all.

**Why it is not trivial.** Every bulk corpus is `n = 8`. At `n = 9` and above,
the catalog holds single-digit numbers of functions. A `:new` verdict there
means "absent from a list of nine", not "new". The table gives the exact
denominator of every novelty claim in the paper, per dimension. Finding F040
of the audit says the same thing in words; this puts a number on it.

### B3. `corpus_sigma.csv`

**Question.** How much mathematics does each published corpus carry?

**Axes.** The source corpus against: members, distinct σ-classes, the ratio of
the two, the σ-classes unique to that source, and the σ-classes it shares.

**Why it is not trivial.** σ is the ortho-derivative signature. Two functions
with different σ are provably CCZ-inequivalent, so the count of distinct σ is a
sound lower bound on the classes that a corpus carries. The measured spread is
extreme: `simonberg_gf4_n8` holds 196,863 members and 27 σ-classes, a ratio of
7291 members per class, while `beierle2025_n8` holds 3,775,599 members and
3,775,599 σ-classes, a ratio of 1. Any statement of the form "corpus X is
larger than corpus Y" is meaningless without this table.

**CAUTION:** equal σ does not prove equivalence. The σ-class count is a lower
bound on the number of CCZ classes, never an upper bound. The CSV names it
`sigma_classes` and never `ccz_classes`.

### B4. `corpus_overlap.csv`

**Question.** Do the published corpora repeat each other?

**Axes.** Source against source, in σ-space: the size of the intersection and
the share of the smaller source that the larger one contains.

**Why it is not trivial.** It measures redundancy in the literature directly.
The measurement already shows that the 22 σ-classes of Edel–Pott 2009 are all
inside Yu–Wang–Li 2014, and that Beierle et al. 2025 shares no σ-class with any
earlier source.

**CAUTION:** a zero overlap can be a property of the published file and not of
the mathematics. The Beierle et al. 2025 file is named `new_apns.txt` and holds
only the functions that the authors considered new, so its zero overlap is
expected. The CSV carries a `note` column for exactly this, and the paper must
print it.

---

## Group C — the algorithms, compared by what they prove

The user's objection stands: a comparison of raw cost between an equivalence
test and a linear-algebra routine repeats a definition. The comparison that
does carry information divides the cost by the evidence that it buys.

### C1. `invariant_power.csv` — cost against discriminating power

**Question.** Which invariant should run first, and what does each one buy?

**Axes.** The invariant (σ-signature, ortho-derivative differential spectrum,
ortho-derivative Walsh spectrum, the APN-EA mugshot, the Π multiset, the
component degree spectrum, the differential spectrum of `F` itself, the
absolute Walsh spectrum of `F` itself, the Gamma-rank, the Delta-rank) against
a population (the curated catalog at each `n`, and a seeded sample of each
`n = 8` corpus).

**The columns.** `population_size`, `evaluated`, `undefined`, `errors`,
`distinct_values`, `largest_bucket`, `singleton_buckets`,
`pair_separation_rate`, `bench_seconds_per_call`, `measured_seconds`, `status`.

`undefined` counts the functions for which the invariant has no value, for
example the ortho-derivative of a function that is not quadratic. An undefined
result never becomes a bucket, or "the invariant does not apply here" would read
as "every one of these functions has the same invariant".

**Why it is not trivial.** The differential spectrum of a quadratic APN
function is the same for every member of the population, so it separates
nothing at any cost. The σ-signature costs about 0.4 ms at `n = 8` and
separates almost every pair. The Gamma-rank costs 167 s and adds little that σ
did not already give. The ratio, and not the cost, is the result: it produces
the order in which a search should apply its filters.

**The discussion it opens.** A search that deduplicates with a necessary but
insufficient invariant reports a lower bound on its class count and calls it a
count. Finding F021 of the audit records this defect in the repository's own
QAM search. C1 measures how large the gap can be.

**CAUTION:** every invariant here is necessary and not sufficient, except where
the paper states otherwise. A collision is not a proof of equivalence. The
`status` column says `measured`, `stopped_budget` (the wall clock passed the
budget and the row holds a partial count), `skipped_budget` (the estimated cost
passed the budget before the work started) or `not_applicable` (the dimension is
above the guard of the source). A missing row therefore never reads as a zero.

### C2. `method_completeness.csv` — what an algorithm can prove

**Question.** Which algorithms can support a negative statement?

**Axes.** The finding, and through it the paper and the method, against the
completeness class of the method (`complete_within_region`, `pruned_search`,
`heuristic`, `randomized`, `unknown`) and the region that stays unexplored.

**Why it is not trivial.** This is the axis that decides whether "we found no
new class" means anything. A fast heuristic and a slow exhaustion give the same
output format and carry opposite weight. The table pairs the completeness class
with the size of the region left, so a reader sees the exact strength of every
negative claim in the collection.

**The discussion it opens.** It is the natural companion of the reach limits.
One says what the method proves; the other says how far the machine goes.

---

---

## How to read each table in one line

| File | Read it as |
|---|---|
| `papers.csv` | one row per reproduced paper; every other table of group A aggregates it |
| `findings.csv` | one row per audit defect, flattened out of `audit/findings.yaml` |
| `reproduction_by_method.csv` | "papers of topic X reproduce like this and carry this many defects" |
| `reproduction_by_year.csv` | the same, against the publication year |
| `defect_kind_by_tier.csv` | "a defect of kind X was found at tier Y"; the `recomputed` rows are the defects that reading cannot find |
| `evidence_vs_outcome.csv` | "papers that scored X on criterion R carry this many defects each" |
| `method_completeness.csv` | "the method behind this finding can or cannot support a negative claim" |
| `method_by_dimension.csv` | "method group X reaches dimension n with this many functions" |
| `evidence_depth.csv` | "a novelty verdict at dimension n compares against this many known classes" |
| `corpus_sigma.csv` | "corpus X holds this many members and this many provably distinct classes" |
| `corpus_overlap.csv` | "corpus X and corpus Y share this many classes" |
| `invariant_power.csv` | "invariant X costs this much and separates this share of the pairs" |

## How the tables connect

Three joins carry the argument of the paper.

1. `papers.csv` joins to `method_by_dimension.csv` through `method_group`. It
   asks whether the methods that produce the most functions are the methods
   that reproduce.
2. `corpus_sigma.csv` joins to `evidence_depth.csv` through `n`. It asks what a
   novelty claim is worth at each dimension.
3. `invariant_power.csv` joins to `method_completeness.csv` through the method.
   It asks whether the filter that a search used was strong enough for the
   claim that the search made.

## What to draw

- **A heatmap** for B1: method group against dimension, filled by σ-classes and
  not by records. It is the figure the paper already has, with the fill
  corrected.
- **A second heatmap** for A4: defect kind against verification tier. The
  bottom-right corner holds the defects that only recomputation finds.
- **A scatter** for C1: cost on one axis, pair separation on the other, one
  mark per invariant. The useful invariants sit in the top-left corner.
- **A bar chart** for A2: one bar per method group, split by outcome.
- **A matrix** for B4: source against source. Most cells are empty, and the
  empty cells are the result.

Use no figure for group C2 or for B2. Both are tables of a few rows, and a
figure would hide the numbers.

## What is drawn, and by what

`packages/VBFRepro/analysis/reproductions/figures.jl` renders the figures and LaTeX tables the manuscript reads.
Run it with `make -C packages/VBFRepro/analysis figures`. It reads the CSVs above and writes only
into the explicitly selected figure directory; it recomputes no metric and opens no database, so
a figure cannot disagree with the table it came from. It borrows the resolved
shared analysis environment in `packages/VBFRepro/analysis`.

Four of the five drawings above are implemented. C1 is not a scatter: on the
population it uses, separation is bimodal, so the second axis held no
information. It is a cost chart, ordered by cost, with separation as the colour
and the exact share printed at each mark. B4 is not drawn at all, because its
one result — that `beierle2025_n8` shares no signature with any other source —
is one sentence and does not need a matrix.

`packages/VBFRepro/analysis/reproductions/curated_bfa4r.csv` holds the author's BFA-4R grades for the 40 graded
papers. It is a SOURCE, not a generated file: the grades are an expert reading
that overrides the automatic first pass from `packages/VBFRepro/analysis/reproductions/grades.jl`,
and the two disagree on most papers. `figures.jl` renders both the per-paper
table and every aggregate from this one file, so the totals in the text can
never drift from the table the reader sees. Any aggregate over BFA-4R grades
must come from here and never from `evidence_vs_outcome.csv`, which grades 42
papers from the automatic pass.

Four paper ids are spelled differently in the two sources (`Yu_202211`/`Yu_202211d`,
`Calderini_202009a`/`Calderini_202009`, `Yuyin_201307`/`Yuyin_201300`,
`Chase_202110a`/`Chase_202110`). `figures.jl` maps them and fails loudly if any
curated row stops joining, rather than silently dropping it from an aggregate.
