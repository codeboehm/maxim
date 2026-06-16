# AGENTS.md — <your project>

> Copy this to your repo root as `AGENTS.md`. AGENTS.md-aware agents (Mistral Vibe, newer Copilot, …) load it automatically: files closer to the task win, plus your user-global `~/.vibe/AGENTS.md`. It carries the **stack, constraints, and domain truth** — the maxim skills read it for project-specific conventions.

## The project in one sentence

<What this codebase is, the stack, and how the pieces fit — one or two sentences.>

## Knowledge: one source of truth

<Where the authoritative project knowledge lives — e.g. `docs/`, a skills dir, key modules. Tell the agent to read it before working an area, instead of guessing.>

## Critical rules (never violate)

1. **Never auto-commit or auto-push.** Stop after implementing; the developer reviews and confirms.
2. **Load the relevant docs/skill before starting** a non-trivial task. Don't guess conventions — read them.
3. <Any invariant unique to this repo — mirrored files that must stay in sync (with the verification command), layering rules, naming conventions, generated artifacts that must be rebuilt, etc.>
4. <Build/test/lint commands the agent must run to verify a change.>

## Planning artifacts: where outputs go

The maxim skills persist their work here. Keep these locations (or change them and say so):

- **Structured prompts** (`prompt` skill) → `.agents/prompts/<unix-timestamp>-<kebab-slug>.md` (real `date +%s`, persisted automatically).
- **Specifications** (`specify`) → `.agents/specs/<kebab-slug>.md` (topic-named).
- **Implementation plans** (`implement`) → `.agents/plans/<kebab-slug>.md` (reuse the spec's slug).
- **Verification reports** (`verify`) → `.agents/verifications/<kebab-slug>.md` (evidence ledger + PASS/FAIL/BLOCKED).
- Producing a spec → `specify`; implementing one → `implement`; revising one → `rework`; checking one → `verify`; investigating → `analyze`.

## Live analysis access (optional — for the `analyze` skill)

<If this project exposes a way to inspect the running system — diagnostic/agent endpoints, a way to query the DB, log retrieval via SFTP creds in an env var — document it here: the base URL, how to mint a token, the required headers, and the SFTP variable. Mark which stage it targets, and note "read-only by default; mutations need explicit confirmation." If there's no live access, delete this section.>

## Deployment & infrastructure facts

<Deploy command(s), host(s), stages, where secrets live, anything an agent would otherwise get wrong from stale docs. Point to the authoritative script/skill rather than pasting commands that drift.>
