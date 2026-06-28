# Agent Instructions

## Paper reproductions

When implementing a paper under `papers/<Paper_ID>/`, follow the organization
used by `papers/Beierle_202201`: keep one paper claim, theorem, lemma,
algorithm, table, or experiment per file; make each file runnable on its own;
and make the code layout mirror the publication closely enough that the paper
can be read side-by-side with the implementation. Prefer paper-facing
orchestration in the paper directory and reuse package APIs for shared math.

<!-- lean-ctx -->
## lean-ctx

Prefer lean-ctx MCP tools over native equivalents for token savings:
`ctx_read` > Read/cat, `ctx_search` > Grep/rg, `ctx_shell` > bash, `ctx_tree` > ls/find.
Native Edit/Write/Glob stay as-is; use `ctx_edit` only when Edit needs an unavailable Read.
Full rules: LEAN-CTX.md (open on demand — do not auto-load).
<!-- /lean-ctx -->
