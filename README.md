# maxim

**Discipline skills for Mistral Vibe** — a set of *maxims* (rules of conduct) plus a deterministic verification harness that make a smaller coding model produce reviewable, evidence-backed work.

> **What it is:** guardrails. **What it isn't:** a model upgrade.
> maxim won't turn Mistral into a frontier model. It imposes structure, forces evidence, and catches the cheap-but-dangerous failures deterministically — so the output is *trustworthy enough to review* instead of confidently wrong. Max **discipline**, not max model.

## Why

Coming from a frontier model to a smaller one feels like going from a car to a bicycle with training wheels. The model still drifts: it confirms instead of checking, asserts instead of grepping, and stamps "VERIFIED" on things it never ran. maxim is the set of training wheels — and, more importantly, a **deterministic brake** (`preflight.sh`) that doesn't depend on the model's disposition at all.

## The pipeline

Seven skills that hand off to each other, each stopping for review and never auto-committing:

| Skill | Does | Hands off to |
|-------|------|--------------|
| `orient` | Discovers the project's operational profile — stack, build/generators, commands, deploy, live access, conventions, landmines — to `.agents/project.md`. | `prompt` / `specify` (auto-run if missing) |
| `prompt` | Turns a rough request into a structured task spec; persists it; stops. | `specify` |
| `specify` | Repo-verified specification with testable acceptance criteria. | `implement` / `verify` |
| `implement` | Spec → reviewed plan → confirmation gate → build with tests. | — |
| `rework` | Revise an existing prompt/spec/plan against feedback, in place. | `specify` / `implement` |
| `analyze` | Investigate via code + logs + (if available) live endpoints. | any of the above |
| `verify` | Independently fact-check a spec/plan into a checkable evidence ledger. | `rework` |

Artifacts live under `.agents/` in the project: the operational profile `project.md` (from `orient`, kept current as the stack changes), plus `prompts/`, `specs/`, `plans/`, `verifications/`.

One more skill sits **outside** the pipeline: **`voice`** — a conversational lens that gives the model's *direct replies to you* the register of a seasoned senior engineer (dry, can-do, realistic). Wording only: it never touches the artifacts above, and accuracy and calibration always outrank it.

## The deterministic core (the part that actually holds)

`skills/verify/preflight.sh` is model-agnostic and runs before any LLM judgment. It deterministically **FAILs** an artifact on:

- **A.** Banned calibration words (`DEFINITIVE`, `PROVEN`, `SUPERSEDES`, `GUARANTEED`).
- **B.** Contradictory conclusions (asserts both "no changes" and "changes required").
- **C.** Unresolvable `file:line` citations (file missing, or line past EOF).
- **E.** Behavioral/security claims (`X can access Y`, `server-to-server`, `privilege escalation`, `would break`…) with **no adjacent evidence** (a `grep`, a caller, a `file:line`).

…and **warns** (advisory — the artifact still passes, but the reviewer is flagged):

- **D.** A quoted code token that isn't actually near its cited line.
- **F.** A backtick API token not found in any cited file — catches invented or wrong names (advisory, since new code legitimately introduces tokens that don't exist yet).
- **G.** A bare file-path with no `:line` that doesn't resolve — wrong dir, renamed, or never created — unless the line marks it new.

It can't rubber-stamp and it can't over-criticize, because it isn't reasoning — it's checking. It also works on specs from *any* agent, not just Mistral.

```bash
bash skills/verify/preflight.sh path/to/spec.md
# exit 0 = clean · 1 = FAIL (fix the items) · 2 = usage
```

## How it works with Mistral Vibe

Vibe loads **skills** from `~/.vibe/skills/` and **project rules** from `AGENTS.md` files in the repo tree (closest to the task wins) plus your user-global `~/.vibe/AGENTS.md`. maxim follows that:

- Skills install into `~/.vibe/skills/` (global, cross-project).
- Each project keeps its own `AGENTS.md` (stack, constraints, artifact locations). See [`AGENTS.example.md`](AGENTS.example.md).

## Install

```bash
./install.sh            # copies skills/* into ~/.vibe/skills/
./install.sh --link     # symlink instead (edits in the repo take effect live)
```

Then add an `AGENTS.md` to your project (copy `AGENTS.example.md`) and start a **new** Vibe conversation so it picks up the skills.

## Known limitations (read this)

These are honest findings, not disclaimers:

- **The model still errs confidently.** In testing, the same model running `verify` reproduced its own blind spots — it confirmed a flawed spec, and on a stronger tier it flipped to a *different* confident-but-wrong conclusion. Treat `verify`'s LLM verdict as a **draft, not a verdict.**
- **`preflight.sh` is the reliable layer.** It catches the mechanical failures regardless of model. The semantic judgment (does `peers/*` *really* reach `database/schema`?) still needs a reviewer that runs the check — which a small model often won't.
- **High-stakes analysis needs a strong reviewer.** maxim makes output *reviewable*; it doesn't make review unnecessary.
- **Coupled to Vibe's conventions** (`~/.vibe/skills/`, `AGENTS.md` loading). A Vibe update could change these; the deterministic core does not depend on them.

## License

MIT — see [LICENSE](LICENSE).

## Contributing

Issues and PRs welcome, especially: more deterministic `preflight.sh` checks (they're the highest-leverage, model-independent improvements), and adapters for other AGENTS.md-aware agents.
