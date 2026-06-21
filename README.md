# maxim

**Discipline skills for coding agents — Mistral Vibe, Claude Code & GitHub Copilot.** A set of *maxims* (rules of conduct) plus a deterministic verification harness that make a coding model produce reviewable, evidence-backed work — installed once into whichever agents you run.

> **What it is:** guardrails. **What it isn't:** a model upgrade.
> maxim won't turn a model into a frontier one. It imposes structure, forces evidence, and catches the cheap-but-dangerous failures deterministically — so the output is *trustworthy enough to review* instead of confidently wrong. Max **discipline**, not max model.

## Why

Coming from a frontier model to a smaller one feels like going from a car to a bicycle. The model still drifts: it confirms instead of checking, asserts instead of grepping, and stamps "VERIFIED" on things it never ran. maxim is a set of training wheels for that bicycle — and, more importantly, a **deterministic brake** (`preflight.sh`) that doesn't depend on the model's disposition at all.

maxim began as a way to tame **Mistral Vibe**, a smaller model that drifts in exactly these ways. But the discipline was never Mistral-specific, and the brake is model- **and** agent-agnostic by construction — it flags a confidently-wrong spec from *any* agent. So the scope is now broader: the same skills and the same `preflight.sh` install into Vibe, **Claude Code**, and **GitHub Copilot**. The thesis didn't change; the audience did.

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

## How it works (one toolkit, three agents)

The skills are written in the open [Agent Skills](https://agentskills.io) format (`SKILL.md` with `name` + `description`), so the *same files* work across agents. Only the **location** each agent reads from differs:

| Agent | Skills (invocable) | Always-on discipline | Notes |
|-------|--------------------|----------------------|-------|
| **Mistral Vibe** | `~/.vibe/skills/` | block in `~/.vibe/AGENTS.md` | native global skills |
| **Claude Code** | `~/.claude/skills/` | block in `~/.claude/CLAUDE.md` | native global skills; invoke with `/name` |
| **GitHub Copilot** | — *(no global skills dir)* | block in `~/.copilot/AGENTS.md` + per-repo `.github/skills/` | see below |

- **Vibe & Claude** load the eight skills globally from one source, identical format. The discipline block (never auto-commit, run preflight, orient first) is merged into each agent's always-loaded file.
- **Copilot** has no global skills directory. Its CLI *does* load custom instructions from `AGENTS.md` and any dir listed in `COPILOT_CUSTOM_INSTRUCTIONS_DIRS`, so the installer writes `~/.copilot/AGENTS.md` and prints the one-line export to wire it in globally. For the full **invocable** skills, drop them into a repo with `./install.sh --github-skills <repo>` → `<repo>/.github/skills/`, which Copilot (and Cursor, Junie, Gemini CLI, …) read via the workspace.

Project rules still live in each project's `AGENTS.md` (closest to the task wins) — loaded by Vibe and the Copilot CLI alike. See [`AGENTS.example.md`](AGENTS.example.md) and [`docs/multi-agent.md`](docs/multi-agent.md) for the full mapping.

## Install

```bash
./install.sh --dry-run                     # preview everything; writes nothing
./install.sh                               # install into every detected agent (copy)
./install.sh --agent claude                # just one (vibe|claude|copilot|all)
./install.sh --link                        # symlink skills so repo edits go live
./install.sh --github-skills /path/to/repo # bundle into <repo>/.github/skills/
./install.sh --uninstall                   # remove only what maxim added
```

**It's non-destructive — what that means for skills you already have:**

- maxim manages **only its own eight skills**, tracked in a `.maxim-manifest` in each skills dir. A same-named skill it didn't install is **reported and left untouched** — never overwritten. Pass `--force` to deliberately replace one.
- It never `rm -rf`s a folder it doesn't own, and re-running is idempotent (no duplicates).
- The always-on rules go in as a **clearly-marked managed block** (`>>> maxim (managed) >>>` … `<<< maxim <<<`) merged into your existing `~/.vibe/AGENTS.md` / `~/.claude/CLAUDE.md` — everything else in those files is preserved. `--uninstall` removes exactly those skills and blocks, nothing else.

Start a **new** agent session afterward so it picks up the skills, then add an `AGENTS.md` to your project (copy [`AGENTS.example.md`](AGENTS.example.md)).

## Known limitations (read this)

These are honest findings, not disclaimers:

- **The model still errs confidently.** In testing, the same model running `verify` reproduced its own blind spots — it confirmed a flawed spec, and on a stronger tier it flipped to a *different* confident-but-wrong conclusion. Treat `verify`'s LLM verdict as a **draft, not a verdict.**
- **`preflight.sh` is the reliable layer.** It catches the mechanical failures regardless of model. The semantic judgment (does `peers/*` *really* reach `database/schema`?) still needs a reviewer that runs the check — which a small model often won't.
- **High-stakes analysis needs a strong reviewer.** maxim makes output *reviewable*; it doesn't make review unnecessary.
- **Portable, not magic.** The skills run under any Agent Skills-aware tool; the deterministic core depends on none of them. Copilot is the partial exception — no global skills directory, so its *invocable* skills are repo-scoped (`.github/skills/`) while its always-on discipline rides on `AGENTS.md` / `COPILOT_CUSTOM_INSTRUCTIONS_DIRS`.

## License

MIT — see [LICENSE](LICENSE).

## Contributing

Issues and PRs welcome, especially: more deterministic `preflight.sh` checks (they're the highest-leverage, model-independent improvements), and adapters for more agents beyond Vibe, Claude Code, and Copilot.
