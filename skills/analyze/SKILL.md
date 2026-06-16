---
name: analyze
description: Investigate a question or issue with real evidence — read the code, retrieve logs, and (where the project exposes them) use live agent/diagnostic endpoints, including running your own DB queries against the running system. Produces an evidence-backed findings report, not a fix. Use to diagnose a bug, answer a "how/why does X behave" question, or ground another task in reality.
---

When this skill is invoked, your job is to **find out what is actually true** and
report it with evidence — not to implement a fix. Prove every conclusion against
real artifacts (code, logs, live data); never present a guess as a finding.

## Sources of evidence (use what the project offers)

1. **Code & history** — always available. Read the actual files, `grep` for real
   usage, check `git log`/blame. Cite `path:line`.
2. **Logs** — retrieve them two ways, whichever the project supports:
   - **Agent/log endpoint** (if present) — e.g. an `agent/logs` route with
     filters (level, time window, class).
   - **Host via SFTP** — the project usually keeps host credentials in an
     environment/secrets variable (e.g. a `.env.deploy` with `*_SFTP_HOST` /
     `_PORT` / `_USER` / `_PASS`). Source it, connect with `sftp`/`lftp`, and read
     the log files under the host's log directory. Use the variable the project
     defines; do not hardcode hosts or credentials.
3. **Live agent/diagnostic endpoints** (if present) — for inspecting the running
   system: health, config, routes, and often a **query endpoint that runs your
   own SQL** against the live database. Typical shape: a time-limited token in an
   auth header plus a request-flavor header; enumerate what's available via the
   project's `routes`/`diagnostics` endpoint before relying on a specific one.

## Project-specific access

The endpoint URLs, the token-generation command, the header names, and the SFTP
variable are **project-specific**. Discover them from the project's `AGENTS.md`,
its skills, and its deploy/secrets scripts — do not invent them. If the project
has no live access, say so and fall back to code + local reproduction.

If a project documents agent/diagnostic endpoints or host (SFTP) access in its
`AGENTS.md`, its skills, or its deploy scripts, use them — and treat anything
branded *prod* as production (read-only by default). If it documents none, say so
and rely on code + local reproduction.

## The senior bar (non-negotiable)

- **Evidence over assertion.** Reproduce the issue if you can. Back each claim
  with the specific code line, log entry, or query result you saw. If you
  couldn't verify something, label it as inferred or unknown.
- **Root cause, not symptom.** Keep asking "is this the cause or a downstream
  effect?" Don't stop at the first plausible explanation — form a hypothesis,
  then actively look for evidence that would *disprove* it.
- **Trace which branch actually runs.** Two traps. (1) *Reachability:* in an
  `if/elseif` chain or behind early returns/guard ordering, only one branch
  executes — a later check is dead for any case an earlier branch already
  matched, so confirm the branch you're reasoning about is even reached before
  trusting its condition. (2) *Alternative satisfiers / inputs:* when behavior
  forks (token OR cookie OR session; cache hit vs. miss; one stage vs. another),
  check each path and confirm which one the real case takes — a control or value
  present on one path is often absent on another.
- **Safety on live systems — read-only by default.** Never run mutating SQL or
  state-changing calls against a running system without explicit confirmation,
  and treat anything named/branded *prod* as production: minimize what you pull,
  do not exfiltrate secrets or personal data, and prefer the lowest-privilege,
  shortest-lived token. Live agent endpoints are normally dev/stage-gated for a
  reason — respect that gating; if it's off on a stage, that stage is off-limits.
- **Report, don't fix.** This skill ends at findings. If a change is warranted,
  recommend the next step (often the `specify` skill) — don't start editing code.

## Output

A tight findings report:

- **Question / issue** — what you set out to determine.
- **What you checked** — code, logs, endpoints/queries actually run (with the
  commands or `path:line`).
- **Evidence** — the concrete observations (log lines, query results, code).
- **Finding** — the root cause or the best-supported hypothesis, and what would
  confirm it if you couldn't fully verify.
- **Unknowns / next step** — open questions and the recommended follow-up.

If the project's `AGENTS.md` defines an analysis-output location, persist the
report there; otherwise keep it in the conversation unless asked to save it.

## Rules

- Use live/log/DB access only where the project actually provides it; otherwise
  rely on code + local repro and say the live path wasn't available.
- Read-only by default on any running system; mutations need explicit go-ahead.
- Never commit, deploy, or change state as part of analysis.
- This skill is also **optional tooling** for `prompt`, `specify`, and
  `implement` — they call on it to ground context and verify claims against the
  running system.
