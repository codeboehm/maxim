# Design notes

The thesis behind maxim, and the evidence for it.

## The core finding

Skill instructions shape the **form** of a model's output, not its **truth**.

Tell a small model to "verify every claim against the code" and it will produce
a beautifully structured document with an evidence table, citations, and a
confident verdict — in which the citations are misattributed, the central claim
was never actually checked, and the verdict is wrong. The discipline is adopted
as *format*, not as *behavior*. The hard part — running the `grep` that would
*disconfirm* the claim — is exactly what gets skipped.

This was observed repeatedly across model tiers:

- A **smaller tier** rubber-stamped a flawed spec: every claim "VERIFIED," nothing
  refuted, on a document with a refutable central argument.
- A **larger tier**, given the same task, flipped to the opposite failure — a
  confident "critical gaps, changes required" list built on claims that were
  factually wrong (a token scope that *can't* reach the route it "grants," a fix
  whose code couldn't parse the actual data format, a "breaks server-to-server"
  argument for traffic that doesn't exist). Implementing its recommendations would
  have broken working code.

Same root cause, opposite polarity: the model reasons plausibly and asserts
confidently without executing the check that would catch it. A bigger model moved
the *style* of the error, not the *presence* of it.

## The consequence: lean on what doesn't depend on disposition

If the model won't reliably run the disconfirming check, push as much of the
verification as possible into code that **always** runs it.

That is what `skills/verify/preflight.sh` is. It doesn't reason; it checks. It
cannot rubber-stamp (it has no opinion to flatter) and it cannot over-criticize
(it only flags concrete, mechanical violations). It catches:

- emphatic claim-words with no evidence (`DEFINITIVE`, `PROVEN`, …),
- a document that asserts both "no changes" and "changes required,"
- `file:line` citations that don't resolve,
- **behavioral/security claims with no adjacent evidence** — the single highest-value
  check, because "X can access Y / breaks server-to-server / privilege escalation"
  with no `grep` beside it is the exact shape of the errors models make,
- (advisory) quoted code tokens that aren't near their cited line.

These are model-independent and even provider-independent — `preflight.sh` will
flag a confidently-wrong spec from any agent.

## The skills are guardrails, ranked by reliability

1. **Deterministic** (`preflight.sh`): reliable. Runs the same regardless of model.
2. **Procedural** (persist a real-`date +%s` prompt, stop at confirmation gates,
   never auto-commit): fairly reliable — concrete actions are followed more often
   than judgments.
3. **Semantic** (the "senior bar": re-derive claims, trace which branch actually
   runs, calibrate the threat model): aspirational. Present in every skill, but the
   model applies them inconsistently. Treat any LLM verdict as a **draft**.

The whole design follows that ranking: mechanize what you can, gate what you can't,
and never present the model's semantic judgment as a settled result.

## Why `verify` output is a draft, not a verdict

The model that runs `verify` shares the blind spots of the model that produced the
artifact (often the *same* model). Independence of *context* — a fresh
conversation — is not independence of *capability*. Real verification of a
high-stakes claim still needs either a stronger reviewer or a human who runs the
check. `verify` narrows the gap and surfaces candidates; it does not close it.

## Where to push next

The highest-leverage contributions are **more deterministic `preflight.sh`
checks**, because they convert "the model should have caught this" into "the
script always catches this." Everything that can be moved from tier 3 to tier 1
is a permanent win that no model regression can undo.
