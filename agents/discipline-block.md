# maxim — discipline (always on)

These rules apply to **every** task, in any agent, whether or not a maxim skill is
invoked. They are the always-loaded floor; the skills add procedure on top.

1. **Never auto-commit or auto-push.** Stop after implementing; the developer
   reviews and confirms. A confirmation gate is not optional.
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
   `prompts/`, `specs/`, `plans/`, `verifications/`. Honor any locations the project's
   `AGENTS.md` defines instead.

**The pipeline:** `orient` → `prompt` → `specify` → `implement`; `rework` revises an
artifact, `analyze` investigates, `verify` independently fact-checks. `voice` is a
tone lens over direct replies only — never over artifacts. Each skill stops for
review and hands off; none auto-commits.
