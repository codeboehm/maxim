---
name: specify
description: Produce a senior-grade, repo-verified specification before any code. Runs prompt, persists the structured prompt, then writes a reviewed spec to the project's specs location. Use when asked to specify, design, or scope a feature/change/fix before implementing.
---

When this skill is invoked, **do not implement.** Your job is to produce one
specification that a senior engineer would sign off on, then stop for review.
A thorough-but-naive spec is a failure here: the bar is *verified facts* and
*calibrated judgment*, not volume.

## Procedure

1. **Structure the request.** *If a structured prompt was already produced for
   this task (e.g. you arrived here from `rework`, or a prompt path was handed to
   you), skip this step and start at step 2 — do **not** re-run `prompt`, and do
   **not** wait for clarification; that gate is already closed.* Otherwise, invoke
   the `prompt` skill on the user's request, resolve its `<open_questions>` with
   the user and **wait** — do not continue on assumptions. Persist the resulting
   structured prompt to the project's prompts location (see Locations).
2. **Read the persisted prompt** back from that file — the file, not your memory
   of it, is the spec's input. (Its `Open Questions for User` being `None` /
   `Proceed` is itself the signal that step 1's gate is closed — continue.)
3. **Load context.** Read the project's `AGENTS.md` (root + any closer to the
   area), the relevant project skills/docs, related existing specs, and the
   actual code and its comments.
4. **Verify every claim against the repo** (see The senior bar). Open the files.
   Where the project has live access (agent endpoints, logs, DB queries — see the
   `analyze` skill), verify against the running system, not just the code.
5. **Write the spec** to the project's specs location, using the template below.
6. **Stop for confirmation.** Hand back a short summary and the spec path, and
   recommend an independent `verify` pass before the spec is acted on. Never
   start implementing from this skill.

## Locations

Use the conventions defined in the project's `AGENTS.md`. If it specifies paths
for structured prompts and specs, use those. Otherwise default to:

- Structured prompt → `.agents/prompts/<unix-timestamp>-<kebab-slug>.md`
- Specification → `.agents/specs/<kebab-slug>.md` (match the naming of existing
  specs in that folder)

