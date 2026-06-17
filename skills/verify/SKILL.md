---
name: verify
description: Independently fact-check a spec, plan, or analysis against the actual code. Re-derives every load-bearing claim from the repo, records each as a checkable evidence-ledger row (verified / refuted / unverified), and returns a PASS / FAIL / BLOCKED verdict. Use to gate a draft before acting on it, or when asked to validate, fact-check, or sanity-check an artifact.
---

When this skill is invoked, you are an **independent, skeptical reviewer.** Do
**not** trust the document's own citations or its conclusion — re-derive each
claim from the code yourself. Your output is a verdict plus a checkable evidence
ledger. You do **not** edit the document (that's `rework`); you judge it and say
exactly what's wrong.

You are the backstop against fake verification. A document that says "VERIFIED"
next to a claim, or shows a *commented-out* command as proof, has proven nothing
— treat such claims as Unverified until you run it yourself.

## Input

A path to the artifact to check (a spec, plan, or analysis — e.g.
`.agents/specs/<slug>.md`). If none is given or it doesn't resolve, **ask**.

## Procedure

1. **Run the mechanical pre-flight (first, always).** Run
   `bash ~/.vibe/skills/verify/preflight.sh <target>` on the artifact under
   review. It deterministically checks banned calibration words, contradictory
   conclusions, unresolvable `file:line` citations, bare file-path references
   that don't resolve (unless marked new), behavioral/security claims with no
   adjacent evidence, and quoted tokens that aren't at their cited line.
   A non-zero exit is an
   **automatic FAIL** on the items it reports — they block PASS regardless of the
   claim ledger, and you do **not** re-judge them by hand (the script is the
   source of truth, and it reports the *real* line numbers — don't paraphrase
   them). Carry its findings into the report, then continue the semantic checks
   below.
2. **Extract the load-bearing claims.** List the facts and assertions the
   document's conclusion/recommendation actually depends on. A claim is
   load-bearing if removing it would change the conclusion. Separate these from
   incidental detail — spend your effort here.
3. **Re-derive each one from the code yourself.** Open the cited file, `grep` for
   the real callers, run the command. The document citing `X:42` is a *starting
   point to check*, not evidence — confirm the line actually says what's claimed,
   and that the claimed behavior is **reachable on the real path** (watch
   `if/elseif` short-circuits, early returns, and alternative satisfiers like
   token-OR-cookie-OR-session).
4. **Record each claim as one ledger row** (format below): claim · load-bearing? ·
   verdict · evidence. Evidence is the **actual** `file:line` excerpt or command
   output — never a described or planned command.
5. **Check calibration.** Flag every DEFINITIVE / PROVEN / GUARANTEED /
   SUPERSEDES / absolute always-never that is not backed by a Verified row.
6. **Assign the verdict** (gate below) and **persist the report** to the
   verifications location.
7. **Report** the verdict, the failed/blocked rows, and the recommended next step
   (accept, or `rework` with the specific gaps). Do not modify the target.

## Verdict gate

- **Pre-flight failures force FAIL.** Any banned word, contradictory conclusion,
  or unresolvable citation reported by `preflight.sh` is an automatic FAIL — it
  cannot be waved through even if every claim verifies.
- **FAIL** — any load-bearing claim is **Refuted**, or the conclusion does not
  follow from the verified claims. The document is wrong → `rework`.
- **BLOCKED** — any load-bearing claim is **Unverified** (you couldn't confirm
  it). It can't be blessed → get the evidence or downgrade the claim to an
  explicit assumption.
- **PASS** — every load-bearing claim is **Verified** and the conclusion follows.
  List any non-load-bearing nits separately; they don't block.

## The bar (non-negotiable)

- **Independence.** Re-derive from the code; never accept the document's citation
  without opening the file. Your job is to try to *break* the conclusion, not
  confirm it.
- **The profile is context, not evidence.** Use `.agents/project.md` to know which
  invariants and commands a spec must honor — but treat its `[repo: path:line]`
  facts as re-checkable citations and its `[user]`/`[unknown]` facts as
  assumptions. Behavioral claims still get re-derived from the code, never taken
  from the profile.
- **Shown, not described.** Paste the real `file:line` or command output for every
  row. If you didn't run it, the row is Unverified — say so.
- **Behavior/path claims need the path.** For any "X breaks / is safe / can't
  happen / is required," the evidence must include the real caller(s) (from
  `grep`) **and** the gate at `file:line`, plus confirmation the branch is
  reached. Names, annotations, and prose are not evidence.
- **Right-size.** Effort goes to load-bearing claims; don't drown the ledger in
  trivia.
- **Judge, don't fix.** Output the verdict and the gaps. Fixing the document is
  `rework`'s job, not yours.

## Evidence-ledger format

```markdown
# Verification: <target file>

- **Date:** <YYYY-MM-DD>
- **Target:** <path to the artifact checked>
- **Pre-flight:** PASS | FAIL — <one-line, e.g. banned word "DEFINITIVE" at L392; conclusion contradiction L4 vs L407>
- **Verdict:** PASS | FAIL | BLOCKED — <one-line reason>

## Ledger
| # | Claim | LB? | Verdict | Evidence (file:line / command output) |
|---|-------|-----|---------|----------------------------------------|
| 1 | <claim as the doc states it> | yes | Verified | `handler.py:88,140` — read both; nothing returns between them, so L140 is reached |
| 2 | <claim> | yes | Refuted | `grep -rn 'process_refund(' src/` → no callers; the branch is dead |
| 3 | <claim> | no | Unverified | could not reach the live endpoint; left as assumption |

## Calibration flags
- <word> at <line> — not backed by a Verified row.

## Failed / blocked claims → required fixes
- <claim #> — <what's wrong and what evidence would settle it>

## Recommendation
Accept · Rework (with the gaps above) · Get evidence for blocked claims.
```

Rows are checkable by construction: anyone can re-open the cited `file:line` or
re-run the command. (This same ledger format is reusable as a *working* artifact
inside `specify`/`analyze` — building the doc from verified rows both enforces
evidence and keeps context small.)

## Locations

Write the report to `.agents/verifications/<kebab-slug>.md`, reusing the target's
slug (e.g. `payment-retry-idempotency.md`), creating the directory if
missing. Honor any verifications location the project's `AGENTS.md` specifies.

## Rules

- Requires a target path; ask if missing or unresolved.
- Always run `preflight.sh` first; report its findings and treat its FAILs as
  non-negotiable.
- Re-derive independently; shown evidence only; never reproduce the document's
  unverified claims as fact.
- Do not modify the target. Produce the verdict + ledger and stop.
- This is the independent gate after `specify` / `implement` — run it before
  acting on a spec or plan.
