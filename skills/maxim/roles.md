# maxim roles — which agent runs which step, on which model

This file ships with the `maxim` skill. It is the single source for roles, tiers,
model resolution, and the per-agent adapters. Skills name **roles**, never vendor
models; only the gated adapter sections below name models.

## Roles

| Role | Tier | Writes | Independence | Used for |
|------|------|--------|--------------|----------|
| `orchestrator` | (inherits the session) | run notes in the reply only | — | The `maxim` run itself: sequencing, limits, announce lines, final report. Thin. |
| `scout` | light | nothing (read-only) | none needed | File/grep sweeps, caller inventories, citation spot-checks, log scans, "does X exist". Returns findings with `file:line` and command output. |
| `author` | standard (deep on escalation) | prompts, specs, plans, code, tests, docs | — | `prompt`, `specify`, `rework`, plan writing, `implement`, `analyze` synthesis. |
| `verifier` | standard (deep on escalation) | `.agents/verifications/` only | **required**: fresh context, paths only | `verify` in `review` mode. |
| `decider` | deep (the most capable model available) | `.agents/verifications/` only (report + decision log) | **required**: fresh context, resumable | `autopilot` runs only: verify + every gate. |
| *deterministic* | no model | as the script does | — | `preflight.sh`, `reindex.sh`, `query.sh`, test runners, mirror diffs. Run by whoever orchestrates, from the project root. Never delegated to an LLM agent. |

**Read-only** means: read files, run read commands and read-only queries. Never
edit code or the artifacts under review, never commit, push, deploy, promote, or
run mutating requests.

## Which step goes to which role

| Step | Role |
|------|------|
| `orient` repo sweep · `specify` evidence gathering · `analyze` log/code/endpoint sweeps | scout (parallel where supported) |
| `orient` write profile · `prompt` · `specify` design + writing · `rework` · `analyze` synthesis · `implement` plan, code, tests | author |
| Open questions (`orient`, `prompt`) · spec acceptance · plan approval + "start implementation" · final evidence | user (`maxim` and every skill on its own) · decider (`autopilot`) |
| `verify` | verifier (`maxim`) · decider (`autopilot`) |
| `index`, pre-flight, test suites | deterministic |
| `voice` | none — a wording lens over the main reply |

A mechanical write sweep (renames, doc updates across copies) may go to a
light-tier writer only if the agent can give it write tools; otherwise the author
does it.

## Escalation to the deep tier (author, verifier)

Escalate when any holds: security/auth/crypto; data that can be lost; schema or
migration; cross-service or cross-repo change; anything touching production; a
`verify` FAIL on the same spec twice; the author's own confidence is low on a
load-bearing claim. The decider is always deep.

## Model resolution (first match wins)

1. The user's instruction for this run ("run the author on …").
2. A **Model routing** section in the project's always-on file (`AGENTS.md`, or
   the file your agent reads instead), closest to the task wins.
3. A **Model routing** section in the user-global always-on file.
4. Escalation (above).
5. The role's default for your agent (adapter sections below); with no adapter,
   the subagent inherits the session model.

## Announce every agent start

Before you start an agent, print exactly one line to the user:

```
▶ <agent> — <purpose, one clause> — model: <model> (<source>)
```

`<source>` is one of: `agent definition` · `run instruction` · `AGENTS.md routing`
· `user routing` · `escalation: <trigger>` · `inherited` · `inline (same context)`.
When you continue an existing agent, print the same line with `resumed` after the
source. When a role runs inline (no subagent), still print the line with
`inline (same context)` — the user sees every role step.

