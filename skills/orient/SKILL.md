---
name: orient
description: Build or refresh the project's operational profile — stack, build/generators, commands, config & secrets, deployment, live/diagnostic access, conventions, and landmines — by discovering it from the repo FIRST and asking the user only what the repo can't answer. Persists a provenance-tagged `.agents/project.md` that the other skills read as operational ground truth. Use when confronting a new or unfamiliar project, or to refresh after infrastructure changes. The pipeline (prompt/specify) auto-runs it when the profile is missing.
---

When this skill is invoked, your job is to **find out how this project is built,
run, and deployed** — the operational questions a senior asks on day one — and
persist the answers for the rest of the pipeline to read. Capture
*meta/operational* facts only: stack, generators, commands, config, deploy,
access, conventions, landmines. **Not** the business/domain logic of a feature —
that belongs to `specify` on a specific task.

The discipline that separates this from a questionnaire: **discover before you
ask.** Answer everything the repo can answer, with evidence (`file:line`); fold in
the project's `AGENTS.md` as authoritative; only then ask the human the residue
the repo genuinely can't reveal. Never ask what `package.json` already says, and
never guess what only the developer knows.

## Procedure

1. **Check for an existing profile.** If `.agents/project.md` exists, read it and
   refresh stale or missing sections rather than rebuilding from scratch; keep
   confirmed facts that still hold.
2. **Discover from the repo (evidence first).** Walk the operational surface and
   record each fact with its source `path:line`:
   - manifests & lockfiles (`package.json`, `composer.json`, `go.mod`,
     `pyproject.toml`, `pom.xml`, `Cargo.toml`, …) and runtime pins (`.nvmrc`,
     `.tool-versions`, `engines`, Dockerfile base image);
   - build & generators (vite/webpack/rollup, sass/postcss/tailwind, `tsconfig`,
     OpenAPI/GraphQL/proto codegen, migration dirs);
   - commands (`scripts` in `package.json`, `Makefile`, `justfile`, composer
     scripts, `tox.ini`);
   - CI/CD (`.github/workflows`, `.gitlab-ci.yml`, `Jenkinsfile`);
   - containers & deploy (`Dockerfile`, `docker-compose.yml`, k8s/helm, deploy
     scripts, `Procfile`, `*.deploy`);
   - config & secrets (`.env*`, `.env.example`, `config/`);
   - conventions (`.editorconfig`, eslint/prettier/cs-fixer, `CODEOWNERS`,
     pre-commit config, existing `docs/`).
3. **Fold in `AGENTS.md`** (global + any project-level), treating its declarations
   as authoritative where they overlap discovery.
4. **Ask the human the residue — batched by category, then wait.** Only what the
   repo can't answer: which stage is *prod*, where prod secrets actually live,
   deploy auth, manual steps, the undocumented landmines. Don't proceed on guesses.
5. **Persist to `.agents/project.md`** (template below), every fact tagged by
   provenance: `[repo: path:line]`, `[AGENTS.md]`, `[user]`, or `[unknown]`. Stamp
   the date; create the directory if missing. (Honor any profile location the
   project's `AGENTS.md` defines.)
6. **Offer to seed `AGENTS.md`.** If the project has no `AGENTS.md`, or it's thin,
   *offer* to promote the confirmed facts into it so they become curated doctrine
   — only with the user's confirmation. Never rewrite `AGENTS.md` silently.
7. **Stop.** This skill ends at the persisted profile. It does not specify or
   implement.

## What to capture (operational only — never business logic)

- **A · Stack & topology** — languages + frameworks per tier (backend/frontend/
  infra); datastores; runtime versions + version manager; monorepo vs polyrepo;
  package managers + lockfiles.
- **B · Build, generators & artifacts** — asset pipeline (SCSS→CSS, JS/TS
  bundle+minify, images/fonts); codegen (API clients, ORM migrations, proto,
  i18n, type gen); **which files are generated (don't hand-edit) + the rebuild
  command**; mirrored/duplicated files + the sync-check command.
- **C · Commands** — install, dev-run, build, test, lint, format, typecheck, and
  where each is defined; **what CI gates on**.
- **D · Config & secrets** — config files + precedence; env files committed vs
  ignored; required vars to run vs to deploy; where secrets live and what must
  never be committed.
- **E · Deployment & infra** — deploy command/script and what it does;
  hosts/stages and **how to tell which is prod**; CI/CD trigger (push/tag/manual);
  containerization/orchestration.
- **F · Live & diagnostic access** — health/diagnostic endpoints, token minting,
  required headers; log retrieval (endpoint or host SFTP env var); live DB-query
  access, read-only vs mutating. *(This is what `analyze` consumes.)*
- **G · Conventions & invariants** — layering/import rules; naming + enforced
  formatting; branch/commit/PR rules + hooks; the "source of truth" docs to read
  before touching an area.
- **H · Boundaries & landmines** — vendored/third-party code not to edit;
  deprecated areas; fragile spots and manual steps the team carries in their heads.

## Output template (`.agents/project.md`)

```markdown
# Project profile

- **Generated:** <YYYY-MM-DD> by `orient`
- **Provenance:** [repo: path:line] · [AGENTS.md] · [user] · [unknown]

## Stack & topology
- <fact> [repo: path:line]

## Build, generators & artifacts
- Generated (do not hand-edit): <paths> — rebuild: `<cmd>` [repo: path:line]

## Commands
| Task | Command | Source |
|------|---------|--------|

## Config & secrets
## Deployment & infrastructure
## Live & diagnostic access
## Conventions & invariants
## Boundaries & landmines

## Open / unknown
- <fact the repo couldn't answer and the user hasn't confirmed> [unknown]
```

## Rules

- **Operational truth only.** Stack, build, commands, deploy, access, conventions,
  landmines — never the business/domain logic of a feature.
- **Discover before asking; evidence before assertion.** Tag every fact with its
  source. Mark what you couldn't confirm `[unknown]` — never fill a gap with a
  guess.
- **Persist to `.agents/project.md`** (or the project's configured location),
  created if missing. Refresh in place — don't fork parallel profiles.
- **Living document.** The profile tracks the project as it evolves: `implement`
  updates it when a change alters the operational surface (new dependency, build
  step, command, env var, service, or generated artifact), and re-running `orient`
  refreshes it wholesale. A profile that has drifted from the repo is worse than
  none — keep it honest, or mark the drifted section `[unknown]`.
- **Never rewrite `AGENTS.md` silently.** Offer to seed it; act only on
  confirmation. `AGENTS.md` is developer-owned doctrine; the profile is the
  agent's discovered, refreshable working copy.
- **Stop at the profile.** It feeds `prompt` / `specify` / `rework` / `verify` /
  `analyze`; it does not specify or implement.