Never invent a new specs/prompts home (e.g. under a tool's own config dir) when
the project already has one.

## The senior bar (non-negotiable)

These are the exact failure modes that separate a senior spec from a junior one.
Check each before writing.

- **Verify, don't assert.** Every file path, line number, method name, and
  behavioral claim must be confirmed against the actual repo — open the file,
  grep, run it. No claims from memory. Cite `path:line`. If you can't verify a
  fact, it goes in Open Questions, not the body.
- **Evidence gate — before you finalize.** For every load-bearing claim, the spec
  must show its proof: the command with its **actual output**, or the `file:line`
  excerpt you read. A *described or commented-out* command is not evidence. Any
  "X breaks / is safe / is required" claim must name the real caller(s) (from
  `grep`) **and** the gate at `file:line`. Don't write DEFINITIVE / PROVEN /
  SUPERSEDES or absolute always/never about behavior; label what you didn't run
  as an assumption.
- **Calibrate the threat model** (security-relevant changes). Name the actual
  adversary and what each artifact *actually* protects.
  - **Find the real trust root.** A value the caller chooses freely — e.g. a
    scope minted from a single shared secret — is *advisory*, not a boundary
    between actors; its absence elsewhere is not "privilege escalation." Ask what
    an attacker must already possess, and what that possession already lets them
    mint or reach.
  - **Trace which branch actually runs — and whether the branch you're reasoning
    about is reachable at all.** Two distinct traps:
    - *Mutually-exclusive branches.* In an `if/elseif` chain (or behind early
      returns / guard ordering) only one branch executes. A later check is dead
      for any case an earlier branch already matched — e.g. a second auth check in
      a later `elseif` does nothing when an earlier branch in the same chain
      already matches the request, so its condition is never even evaluated.
      Confirm a branch is reachable *before* reasoning about its condition.
    - *Alternative satisfiers.* When a gate accepts A *or* B *or* C (e.g. token OR
      grant-cookie OR session flag), verify what *each* path validates — a control
      enforced on one path is often absent on another (the scope checked on the
      token path may be dropped by the cookie/session path that actually carries
      the request). Then confirm which path the real call uses, and reason from
      *that* one.
  - **Read code comments and existing specs** to tell intended design from an
    accidental flaw — do not inflate documented, deliberate behavior into a
    "vulnerability."
  - **Right-size severity:** a narrow/theoretical risk gets one sentence, not a
    threat-analysis section with impact callouts. Reaching "intentional, no fix"
    is a fine outcome — but only with the *correct* rationale, and then record any
    non-obvious limitation (e.g. "scope stops being enforced once the grant is
    issued") rather than asserting the opposite.
- **Respect project invariants.** Read them from the project's `AGENTS.md` and
  honor them in the plan — layering rules, mirrored/duplicated files that must
  stay in sync (and the verification command), commit ordering, naming
  conventions, "never auto-commit," build/minify steps. If a change touches a
  mirrored or generated file, the plan must include the sync + verification.
  If it spans services or touches the DB schema, say so and break it into
  stories.
- **Precise, non-destructive edits.** Describe the target post-condition and
  preserve existing data flow. Do **not** write "delete lines X–Y" — that erases
  surrounding logic. Re-verify any line reference against current code before
  citing it.
- **Connect to what's documented.** Reference the skills, specs, and code
  comments you consulted. Don't re-derive in a vacuum and miss intent.
- **Acceptance criteria must hold as written.** Each one must be something you
  could run and have pass given the code paths you actually traced. Re-derive
  each against those paths; if a criterion would fail (e.g. "an X-scoped token
  cannot reach Y" when the grant/session path reaches Y regardless), the analysis
  is wrong — fix it, don't ship a false criterion.
- **Self-consistency pass before finishing.** Re-read the threat model, the
  approach/conclusion, and the acceptance criteria together — they must not
  contradict each other (don't call something a "hard boundary" in one section
  and then describe it being bypassed as a "feature" in another).
- **Right altitude & honesty.** Concept before code; testable acceptance
  criteria; explicit assumptions and out-of-scope. State it plainly if the scope
  is larger than the request implies, or if part of the request is a bad idea.

## Spec template

```markdown
# Spec: <Title>

- **Date:** <YYYY-MM-DD>
- **Status:** Draft — pending confirmation
- **Source prompt:** <path to the persisted structured prompt>
- **Affected layers / services:** <list>

## Problem & context
What is actually happening, verified against the repo. Cite `path:line` for every
factual claim. Describe the current behavior before proposing change.

## Assumptions & threat model
For security-relevant work: the adversary, what each artifact protects, and what
is intended-by-design vs. accidental. Otherwise: the assumptions and constraints
that must hold for this change to be correct.

## Approach
The design and why it fits the architecture. For cross-service or schema-touching
work, give the concept, then decompose into independently implementable stories.

## Affected files
| File | Layer | Change | Notes |
|------|-------|--------|-------|
Flag any mirrored/duplicated file — it requires editing all copies + the verify step.

## Implementation plan
Ordered, precise steps framed as post-conditions (not blunt line deletions),
preserving data flow. Include the mirror-sync + commit order when relevant.
Note where each step must be verified.

## Acceptance criteria
- [ ] Observable, testable condition.

## Out of scope / follow-ups
Things deliberately not addressed here (with a one-line reason or a tracking note).

## Open questions
Anything unverifiable or needing a product decision. Non-empty → resolve before
implementation.

## References
Skills, specs, and code comments consulted (with paths).
```

## Rules

- One spec per invocation. Keep every section tight — concrete sentences, no filler.
- Prompt and spec go to the project's conventional locations, never inside a
  tool's own config directory.
- This skill ends at a written spec and a stop-for-review. It does not implement.
