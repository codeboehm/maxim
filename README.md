# maxim

**Discipline skills for coding agents — Mistral Vibe, Claude Code & GitHub Copilot.** A set of *maxims* (rules of conduct) plus a deterministic verification harness that make a coding model produce reviewable, evidence-backed work — installed once into whichever agents you run.

> **What it is:** guardrails. **What it isn't:** a model upgrade.
> maxim won't turn a model into a frontier one. It imposes structure, forces evidence, and catches the cheap-but-dangerous failures deterministically — so the output is *trustworthy enough to review* instead of confidently wrong. Max **discipline**, not max model.

## Why

Coming from a frontier model to a smaller one feels like going from a car to a bicycle. The model still drifts: it confirms instead of checking, asserts instead of grepping, and stamps "VERIFIED" on things it never ran. maxim is a set of training wheels for that bicycle — and, more importantly, a **deterministic brake** (`preflight.sh`) that doesn't depend on the model's disposition at all.

maxim began as a way to tame **Mistral Vibe**, a smaller model that drifts in exactly these ways. But the discipline was never Mistral-specific, and the brake is model- **and** agent-agnostic by construction — it flags a confidently-wrong spec from *any* agent. So the scope is now broader: the same skills and the same `preflight.sh` install into Vibe, **Claude Code**, and **GitHub Copilot**. The thesis didn't change; the audience did.

## The pipeline

Seven skills that hand off to each other, each stopping for review and never auto-committing (two orchestrators, `maxim` and `autopilot`, run them for you — see below):

| Skill | Does | Hands off to |
|-------|------|--------------|
| `orient` | Discovers the project's operational profile — stack, build/generators, commands, deploy, live access, conventions, landmines — to `.agents/project.md`. | `prompt` / `specify` (auto-run if missing) |
| `prompt` | Turns a rough request into a structured task spec; persists it; stops. | `specify` |
| `specify` | Repo-verified specification with testable acceptance criteria. | `implement` / `verify` |
| `implement` | Spec → reviewed plan → confirmation gate → build with tests. | — |
| `rework` | Revise an existing prompt/spec/plan against feedback, in place. | `specify` / `implement` |
| `analyze` | Investigate via code + logs + (if available) live endpoints. | any of the above |
| `verify` | Independently fact-check a spec/plan into a checkable evidence ledger. | `rework` |

`specify` runs `preflight.sh` on its own spec before handing it back (at most three passes), so the mechanical failures are settled before review.

**Running the suite in one go:** the **`maxim`** skill orchestrates the steps above for a single request — `orient` (if the profile is missing) → `specify` (which runs `prompt`) → pre-flight → `verify` in a fresh context where the agent supports it → `rework` on FAIL/BLOCKED. It pauses only for your answers to open questions, and it ends in one of three states, all of them legitimate:

| End state | Meaning |
|-----------|---------|
| `PASS (draft)` | Pre-flight clean, `verify` passed, no open questions. Still a draft verdict — review the spec. |
| `STOPPED — limit reached` | 3 pre-flight passes or 2 rework cycles used, or two passes in a row reported the same findings. The open findings are listed. |
| `STOPPED — needs input` | An open question or a claim only you can settle. |

The limits exist so the agent has no reason to weaken a spec until it passes: a failing claim is either evidenced or moved to Open Questions, and the final report lists every claim removed or downgraded on the way. `maxim` never continues into `implement`: you stay the verifier at every gate.

**Roles and models.** Each step runs on an agent with a fitting role — `scout` (light: read-only sweeps), `author` (standard: specs, plans, code), `verifier` (standard, fresh context), `decider` (the most capable model) — defined once in [`skills/maxim/roles.md`](skills/maxim/roles.md). Every agent start is announced in the chat with its role, purpose and model, and the final report lists the model each step ran on. Under Claude Code, `install.sh --agent claude` adds the role agents (`maxim-scout` on Haiku, `maxim-author` and `maxim-verifier` on Sonnet, `maxim-decider` on Opus) to `~/.claude/agents/`; other agents fall back to their session model or run inline.

**Fully automatic: `/autopilot`.** A separate skill for when you want the whole way, request → implemented change, without being asked at each gate. An independent `decider` agent takes your gates — open questions, spec acceptance, plan approval, final evidence — deciding from your profile in `~/.maxim/decider-profile.md` (start from [`agents/decider-profile.example.md`](agents/decider-profile.example.md)) and logging every decision in the verification report. It commits only what your invocation grants (`/autopilot <request> — grant: commit, push`); without a grant it stops at `IMPLEMENTED — awaiting your commit`, and without subagent support every gate comes back to you. All the other skills, `maxim` included, keep you as the verifier.

