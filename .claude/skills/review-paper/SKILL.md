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

## 4. Follow-ups (explicit, opt-in — never automatic)

The reviewer is read-only. Two possible follow-up actions, each requiring user
go-ahead:

- **Catalog gaps** — if the review emitted Catalog-gap records, offer to run the
  **`apn-catalog-updater`** agent (`subagent_type: "apn-catalog-updater"`),
  passing the records verbatim. That agent re-verifies APN + novelty before
  writing the `[[apn_functions]]` block. Do not invoke it unless the user asks.
- **Reuse violations** — if helpers duplicate core, offer to refactor
  `papers/<ID>/helpers.jl` to call the `VBF` export (or promote a genuinely
  missing primitive into `packages/VBF/src/`). Separate edit task; not part of the
  review.

Run the review first; act on it only after the user chooses to.

---

## Notes

- The reviewer agent is **read-only**. All mutation (catalog writes, helper
  refactors) happens in named follow-up steps, never inside the review pass.
- Keep this skill in sync with the agents: if the reviewer agent's name, the
  `apn-catalog-updater` name, the `papers/<ID>/input/` layout, or the catalog path
  `packages/VBFCatalog/data-raw/apn_catalog/n<N>_apn.toml` changes, update the
  relevant steps here.
