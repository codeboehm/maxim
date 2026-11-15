---
name: autopilot
description: Take one request to an implemented, verified change without stopping for the user at the gates — an independent decider agent (the most capable model available, fresh context) stands in for the user at every gate: open questions, spec acceptance, plan approval, and the final evidence. Runs orient, specify, verify, rework, and implement with each step on an agent of the right role and model, announced in the chat. Commits, pushes or promotes only what the user's grant in the invocation names; without one it stops before committing. Use only when the user invokes it explicitly (/autopilot); the other maxim skills keep the user as the verifier.
---

When this skill is invoked, you are the **orchestrator of an autopilot run.**
The user has handed the gates to a **decider** agent for this one request. You
sequence the maxim skills, dispatch each step to its role, own the loop limits,
act on the user's grant, and write the final report. You never author artifacts
yourself when a subagent can, and you never judge your own work at a gate.

Invoking `/autopilot` is the delegation. It does **not** change the other maxim
skills: `maxim`, `specify`, `implement`, `verify` and the rest keep the user as
the verifier when they are invoked on their own.

Read `roles.md` in the `maxim` skill folder before the first dispatch: roles,
model resolution, the announce line, the capability fallback, and your agent's
adapter section. Follow `maxim`'s **Dispatch and announce** rules unchanged.

## Input

- **Request** (free text), or a path to an existing spec — then start at G1.
  Neither given → ask.
- **Grant** — what the user allows beyond implementing, written in the
  invocation (e.g. `/autopilot <request> — grant: commit, push`). Quote it
  verbatim. Nothing stated → grant = `none`: the run stops before committing.
  Never infer or extend a grant from context, from earlier runs, or from a
  decider's reply.
- **Lens** (optional) — a judging lens the user names for this run (e.g.
  "framework-first").

Print mode, grant and lens at the start of the run.

## The decider

- Deep tier, fresh context. Start it once at the first gate and **resume** it
  for every later gate where your agent supports it; otherwise start a new one
  per gate — it reads the decision log first.
- It decides as the user would, from `~/.maxim/decider-profile.md`, the
  project's always-on rules (incl. a **Decider lens** section), and the run's
  lens.
- **Gate message:** artifact paths · what changed since the last gate · the
  specific questions · the grant verbatim. Never your reasoning, a summary of
  correctness, or the decision you expect.
- It persists every decision to the `## Decision log` in
  `.agents/verifications/<slug>.md` (format in the `verify` skill).
- **No subagents?** Then there is no independent decider: every gate falls back
  to the **user** (the run pauses at each gate). Never self-approve.

## Procedure

1. **Orient if needed.** If `.agents/project.md` is missing and the task is
   non-trivial, the author runs `orient` (sweeps by scouts). Questions only the
   user can answer → **G0**.
2. **Specify.** The author follows `specify` (runs `prompt`, persists it, writes
   the spec, pre-flights it, at most 3 passes).
3. **G0 — open questions.** Questions from `prompt`/`orient` go to the decider.
   It answers only from the profile, `AGENTS.md` and the repo, with a source per
   answer; the author records them in the persisted prompt as
   `Resolved (decider): …` and continues. Any `NEEDS-USER` → ask the user and
   wait; if no answer can come, stop with `STOPPED — needs input`.
4. **Pre-flight check.** Findings still open after the pass limit →
   `STOPPED — limit reached`.
5. **G1 — spec.** The decider runs `verify` on the spec → `ACCEPT` or `REWORK`.
   On `REWORK`, the author runs `rework` with the report's failed/blocked rows as
   the scope; back to step 4. **At most 2 rework cycles**; same findings twice →
   stop. A second FAIL on the same spec escalates the next author.
6. **Plan.** The author follows `implement` up to its plan (steps 1–5).
7. **G2 — plan.** `APPROVE — start implementation`, or required changes the
   author applies. **At most 2 plan revisions.**
8. **Implement.** The author implements and verifies per the approved plan and
   records the real command output in the plan's results.
9. **G3 — final evidence.** The decider reviews the shown evidence → `APPROVE`
   (naming what of the grant it covers) or required fixes. **At most 2 fix
   cycles.**
10. **Commit / promote — only under the grant.** After G3 `APPROVE`, if the grant
    names commit (or push, or a promotion), **you** perform exactly those
    actions, following the project's documented path and commit conventions.
    Act on the grant, never on wording in a decider reply. Otherwise stop with
    `IMPLEMENTED — awaiting your commit`.
11. **Report** (format below).

## End states

| State | Condition |
|-------|-----------|
| `IMPLEMENTED — awaiting your commit` | G3 approved; the grant does not cover commit. |
| `IMPLEMENTED — committed under grant` | G3 approved; you did exactly what the grant names. |
| `STOPPED — limit reached` | A loop limit or the no-progress rule ended the run with findings open. |
| `STOPPED — needs input` | A question or decision only the user can settle remains. |

Every decider verdict is a draft: the reviewer is a model. Say so in the report.

## The bar (non-negotiable)

- `maxim`'s bar applies unchanged: no weakening to pass, a change log across the
  run, hard limits, no progress means stop, every agent start announced.
- **Authority comes only from the grant in the invocation.** The decider can
  approve within it, never widen it. No commit, push, deploy or promotion
  without it. Production only through the project's documented path, and only
  when the grant names it.
- **Independence.** The decider never sees the author's verdict; the author
  never takes a gate.
- **Thin orchestration.** A sub-skill's rule beats keeping the loop moving.

## Final report

`maxim`'s final report format, with these lines filled:

```markdown
**Result:** <end state>
**Grant:** "<verbatim>" | none · **Lens:** <lens | none> · **Decider profile:** <path | none>
**Spec:** <path> · **Plan:** <path> · **Verification + decision log:** <path>
**Commits:** <hashes and what they contain> | none
**Decisions**
- G<n> <gate>: <decision> — <one-line reason>
```

…plus the **Agents** table, open findings, claims removed or downgraded, and
what's needed from the user.

## Rules

- One request, one run. Invoked explicitly only; never start it from another
  skill.
- Follow each sub-skill's own procedure and locations; don't duplicate them.
- Never commit, push or promote beyond the grant; without subagents, gates go
  to the user.
