---
name: rework
description: Revise an existing planning artifact — a structured prompt, a specification, or an implementation plan — addressing concrete feedback. Always clarifies the rework task via prompt first, then delegates to the matching skill (specify for a spec, implement for a plan) to redo it to the senior bar. Use when asked to rework/revise/fix an existing prompt, spec, or plan.
---

When this skill is invoked, you are **revising an existing artifact**, not
starting from scratch and not implementing. First make the rework task explicit,
then hand it to the skill that owns that artifact type.

## Input

A path to an existing artifact:

- a **structured prompt** — `.agents/prompts/…` (contains a `<task_spec>` block)
- a **specification** — `.agents/specs/…` (a `# Spec:` document)
- an **implementation plan** — `.agents/plans/…` (a `# Implementation Plan:` document)

…plus the user's rework intent (what's wrong / what to change). If no path is
given or its type is unclear, **ask** — don't guess which artifact is meant.

## Procedure

1. **Read the target and its lineage.** Read the artifact and identify its type
   (by location and content). Follow its links — a spec's `Source prompt`, a
   plan's `Spec`. Understand the original intent before changing it.
2. **Clarify the rework with `prompt` (always first).** Run it to
   capture *what* about the artifact must change, *why*, the constraints, and the
   acceptance criteria for the rework itself. Feed it the existing artifact and
   any review feedback as context. This **must** write a new clarified prompt
   file to `.agents/prompts/` (a fresh `date +%s` name) — never skip it or reuse
   an earlier prompt. Resolve its open questions and **wait** — a rework with a
   vague goal ("make it better") is not ready to execute.
3. **Delegate to the matching skill — reusing the prompt from step 2.** You have
   already run `prompt`; when you follow the skill below, start at the
   step that *consumes* the structured prompt — **do not invoke prompt
   again.**
   - **Target is a spec** → follow the `specify` skill: re-verify against current
     code, then rewrite the spec to its senior bar, addressing the rework.
   - **Target is a plan** → follow the `implement` skill from its planning step:
     re-verify the spec, then rewrite the plan, addressing the rework; honor its
     review and confirmation gates.
   - **Target is a structured prompt** → the clarified prompt from step 2 *is* the
     reworked prompt; update the target file with it. If the user wants to go
     further, hand off to `specify`.
4. **Update in place.** Rework the existing artifact at its current path/slug —
   do not spawn a parallel copy (that fragments prompt ↔ spec ↔ plan). Note what
   changed and why (in the handoff, or a short "Revised:" line at the top).
5. **Inherit the downstream gates.** Stop where the delegated skill stops
   (`specify`: after the spec; `implement`: plan-approval, then explicit
   start-implementation). Never auto-commit.

## The senior bar (non-negotiable)

- **Fix the named gaps; keep what was right.** Address the concrete feedback —
  don't rewrite wholesale and don't discard sound prior decisions. If the rework
  request is vague, the prompt step must pin it down before you act.
- **Re-verify against current code.** Artifacts drift from the code after they're
  written; re-check every fact the revision depends on (`path:line`), and use the
  `analyze` skill's live access where the project offers it. Read
  `.agents/project.md` for the operational ground truth (stack, commands,
  invariants); if it looks stale against the current repo, flag it or refresh it
  via `orient` before relying on it.
- **Apply the delegated skill's full bar** — verification, threat-model
  calibration, project invariants, precise non-destructive edits, testable
  acceptance criteria. Rework is not a shortcut around quality.
- **Traceability.** Keep the prompt ↔ spec ↔ plan names aligned so the revised
  artifact stays linked to its lineage.

## Rules

- Requires a path; if missing or its type is ambiguous, ask before proceeding.
- Always run `prompt` first; then delegate to `specify` (spec) or
  `implement` (plan), reusing that prompt — never double-run prompt.
- Revise the artifact in place at its existing location; don't create a duplicate.
- Honor the delegated skill's stop-for-review gates. Never commit or push.
