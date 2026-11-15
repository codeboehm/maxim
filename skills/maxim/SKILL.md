---
name: maxim
description: Run the maxim skill suite end to end for one request — orient (if needed), specify (which runs prompt), the deterministic pre-flight, an independent verify, and bounded rework cycles — with each step on an agent of the right role and model, announced in the chat, and stop with a specification plus its verification report. The user stays the verifier — every gate and open question goes to the user. Stops at PASS, at the loop limit, or when it needs input; never implements. Use when asked to run the whole pipeline, or to take a request to a verified spec automatically. (For a fully automatic run to an implemented change, the user invokes the separate `autopilot` skill.)
---

When this skill is invoked, you are an **orchestrator.** You sequence the other
maxim skills, dispatch each step to its role, own the loop limits, and write the
final report. You do **not** restate or replace their procedures — each skill
runs to its own bar. You do **not** implement, and you never judge your own work.

**Reaching PASS is not your goal.** Your goal is an honest account of how far
the spec got. A run that stops at the limit with its open findings listed is a
better result than a PASS reached by weakening the spec. All three end states
below are legitimate ways to finish.

Read `roles.md` (next to this skill) before the first dispatch: it defines the
roles, the model resolution order, the announce line, the capability fallback,
and your agent's adapter section.

## Input

A request to specify (free text), **or** a path to an existing spec
(`.agents/specs/<slug>.md`) — then skip to step 3. If neither is given, **ask**.

## Dispatch and announce

- Each step runs under the role `roles.md` assigns: evidence sweeps → `scout`;
  `orient`, `specify`, `rework` → `author`; `verify` → `verifier`. Pre-flight,
  `reindex.sh`, `query.sh` and test runs are deterministic: run them yourself,
  from the project root.
- **Before starting any agent, print the announce line** from `roles.md`:
  `▶ <agent> — <purpose> — model: <model> (<source>)`. Also when resuming one
  (add `resumed`), and for a role you run inline (`inline (same context)`).
- Resolve the model per `roles.md` (run instruction → routing sections →
  escalation → default). Apply escalation at dispatch when a trigger holds.
- Give a subagent paths and the instruction to follow the named skill — never
  your reasoning, your summary, or the verdict you expect.
- An author cannot ask the user. When it returns open questions, you ask the
  user, wait, then resume or re-start it with the answers; the answers are
  recorded in the persisted prompt as `Resolved (user): …`.
- No subagents available → follow the fallback chain in `roles.md`.

## Procedure

1. **Orient if needed.** If `.agents/project.md` is missing and the task is
   non-trivial, run `orient` (author; sweeps by scouts). Its questions go to the
   user.
2. **Specify.** The author follows the `specify` skill: it runs `prompt`,
   persists the structured prompt, writes the spec, and pre-flights it (at most 3
   passes). **The clarification gate stays human:** if `prompt` has open
   questions, ask the user and wait — never answer them yourself to keep the run
   moving.
3. **Check the pre-flight result.** (For a spec handed in by path, run
   `specify`'s pre-flight section on it now.) If findings are still open after
   the pass limit, go to step 6 with `STOPPED — limit reached`. Do not send a
   spec with open pre-flight findings to `verify`; its verdict would be FAIL by
   rule.
4. **Verify independently.** The verifier runs the `verify` skill on the spec in
   a **fresh context**, given only the spec path. If no separate context is
   available, run `verify` inline and label the verdict **non-independent (same
   context)**. Read the persisted report; the file, not a summary, is the result.
5. **Act on the verdict.**
   - **PASS** → step 6.
   - **FAIL / BLOCKED** → if a failed or blocked claim can only be settled by
     the user (a product decision, access you don't have), go to step 6 with
     `STOPPED — needs input`. Otherwise the author runs `rework` on the spec with
     the verification report as the rework intent — its "Failed / blocked claims
     → required fixes" list is the scope, nothing more. `rework` clarifies via
     `prompt` and re-runs `specify`'s procedure, pre-flight included. If that
     `prompt` raises open questions, ask and wait. Then return to step 3.
   - **At most 2 rework cycles** (so at most 3 `verify` runs). Stop earlier if
     a `verify` run fails or blocks on the same claims as the previous one:
     the spec is not converging, and that is a signal to reconsider the design,
     not to retry. A second FAIL on the same spec escalates the next author and
     verifier.
6. **Stop and report** (format below). Never continue into `implement`, never
   commit.

## End states

| State | Condition |
|-------|-----------|
| `PASS (draft)` | Pre-flight clean, `verify` returned PASS, and the spec's Open Questions section is empty. |
| `STOPPED — limit reached` | A loop limit or the no-progress rule ended the run with findings still open. |
| `STOPPED — needs input` | An open question, or a claim only the user can settle, remains. |

`PASS (draft)` is a draft verdict: the reviewer is a model. Say so in the
report; the user still reviews the spec.

## The bar (non-negotiable)

- **No weakening to pass.** A failing claim has two valid outcomes: it gets
  real evidence, or it moves to Open Questions as unverified. Rewording it past
  a check, deleting it, or loosening an acceptance criterion is a defect. This
  holds for the pre-flight and for `verify` findings alike.
- **Keep a change log across the run.** Record every claim removed, downgraded
  to an assumption, or moved to Open Questions, and every acceptance criterion
  changed, with the pass in which it happened. It goes into the final report in
  full, including on PASS.
- **Limits are hard.** 3 pre-flight passes per spec version, 2 rework cycles
  per run. Do not extend them because the next pass "would probably" succeed.
- **No progress means stop.** The same findings twice in a row end that loop
  immediately.
- **Human gates stay human.** Open questions from `prompt`, the acceptance of
  the spec, and the hand-off to `implement` are the user's. Only the separate
  `autopilot` skill, invoked by the user, hands gates to a decider.
- **Every agent start is announced** with role, purpose and model.
- **Thin orchestration.** If a sub-skill's rule conflicts with what you would
  do to keep the loop moving, the sub-skill's rule wins.

## Final report

Give this in the reply; the artifacts themselves are already persisted by the
sub-skills.

```markdown
**Result:** PASS (draft) | STOPPED — limit reached | STOPPED — needs input
**Spec:** <path>
**Verification:** <path> — <verdict>, independent | non-independent (same context)
**Passes used:** pre-flight <n>/3 (last spec version) · rework cycles <n>/2 · verify runs <n>

**Agents**
| Step | Role | Model requested (source) | Model reported | Fallback |
|------|------|--------------------------|----------------|----------|
| <step> | <role> | <model> (<source>) | <Model: line or "not stated"> | <none or step n> |

**Open findings**
- <pre-flight finding or failed/blocked claim, verbatim> — or "None"

**Claims removed or downgraded during the run**
- <claim> — <removed | moved to Open Questions | criterion changed> in <pass> — or "None"

**Needs from you**
- <open question or decision> — or "None"

**Next step:** review the spec · answer the questions above · reconsider the design
```

## Rules

- One request, one spec, one run.
- Requires a request or a spec path; ask if missing.
- Follow each sub-skill's own procedure and locations; do not duplicate them.
- Stop at one of the three end states and report. Never implement, never
  commit or push.