Every subagent's reply starts with `Model: <id as its environment states it, or
"not stated">`. The run record lists both: the model requested (with source) and
the model reported.

## Capability fallback (any agent)

For each step that should run in its own agent:

1. **Subagent with a chosen model** → resolve the model as above.
2. **Subagent without model choice** → still start one (independence); model
   `inherited`.
3. **No subagents** → run inline, labelled `inline (same context)`; a
   verify/decider result is labelled **non-independent (same context)**. In an
   `autopilot` run every gate falls back to the **user**: the run pauses at the
   gate. Never self-approve.
4. **Resume** → if the agent can continue a subagent, keep one decider (and one
   author) for the whole run. Otherwise start a new one per gate and give it the
   decision log (decider) or the persisted prompt/spec/plan (author) as its memory.

## Gate message to a verifier or decider

Paths (spec, plan, verification report, results section) · what changed since the
last gate · the specific questions · the user's grant verbatim (decider only).
Never your verdict, your summary of correctness, or what you expect it to find.

## Tier → model by provider (reference data)

Checked against each vendor's own model docs on **2026-11-15**. Lineups change
every few months — re-check the source before relying on a row, and update the
date when you do. A model is only usable where your agent can run it (see the
adapters below); this table is what an adapter or a **Model routing** section
picks from.

| Provider | light (`scout`) | standard (`author`, `verifier`) | deep (`decider`, escalation) | Source |
|----------|-----------------|---------------------------------|------------------------------|--------|
| Anthropic | `claude-haiku-5-5` | `claude-sonnet-5-5` | `claude-opus-5-5` | [models overview](https://platform.claude.com/docs/en/about-claude/models/overview) |
| OpenAI | `gpt-6-luna` | `gpt-6.1-sol` | `gpt-6-astra` | [models](https://developers.openai.com/api/docs/models) |
| Google | `gemini-4-hydrogen` | `gemini-4-argon` | `gemini-4-carbon` | [models](https://aistudio.google.com/docs/models) |
| Mistral | `mistral-small-2603` (`mistral-small-latest`) | `mistral-large-4-0` | `mistral-large-4-0` (no higher tier) | [models](https://docs.mistral.ai/getting-started/models/models_overview/), [Small 4](https://docs.mistral.ai/models/mistral-small-4-0-26-03.md), [Vibe config](https://docs.mistral.ai/mistral-vibe/terminal/configuration) |
| xAI | — | — | `grok-4.7` | [models](https://docs.x.ai/docs/models) |

How the rows were chosen, and what is not settled:

- **Anthropic.** Haiku 5.5: high-volume, latency-sensitive tasks. Sonnet 5.5:
  "the best combination of speed and intelligence". Opus 5.5: the vendor's
  recommended starting point "for most workloads". Models priced above Opus are
  deliberately not mapped (cost); the decider runs on Opus.
- **OpenAI.** Astra: "most capable model for the most demanding work". Sol:
  "near-Astra performance for complex work at a lower cost". Luna: "most
  efficient model for focused, high-volume tasks". (Terra, "fast, efficient",
  is an alternative light model.)
- **Google.** Carbon: strongest reasoning, complex coding. Argon: efficient
  frontier reasoning, cheaper per turn. Hydrogen: fast, efficient, everyday
  coding and agentic workflows. The page labels no stability for Gemini 4 and
  does not rank Hydrogen as the fastest explicitly.
- **Mistral.** Small 4 is GA ("hybrid … instruct, reasoning, and coding");
  Large 4 is the current top model. Medium 3.5 (`mistral-medium-latest`, Vibe's
  built-in) is deprecated since 2026-10-31, retiring 2027-04-30, with Large 4 as
  the named replacement; the Devstral coding models are deprecated too.
  Codestral is a code-completion model, not an agent model.
- **xAI.** `grok-4.7` is "the most capable model we've built". The page names
  no fast or mini tier, so light and standard stay empty.
- **A missing tier** uses the next higher tier listed for that provider.
- **Not mapped:** Microsoft (MAI-Code), Moonshot (Kimi), Z.ai (GLM), DeepSeek —
  available through Copilot or Mistral's API, but their docs were not checked.

---

## Adapter: Claude Code (only when you are running in Claude Code)

- Agent definitions, installed by `./install.sh --agent claude` into
  `~/.claude/agents/` (or `$CLAUDE_AGENTS_DIR`):

  | Role | Agent (`subagent_type`) | Default model |
  |------|-------------------------|---------------|
  | scout | `maxim-scout` | `haiku` |
  | author | `maxim-author` | `sonnet` |
  | verifier | `maxim-verifier` | `sonnet` |
  | decider | `maxim-decider` | `opus` |

- Tier → alias for overrides and escalation: light `haiku` · standard `sonnet` ·
  deep `opus`. Apply an override by passing `model` on the Agent call (it wins
  over the definition); pass nothing to use the definition's `model:` line. The
  per-call `model` takes an alias only (e.g. `haiku`, `sonnet`, `opus`); a full
  model ID from a routing section cannot be passed per call — map it to its alias
  or say in the announce line that it was not applied.
- Before announcing a default, read the `model:` line of the definition Claude
  Code will load (`.claude/agents/` in the project wins over `~/.claude/agents/`).
- `CLAUDE_CODE_SUBAGENT_MODEL_FORCE`, an org model allowlist, or auto mode can
  change the model a subagent actually gets — hence the self-reported `Model:`
  line. `/tasks` shows each running subagent's model.
- Continue an agent with `SendMessage` to its ID or name; it keeps its history.
- Forks ignore `model`; don't fork for a role that needs a specific model.
- If `maxim-*` agents are not installed, use the general-purpose subagent with
  the tier alias as `model` (fallback step 1) and say so in the announce line.
- If `~/.claude/agents/` did not exist when the session started, new agent files
  load only after a restart.

## Adapter: Mistral Vibe (only when you are Mistral Vibe)

Vibe supports subagents (TOML files in `~/.vibe/agents/` or `./.vibe/agents/`
with `agent_type = "subagent"`) and a per-agent `active_model`; unset, they run on
the session's model. `active_model` takes an **alias** the user defines in a
`[[models]]` block (`name` = the provider's model ID from the Mistral row above,
`provider = "mistral"`); other providers' rows are reachable through a
`[[providers]]` entry such as OpenRouter. maxim ships no Vibe agent files yet:
use fallback step 2 (subagent, model `inherited`) unless the user has defined
role subagents and named them in a **Model routing** section. If
`enable_subagents = false`, use step 3. Resuming a subagent is not documented —
treat it as unavailable.

## Adapter: GitHub Copilot (only when you are GitHub Copilot)

Copilot custom agents (`.github/agents/<name>.agent.md`) take a `model` property
and can invoke another custom agent through the `agent` tool. Copilot offers
several vendors; its model **display names** for the rows above (all listed GA in
GitHub's [supported models](https://docs.github.com/en/copilot/reference/ai-models/supported-models)
on 2026-11-15):

| Provider | light | standard | deep |
|----------|-------|----------|------|
| Anthropic | Claude Haiku 5.5 | Claude Sonnet 5.5 | Claude Opus 5.5 |
| OpenAI | GPT-6 Luna | GPT-6.1 Sol | GPT-6 Astra |
| Google | Gemini 4 Hydrogen | Gemini 4 Argon | Gemini 4 Carbon |
| xAI | — | — | Grok 4.7 |

The exact string the `model` property expects is not specified in GitHub's
docs; community examples use the display name with a ` (copilot)` suffix in VS
Code (e.g. `Claude Sonnet 5.5 (copilot)`) — unverified. GitHub's docs say the
property applies in VS Code, JetBrains, Eclipse and Xcode. maxim ships no Copilot
agent profiles yet: use fallback step 2 unless the user's routing section names
custom agents to use. Resume is not documented — treat it as unavailable.

## Any other agent

No adapter needed: the portable text above plus the fallback chain applies.
