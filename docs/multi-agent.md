# Multi-agent layout: how maxim maps onto Vibe, Claude Code & Copilot

maxim's skills are written once, in the open [Agent Skills](https://agentskills.io)
format (a folder with a `SKILL.md` carrying `name` + `description`). That format is the
cross-tool standard; what changes per agent is only **where each one reads skills and
always-on rules from**. This note is the reference for that mapping.

It adapts the team-oriented guidance in *AI Coding Assistants: Knowledge Management &
Context Strategy* to maxim's actual shape. The guide describes a **per-repo** layout
(`.github/skills/`, `.claude/skills/`); maxim instead installs into each agent's
**global** user directory, because the skills are cross-project discipline, not
project knowledge. The per-repo `.github/skills/` layer still exists here — as an
opt-in bundle (`--github-skills`) for Copilot and teammates.

## The three tiers

| Tier | What it is | Loads | Per agent |
|------|------------|-------|-----------|
| **1 · Skills** | The 11 invocable `SKILL.md` skills | On demand (progressive disclosure) | Vibe `~/.vibe/skills/` · Claude `~/.claude/skills/` · Copilot: none global |
| **2 · Always-on discipline** | The managed block (`agents/discipline-block.md`) | Every session | Vibe `~/.vibe/AGENTS.md` · Claude `~/.claude/CLAUDE.md` · Copilot `~/.copilot/AGENTS.md` |
| **3 · Per-repo bundle** | Same 11 skills committed into a repo | Workspace / on demand | any agent — `<repo>/.github/skills/` (+ `.github/copilot-instructions.md`) |

`skills/` in this repo is the single source of truth. `install.sh` copies (or symlinks)
it into tiers 1 and 3, and merges the tier-2 block into each agent's always-on file.

## Artifact formats: Markdown vs XML

The stored artifacts (`.agents/prompts/`, `specs/`, `plans/`, …) are **Markdown for
every agent** — with one exception: the structured *prompt* under **Mistral Vibe**,
which uses an XML `<task_spec>` block. A Mistral model follows explicit XML delimiters
more reliably; Claude, Copilot, and other agents write the same sections as readable
Markdown. The discipline (every section filled), the file extension (`.md`), and the
storage path are identical either way — only the serialization differs. The `prompt`
skill carries both templates and picks by agent (Markdown is the default; XML only if
you're Mistral), so the one symlinked source still serves all three.

## Per agent

### Mistral Vibe
- **Skills:** native, global — `~/.vibe/skills/<name>/SKILL.md`.
- **Always-on:** `~/.vibe/AGENTS.md` (user-global) + each repo's `AGENTS.md` (closest wins).
- maxim's origin agent; nothing here is special-cased anymore.

### Claude Code
- **Skills:** native, global — `~/.claude/skills/<name>/SKILL.md`; invoke with `/name`.
- **Always-on:** `~/.claude/CLAUDE.md` (Claude reads `CLAUDE.md`, **not** `AGENTS.md`).
- The discipline block is merged into your existing `CLAUDE.md` between markers, below
  whatever personal instructions you already keep there.

### GitHub Copilot
- **Skills (invocable):** Copilot has **no global skills directory**. The cross-tool way
  to give it the full skills is a repo's `.github/skills/`, which it reads via the
  workspace (so do Cursor, JetBrains Junie, Gemini CLI, …). Use
  `./install.sh --github-skills <repo>`.
- **Always-on (global):** the Copilot CLI loads custom instructions from `AGENTS.md` and
  any directory on `COPILOT_CUSTOM_INSTRUCTIONS_DIRS`. The installer writes
  `~/.copilot/AGENTS.md` and prints the export to add to your shell profile:
  ```bash
  export COPILOT_CUSTOM_INSTRUCTIONS_DIRS="$HOME/.copilot${COPILOT_CUSTOM_INSTRUCTIONS_DIRS:+,$COPILOT_CUSTOM_INSTRUCTIONS_DIRS}"
  ```
  (It does **not** edit your shell config for you.)
- **Honest limitation:** Copilot's *invocable* discipline is repo-scoped, not global.
  Globally it gets the always-on rules; the step-by-step skills travel per repo.

## Roles, models and adapters

Skills name **roles**, never vendor models. The roles (`scout` light, `author` and
`verifier` standard, `decider` deep, plus deterministic scripts that use no model),
the model resolution order, the announce line printed before every agent start,
and the capability fallback all live in one file: `skills/maxim/roles.md`. It ships
inside the `maxim` skill, so every install path carries it. `maxim` uses scout,
author and verifier and leaves every gate to the user; only `/autopilot`, invoked
explicitly, adds the `decider` at the gates. `roles.md` also holds a dated
tier → model reference table for Anthropic, OpenAI, Google, Mistral and xAI, plus
Copilot's display names — the data a Vibe or Copilot adapter, or a project's
"Model routing" section, picks from.

| Agent | Subagents | Per-agent model | Resume | What maxim ships |
|-------|-----------|-----------------|--------|------------------|
| **Claude Code** | Agent tool; custom agents in `~/.claude/agents/` / `.claude/agents/` | frontmatter `model`; a per-call `model` alias overrides it | `SendMessage` | `agents/claude/maxim-{scout,author,verifier,decider}.md` → `~/.claude/agents/` (`--agent claude` only; `CLAUDE_AGENTS_DIR` overrides) |
| **Mistral Vibe** | TOML subagents in `~/.vibe/agents/` (`agent_type = "subagent"`) | `active_model` | not documented | nothing yet — subagents inherit the session model, or name your own in a "Model routing" section |
| **GitHub Copilot** | custom agents invoked via the `agent` tool | `model` property | not documented | nothing yet — same fallback |
| **Other** | — | — | — | nothing; the portable text runs inline with human gates |

Sources (checked 2026-11-15): [Claude sub-agents](https://code.claude.com/docs/en/sub-agents),
[Vibe agents & skills](https://docs.mistral.ai/mistral-vibe/agents-skills),
[Copilot custom agents](https://docs.github.com/en/copilot/reference/custom-agents-configuration).

The Claude agent files follow the same ownership rules as skills (manifest in the
agents dir, foreign same-named files skipped, `--uninstall` removes only maxim's).
If `~/.claude/agents/` did not exist before, restart Claude Code once after the
install. The decider's personal profile is **not** shipped: copy
`agents/decider-profile.example.md` to `~/.maxim/decider-profile.md`.

## The non-destructive install model

`install.sh` is built to be safe against a home directory that already has skills:

- It manages **only its own 11 skills**, tracked in a `.maxim-manifest` in each skills
  dir. A skill is "maxim's" iff it's in that manifest or is a symlink resolving into this
  repo.
- A same-named skill it didn't install is **skipped and reported**, never overwritten.
  `--force` opts into replacing it; only then does it become maxim-managed.
- It never `rm -rf`s a directory it doesn't own. Re-running is idempotent.
- Tier-2 rules are a **marked block** merged into your files; the rest of each file is
  untouched. `--uninstall` removes exactly the managed skills and blocks.

See the repo [`README.md`](../README.md) for the command surface, and
[`design-notes.md`](design-notes.md) for *why* the deterministic core is the part that
makes this portability trustworthy.