Artifacts live under `.agents/` in the project: the operational profile `project.md` (from `orient`, kept current as the stack changes), plus `prompts/`, `specs/`, `plans/`, `verifications/`.

One more skill sits **outside** the pipeline: **`voice`** — a conversational lens that gives the model's *direct replies to you* the register of a seasoned senior engineer (dry, can-do, realistic). Wording only: it never touches the artifacts above, and accuracy and calibration always outrank it.

A second skill sits **outside** the sequential pipeline alongside `voice`: **`index`** — a deterministic catalog of `.agents/` (prompts, specs, plans, verifications, plus `project.md`'s sections), regenerated by a bash script (`reindex.sh`) and searched by a keyword pre-filter (`query.sh`). The other skills consult it before scanning full artifact directories and refresh it after persisting — but nothing about it is a judgment call: it mechanizes lookup, not relevance.

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
| **Claude Code** | `~/.claude/skills/` | block in `~/.claude/CLAUDE.md` | native global skills; invoke with `/name`; role agents in `~/.claude/agents/` |
| **GitHub Copilot** | — *(no global skills dir)* | block in `~/.copilot/AGENTS.md` + per-repo `.github/skills/` | see below |

- **Vibe & Claude** load the eleven skills globally from one source, identical format. The discipline block (never auto-commit, run preflight, orient first) is merged into each agent's always-loaded file.
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
CLAUDE_AGENTS_DIR=… ./install.sh --agent claude  # role agents somewhere other than ~/.claude/agents
```

For `/autopilot`, create your decider profile once (personal — keep it out of every repo):

```bash
mkdir -p ~/.maxim && cp agents/decider-profile.example.md ~/.maxim/decider-profile.md   # then edit it
```

**It's non-destructive — what that means for skills you already have:**

- maxim manages **only its own eleven skills** (and, for Claude Code, its four `maxim-*.md` role agents), tracked in a `.maxim-manifest` in each directory. A same-named skill or agent file it didn't install is **reported and left untouched** — never overwritten. Pass `--force` to deliberately replace one.
- It never `rm -rf`s a folder it doesn't own, and re-running is idempotent (no duplicates).
- The always-on rules go in as a **clearly-marked managed block** (`>>> maxim (managed) >>>` … `<<< maxim <<<`) merged into your existing `~/.vibe/AGENTS.md` / `~/.claude/CLAUDE.md` — everything else in those files is preserved. `--uninstall` removes exactly those skills and blocks, nothing else.

Start a **new** agent session afterward so it picks up the skills (Claude Code: required once if `~/.claude/agents/` didn't exist before), then add an `AGENTS.md` to your project (copy [`AGENTS.example.md`](AGENTS.example.md)).

## Known limitations (read this)

These are honest findings, not disclaimers:

- **The model still errs confidently.** In testing, the same model running `verify` reproduced its own blind spots — it confirmed a flawed spec, and on a stronger tier it flipped to a *different* confident-but-wrong conclusion. Treat `verify`'s LLM verdict as a **draft, not a verdict.**
- **`preflight.sh` is the reliable layer.** It catches the mechanical failures regardless of model. The semantic judgment (does `peers/*` *really* reach `database/schema`?) still needs a reviewer that runs the check — which a small model often won't.
- **High-stakes analysis needs a strong reviewer.** maxim makes output *reviewable*; it doesn't make review unnecessary.
- **`/autopilot`'s decider is still a model.** It runs on the strongest model available and in its own context, which narrows the blind-spot problem above but doesn't remove it. Its decisions are logged so you can audit them; for high-stakes changes, keep the grant to "none" and commit yourself.
- **The announced model is the one requested.** Environment overrides, org allowlists or a permission mode can give a subagent a different model; each subagent self-reports its model (when its environment states it), and Claude Code's `/tasks` shows the real one.
- **Role adapters ship for Claude Code only.** Vibe and Copilot support subagents with their own model, but maxim has no adapter files for them yet — there, subagents inherit the session model (or run inline, with every gate back to you).
- **Portable, not magic.** The skills run under any Agent Skills-aware tool; the deterministic core depends on none of them. Copilot is the partial exception — no global skills directory, so its *invocable* skills are repo-scoped (`.github/skills/`) while its always-on discipline rides on `AGENTS.md` / `COPILOT_CUSTOM_INSTRUCTIONS_DIRS`.

## License

MIT — see [LICENSE](LICENSE).

## Contributing

Issues and PRs welcome, especially: more deterministic `preflight.sh` checks (they're the highest-leverage, model-independent improvements), role adapters for Vibe and Copilot (subagent definitions per role), and adapters for more agents beyond Vibe, Claude Code, and Copilot.
