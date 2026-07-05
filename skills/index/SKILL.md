---
name: index
description: Deterministically catalog and search a project's .agents/ artifacts (prompts, specs, plans, verifications) plus project.md's sections into .agents/index.md, so other skills can look up prior work without rereading full files. Provides reindex.sh (regenerate the catalog from the artifacts' own headers) and query.sh (keyword pre-filter over the catalog, falling back to full-text search). Consumed automatically by the other skills' persist and context-loading steps; also directly invocable for an ad hoc "what's already been done here" query or a manual rebuild after hand-editing .agents/.
---

This skill has no LLM judgment step of its own — it is a thin wrapper around
two deterministic scripts, the same way `verify` wraps `preflight.sh`. When
invoked directly, run one of the scripts below (next to this skill, wherever
your agent loaded it from — `~/.vibe/skills/index/`, `~/.claude/skills/index/`,
or `.github/skills/index/`) and report the result.

## `reindex.sh [project-root]`

Regenerates `.agents/index.md` **in full** on every run — never an
incremental append or merge. It rescans
`.agents/{prompts,specs,plans,verifications}/*.md` and `.agents/project.md`
and extracts Type/Slug/Date/Status/Title/Links straight from each artifact's
own structured header (the same `- **Field:**` lines the
`prompt`/`specify`/`implement`/`verify` templates already require), plus a
heading→line-number map for `project.md`'s sections. Because nothing is ever
appended, there is no "stale row pointing at a deleted file" state to repair —
deleting an artifact and rerunning removes its row automatically.

## `query.sh <keyword> [<keyword> ...]`

A deterministic keyword pre-filter, not a relevance oracle. It always runs
`reindex.sh` first, then greps the index for the given keywords (matching
against every column, in practice mostly hitting Slug/Title), falling back to
a full-text search across the artifact directories if nothing matches the
index. **This mechanizes *matching*, not *relevance*** — a keyword hit is a
mechanical fact ("this string appears here"); deciding whether the matched
artifact is actually relevant to the current task is still the calling
skill's judgment call, the same call it would make reading a directory
listing. Never read a `query.sh` result as proof of relatedness.

## Rules

- Never hand-edit `.agents/index.md` — it is generated; rerun `reindex.sh`.
- Other skills call `query.sh` (never open `.agents/index.md` directly) so
  that what they see is always current, regardless of whether an earlier
  skill's own "refresh the index" step actually ran.
- No new runtime dependency: bash + coreutils only, same as
  `skills/verify/preflight.sh`.
