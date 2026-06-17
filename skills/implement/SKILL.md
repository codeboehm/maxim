---
name: implement
description: Implement a previously written specification, senior-grade. Takes a path to a spec, writes a reviewed implementation plan to the project's plans location, iterates with the user, and only writes code after explicit confirmation — then implements with tests and verification. Use when asked to implement/build/execute a spec.
---

When this skill is invoked, **do not start coding.** There are two gates before
any code is written: (1) an implementation **plan** the user has reviewed and
approved, and (2) an explicit **"start implementation"** go-ahead. Your first
deliverable is the plan, not the change.

## Input

A path to a spec (e.g. `.agents/specs/<slug>.md`), normally produced by the
`specify` skill. If no path was given, or the path doesn't resolve, **ask for
it** — do not guess which spec is meant or invent one.

## Procedure

1. **Read the spec** at the given path, plus its `Source prompt` and any specs it
   references.
2. **Load context.** Read the project's `AGENTS.md` (root + any closer to the
   area) for invariants and conventions, the relevant project skills/docs, and
   the actual code in scope with its comments.
3. **Re-verify the spec against current code.** Specs drift — confirm the files,
   line references, signatures, and behavioral claims it relies on still hold. If
   the code has moved on, **stop and flag it** before planning; do not plan on
   stale facts. Where the project has live access (logs, DB, agent endpoints — see
   the `analyze` skill), use it to confirm current behavior, not just the source.
4. **Write the plan** to the project's plans location (see Locations), using the
   template below. The plan refines the spec's implementation section into
   ordered, independently verifiable steps grounded in the *current* code, with a
   test strategy.
5. **Present the plan for review and iterate.** Summarize it, surface the risky
   decisions, and revise with the user until they approve it. Keep the stored
   plan file in sync with each accepted change.
6. **Stop at the confirmation gate.** Do not write code until the user explicitly
   confirms to start implementation.
7. **Implement** story-by-story per the approved plan, honoring The senior bar.
8. **Verify** against the spec's acceptance criteria — run the tests, lint, and
   build; report the real output.
9. **Hand off for review.** Summarize what changed, any deviation from the
   plan/spec and why, test/verification results, and residual risk. **Never
   commit or push** — that is the developer's call.

## Locations

Use the conventions in the project's `AGENTS.md`. If it specifies a plans
location, use it. Otherwise default to `.agents/plans/<kebab-slug>.md`, reusing
the spec's slug so plan ↔ spec ↔ prompt are traceable by name (create the
directory if missing). Never put the plan inside a tool's own config dir.

## The senior bar (non-negotiable)

- **Plan before code, in small steps.** Each step names the files it touches,
  states the change as a post-condition (not "edit lines X–Y"), gives its
  dependency/order, and says how it will be verified. Sequence so the codebase
  stays working between steps where possible.
- **Right-size the work.** Implement only what the spec requires. No
  gold-plating, no abstractions/queues/caches/config knobs the task doesn't need.
  Over-engineering is a defect.
- **Read before you edit; match the surroundings.** Read each file before
  changing it. Match the existing style, naming, idioms, and error-handling
  conventions — the change should read like the code already there.
- **Test the acceptance criteria.** A change is not done until its acceptance
  criteria are demonstrably met. Write or extend tests that exercise them and
  **run them**. If the area has no tests, add the minimal ones that prove the new
  behavior. If automated testing genuinely isn't feasible, say so and state
  exactly how you verified instead (commands run, output observed).
- **Verify, don't assume.** Run the real tests/lint/build and report actual
  output. If something fails, say so plainly with the error — never claim done on
  an unverified change.
- **Handle failure paths.** Cover malformed/hostile input, mid-operation
  failure, and missing/erroring dependencies — proportional to blast radius
  (rigorous around data, auth, money, irreversible or external actions; lean
  elsewhere).
- **Honor project invariants** from `AGENTS.md`: layering and naming rules;
  mirrored/duplicated files that must stay in sync (run the sync + the
  verification command); generated artifacts (e.g. minify/build steps); commit
  ordering. Applying these is part of "done" — **except committing, which you
  never do automatically.**
- **Keep the operational profile current.** If the change alters the project's
  operational surface — a new or removed dependency, a new build step or
  generator, a new command, a new env var/secret, a new service, a
  generated/mirrored artifact, or a deploy change — update `.agents/project.md` to
  match (provenance-tag the new facts, or re-run `orient` to refresh). A stale
  profile silently misleads every later `prompt`/`specify`; treat updating it as
  part of "done," like a mirror-file sync — but, as ever, never commit it
  automatically.
- **Surface deviations, don't bury them.** If implementing reveals the spec or
  plan was wrong or incomplete, stop and flag it; get agreement before diverging.
  Update the plan file to match what was actually done.
- **Two gates, always.** No code before the plan is approved; no commit/push ever
  without the developer's explicit instruction.

## Plan template

```markdown
# Implementation Plan: <Title>

- **Spec:** <path to the spec>
- **Date:** <YYYY-MM-DD>
- **Status:** Draft — pending approval

## Summary
One paragraph: what will change and the overall approach.

## Spec re-verification
What you re-checked against current code, and any drift from the spec (with
`path:line`). Resolve or flag before proceeding.

## Steps
Ordered, independently verifiable. For each:
1. **<step>** — files touched; the change as a post-condition; dependencies/order;
   how it will be verified.

## Test strategy
Which acceptance criteria each test covers; new vs. existing tests; the exact
commands to run; what "pass" looks like. Manual checks where automation isn't
feasible (with the why).

## Project-invariant steps
Mirror-file syncs + verification, build/minify, layering/naming checks, and the
commit order to follow later (commit happens only on the developer's explicit go).

## Risks & rollback
What could break, blast radius, and how to back out.

## Open questions
Anything to resolve before or during implementation.
```

## Rules

- Requires a spec path; if missing or unresolved, ask — don't proceed.
- Plan goes to the project's plans location, never inside a tool's config dir.
- Honor both gates: plan approved, then explicit "start implementation."
- The skill ends at an implemented, verified change handed off for review. It
  does not commit or push.
