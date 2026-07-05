# Skill: review-paper

Use this skill when the user asks to review, audit, or verify one or more paper
reproductions in this repo (e.g. `/review-paper Yu_202012`, "review the paper I
just reproduced", "audit these reproductions"). This skill is a thin launcher: it
resolves which papers to review, then delegates the actual review to the
**`paper-reproduction-reviewer`** subagent (defined in
`.claude/agents/paper-reproduction-reviewer.md`).

Do **not** re-derive review logic here — the agent owns it. This skill only picks
the targets and dispatches.

---

## 1. Resolve target paper IDs

A paper ID is the name of a directory under `papers/` (author–year slug, e.g.
`Canteaut_201906`). Resolve targets in this order:

1. **Args given** — treat each whitespace/comma-separated arg as a paper ID. Use
   them verbatim.
2. **No args — git fallback.** Detect papers touched in the working tree and
   recent history, in this order until non-empty:
   ```bash
   # a) uncommitted changes (modified + untracked), mapped to paper IDs
   git -C "$(git rev-parse --show-toplevel)" status --porcelain \
     | grep -oE 'papers/[^/]+/' | sed -E 's#papers/([^/]+)/#\1#' | sort -u
   # b) if (a) empty: papers touched in the last commit
   git -C "$(git rev-parse --show-toplevel)" show --name-only --pretty=format: HEAD \
     | grep -oE 'papers/[^/]+/' | sed -E 's#papers/([^/]+)/#\1#' | sort -u
   ```
3. **Still empty** — do not guess. Ask the user which paper ID(s) to review, or
   suggest listing candidates with `ls papers/`.

### Validate before dispatch
For each resolved ID, confirm `papers/<ID>/` exists and `papers/<ID>/input/`
holds `.tex` (or PDF) source. If a directory is missing, report it as **Blocked**
and drop it from the batch — do not fabricate a review. If an ID looks like a
typo of an existing dir, surface the closest match instead of proceeding.

---

## 2. Dispatch to the reviewer agent

Spawn the **`paper-reproduction-reviewer`** subagent via the Agent tool with
`subagent_type: "paper-reproduction-reviewer"`. Pass **all** validated paper IDs
in a **single** agent invocation (the agent handles multi-paper batches and adds
its own cross-paper ranking) — do not spawn one agent per paper.

Prompt the agent with exactly the resolved ID list, e.g.:

> Review the following paper reproduction(s): `<ID1>`, `<ID2>`. Read each paper's
> LaTeX source under `papers/<ID>/input/` as ground truth and compare against the
> reproduction. Run reproduction tests where reasonable. Read-only — do not modify
> files.

If the user added qualifiers ("just check the APN novelty claim", "only run the
tests", "focus on Theorem 3"), forward them verbatim into the agent prompt.

---

The reviewer also reports, per paper, a **Catalog status** (each claimed-new APN →
present / missing / not-new / unverifiable, with **Catalog-gap records** for any
genuinely-new function absent from VBFCatalog) and a **Library-reuse audit**
(helpers that duplicate `VBF` core exports, plus promote-to-core candidates). It
stays read-only and writes nothing.

---

## 3. Output

**Chat only.** Relay the agent's verdict inline to the user. Do **not** write any
`REVIEW.md` or other file unless the user explicitly asks. Lead with the summary
verdict(s) (Complete / Mostly complete / Partial / Missing / Blocked) and the
concrete next-action checklist; keep the full per-item breakdown available but
don't bury the verdict under it. Surface any **catalog gaps** and **reuse
violations** in the summary — they are the actionable follow-ups.

---

## 4. Present next-step options (always, after every review)

After relaying the verdict, **end the response with an explicit next-step menu**
so the user can address the identified gaps immediately instead of re-prompting.
Build the menu from the findings — only offer steps that map to something the
review actually flagged. Use the **`AskUserQuestion`** tool (multiSelect) so the
user picks in one click; label each option with the concrete action and the paper
ID / count it targets.

Derive options from the findings:

- **Catalog gaps found** → "Add N new APN function(s) to VBFCatalog" — runs the
  **`apn-catalog-updater`** agent (`subagent_type: "apn-catalog-updater"`) with
  the Catalog-gap records passed verbatim. That agent re-verifies APN + novelty
  before writing the `[[apn_functions]]` block.
- **Reuse violations found** → "Refactor helpers to reuse VBF core" — edit
  `papers/<ID>/helpers.jl` to call the `VBF` export, or promote a genuinely
  missing primitive into `packages/VBF/src/`. Separate edit task.
- **Partial / Missing / incorrect items** → "Fix reproduction gaps in `<ID>`" —
  address the specific unreproduced theorems, failing tests, or wrong formulas the
  review named.
- **Blocked items** → "Resolve blockers for `<ID>`" — e.g. supply missing
  `input/*.tex`, install a missing dep, or clarify the target.
- Always include a **"Nothing — done for now"** escape option.

If the review found **no** gaps (verdict Complete, no catalog/reuse issues), say so
and skip the menu — do not manufacture busywork.

**Nothing runs automatically.** The menu only gathers the user's choice; execute a
follow-up only after they select it. On selection:

- Catalog gaps → dispatch `apn-catalog-updater` with the records.
- Reuse / reproduction / blocker fixes → do the edits directly (or via the
  relevant subagent), scoped to what the user picked.

Run the review first; act on the menu only after the user chooses.

---

## Notes

- The reviewer agent is **read-only**. All mutation (catalog writes, helper
  refactors, gap fixes) happens in the §4 next-step menu after user selection,
  never inside the review pass.
- Keep this skill in sync with the agents: if the reviewer agent's name, the
  `apn-catalog-updater` name, the `papers/<ID>/input/` layout, or the catalog path
  `packages/VBFCatalog/data-raw/apn_catalog/n<N>_apn.toml` changes, update the
  relevant steps here.
