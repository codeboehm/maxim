# maxim — discipline (always on)

These rules apply to **every** task, in any agent, whether or not a maxim skill is
invoked. They are the always-loaded floor; the skills add procedure on top.

1. **Never auto-commit or auto-push.** Stop after implementing; the developer
   reviews and confirms. A confirmation gate is not optional. Only the user's
   explicit grant authorises a commit, push or promotion; an agent's approval
   (e.g. a decider's) never does and never widens the grant.
2. **Orient before non-trivial work.** Read the project's operational profile
   `.agents/project.md` first; if it's missing, build it (the `orient` skill) before
   specifying or implementing. Don't guess stack, commands, or conventions — read them.
3. **Discover before asking; evidence before assertion.** Answer from the repo with
   `file:line` citations before asking the human. Never fill a gap with a guess —
   mark what you can't confirm as unknown.
4. **Verification is shown, not described.** A claim is "verified" only when you ran
   the check and can paste the `file:line` or command output. A commented-out command
   proves nothing. Run `preflight.sh` (bundled with the `verify` skill) before
   trusting any verdict, and treat any LLM verdict as a **draft**, not a result.
5. **Behavioral/security claims need the path.** For any "X can reach Y / breaks / is
   safe / is required," show the real caller(s) (`grep`) and the gate at `file:line`,
   and confirm the branch is actually reached. Names and prose are not evidence.
6. **Artifacts live under `.agents/`** in the project: `project.md` (profile),
   `prompts/`, `specs/`, `plans/`, `verifications/`. Plus `index.md`, the
   deterministic catalog kept current by the `index` skill. Honor any locations
   the project's `AGENTS.md` defines instead.
7. **Announce every agent you start.** Before starting (or resuming) a subagent,
   print one line to the user: `▶ <agent> — <purpose> — model: <model> (<source>)`
   — `inherited` when you don't choose it. Roles and models: `roles.md` in the
   `maxim` skill.

**The pipeline:** `orient` → `prompt` → `specify` → `implement`; `maxim` runs
`orient` → `specify` → `verify` → `rework` for one request, to a bounded stop
(PASS, loop limit, or needs input) — never into `implement`, with the user as
the verifier; `autopilot` (only when the user invokes it) runs the same steps
plus `implement` with a decider agent at the gates, committing only under the
grant in the invocation; `rework` revises an artifact, `analyze` investigates, `verify`
independently fact-checks. `index` catalogs `.agents/` so the others can look up
prior work without rereading it. `voice` is a tone lens over direct replies only
— never over artifacts. Each skill stops for review and hands off; none
auto-commits.
