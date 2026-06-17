---
name: prompt
description: Turn a rough request into a structured XML task spec (role, context, constraints, instructions, acceptance criteria, open questions) and surface gaps BEFORE writing code. Use at the start of any non-trivial task, or when a request feels under-specified.
---

When this skill is invoked, **do not implement and do not draft a plan.** Your
only job is to turn the user's request into one structured task spec, **store it
to the project's `.agents/prompts/` directory**, and stop. The value is not the
XML syntax — it is forcing every section to be filled, which makes missing
context and hidden ambiguity visible before any code or plan exists.

## Procedure

1. Read the user's request, the loaded `AGENTS.md` (global + project), and the
   project's operational profile `.agents/project.md` if present — it is your fast
   path to the real stack and constraints. If the profile is **missing** and this
   is a non-trivial task, run the `orient` skill first (say so), then continue.
2. Pull `<context>` and `<constraints>` from the **actual repository** — real
   files, stack, schemas, and the project's hard rules. Never invent
   placeholders. If a fact is missing, do not guess it: list it under
   `<open_questions>`. Where the project exposes live access (agent endpoints,
   logs, DB — see the `analyze` skill), use it to ground context and resolve
   facts rather than leaving them open.
3. Emit exactly one `<task_spec>` block (template below).
4. **Always store it** to `.agents/prompts/<unix-timestamp>-<kebab-slug>.md` in
   the project (create the directory if missing). Get `<unix-timestamp>` from the
   real clock — run `date +%s` — never invent or estimate the number. This is
   automatic — never ask whether to save, and never use any other location.
5. If `<open_questions>` is non-empty, ask those questions and **wait**.
6. **Stop.** This skill ends at the stored spec. Do not draft a plan, a logic
   blueprint, or any code — that is a separate, explicitly-invoked step.

## Output template

```xml
<task_spec>
  <system_role>
    The role and stance to adopt for this task (e.g. a paranoid systems
    architect hunting structural flaws, race conditions, and data leaks).
  </system_role>

  <context>
    The real tech stack, the specific files/functions in scope, relevant DB
    schema or data shapes, and the current code under change. Concrete, pulled
    from the repo — not generic.
  </context>

  <constraints>
    The hard rules that must hold for this change (from AGENTS.md and the
    domain): security, legal, data-integrity, style, and deploy constraints.
  </constraints>

  <instructions>
    1. Threat analysis first — concurrency/idempotency, failure-midway state,
       hostile or malformed input, missing/erroring dependencies.
    2. Logic blueprint — a step-by-step summary of the approach BEFORE any code.
    3. Implementation — typed, guarded, with explicit error handling and cleanup.
  </instructions>

  <acceptance_criteria>
    Observable conditions that mean the task is done and correct.
  </acceptance_criteria>

  <open_questions>
    Anything ambiguous or unverifiable. If this section is non-empty, ask before
    writing code.
  </open_questions>
</task_spec>
```

## Rules

- Keep every section tight — concrete sentences, no filler.
- **Always persist to the project's `.agents/prompts/`** —
  `.agents/prompts/<unix-timestamp>-<kebab-slug>.md`, created if missing.
  Storing is unconditional and automatic: do not ask, and do not write to
  `.vibe/`, a temp dir, or anywhere else. (If the project's `AGENTS.md` names a
  different prompts location, honor that instead.)
- **Stop after storing.** Producing and saving the structured prompt is the whole
  job — do not continue into planning, a blueprint, or implementation.
