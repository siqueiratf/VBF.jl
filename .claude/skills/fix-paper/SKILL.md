# Skill: fix-paper

Use this skill when the user asks to fix, resolve, or repair reproduction issues
in one or more papers (e.g. `/fix-paper Canteaut_202205`, "fix the issues in the
paper I just reviewed", "resolve reproduction issues"). This skill is a launcher:
it resolves which papers to fix, then delegates to the **`paper-issue-fixer`**
subagent.

**Prerequisite:** The target paper(s) must have a `packages/VBFRepro/src/<ID>/README.md` with a
`### Reproduction Issues` section. This README is produced by the `review-paper`
skill. If no README exists, tell the user to run `/review-paper <ID>` first.

---

## 1. Resolve target paper IDs

Same resolution logic as `review-paper`:

1. **Args given** — treat each whitespace/comma-separated arg as a paper ID.
2. **No args — git fallback.** Detect papers touched in the working tree:
   ```bash
   git -C "$(git rev-parse --show-toplevel)" status --porcelain \
     | grep -oE 'packages/VBFRepro/src/[^/]+/' | sed -E 's#packages/VBFRepro/src/([^/]+)/#\1#' | sort -u
   ```
   Then recent commits if empty:
   ```bash
   git -C "$(git rev-parse --show-toplevel)" show --name-only --pretty=format: HEAD \
     | grep -oE 'packages/VBFRepro/src/[^/]+/' | sed -E 's#packages/VBFRepro/src/([^/]+)/#\1#' | sort -u
   ```
3. **Still empty** — ask the user which paper ID(s) to fix.

### Validate before dispatch

For each resolved ID:
- Confirm `packages/VBFRepro/src/<ID>/` exists.
- Confirm `packages/VBFRepro/src/<ID>/README.md` exists and contains `### Reproduction Issues`.
- If README is missing, report it and suggest running `/review-paper <ID>` first.
- If the Reproduction Issues section says "None found.", skip that paper and
  tell the user there's nothing to fix.

---

## 2. Pre-flight: show what will be fixed

Before dispatching, read each README's Reproduction Issues section and present
a summary to the user:

```
Paper: <ID>
  - Issue 1: <one-line summary> [RESOLVED / unresolved]
  - Issue 2: <one-line summary> [RESOLVED / unresolved]
  ...
  Unresolved: N issues to attempt
```

Count already-resolved issues and unresolved ones. If all are resolved, skip
that paper. If the user provided specific issue numbers or keywords, note which
issues will be targeted.

---

## 3. Dispatch to the fixer agent

Spawn the **`paper-issue-fixer`** subagent via the Agent tool with
`subagent_type: "paper-issue-fixer"`. Pass all validated paper IDs in a single
invocation.

Prompt the agent with:

> Fix reproduction issues in the following paper(s): `<ID1>`, `<ID2>`.
> Read each paper's `packages/VBFRepro/src/<ID>/README.md`, extract the Reproduction Issues,
> and resolve each unresolved issue. Run tests after fixing. Update the README
> to mark fixed issues as [RESOLVED]. Repository root is `<repo_root>`.

If the user narrowed scope ("just fix issue 1", "only the stale assertion"),
forward that constraint into the prompt.

---

## 4. Output

Relay the fixer agent's report to the user. Lead with:

- **Per paper:** issues fixed / skipped / needs-manual-intervention
- **Test results:** pass/fail after fixes
- **Files modified**

Then list any issues needing manual intervention with clear explanations of
what decision the user needs to make.

---

## 5. Auto-commit via Git Agent (mandatory post-step)

After the fixer agent completes and **at least one issue was fixed**, immediately
spawn the **`git-committer`** subagent via the Agent tool with
`subagent_type: "git-committer"`.

**This step is automatic** — do not ask the user for confirmation. The git-committer
handles its own safety checks (runs `make test` before committing).

### Pre-condition

Only dispatch the git-committer if:
- The fixer agent reported at least one fix.
- The fixer agent's test run passed (or was not run due to missing Makefile —
  the git-committer will run tests itself as its own pre-condition).

If the fixer's tests **failed**, skip the git-committer step and report the
failure to the user. Do not commit broken code.

### Dispatch

Prompt the git-committer with:

> Create atomic commits for the fixes in paper `<ID>`. The following issues
> were fixed: <list of issue numbers and one-line summaries from the fixer
> report>. Repository root is `<repo_root>`. Run `make test` before committing.

### Report

After the git-committer returns, append its commit report to the output:

- **Commits created:** (list of short hashes and subjects)
- **Uncommitted files:** (if any)

If the git-committer halted due to test failure, report that clearly.

---

## 6. Follow-up (explicit, opt-in)

After fixing and committing:
- If tests still fail, offer to investigate further.
- If the user wants, offer to re-run `/review-paper <ID>` to regenerate the
  README with updated status.
- If fixes touched `helpers.jl` reuse patterns, mention that a follow-up
  review may catch further reuse opportunities.

---

## Notes

- This skill is the **write** counterpart to `review-paper` (read-only).
  The pipeline is: `/review-paper` → README with issues → `/fix-paper` →
  issues resolved → `git-committer` → atomic commits.
- The fixer agent never touches Paper Issues — only Reproduction Issues.
- The fixer agent never modifies `packages/VBFRepro/src/<ID>/input/` source material.
- The git-committer never modifies files — it only stages and commits.
- Keep this skill in sync with the `paper-issue-fixer` and `git-committer`
  agent definitions and the README format produced by `review-paper`.