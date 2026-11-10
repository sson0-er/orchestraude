---
name: orchestrate
description: Drives a feature end to end. Requirements (interactive), research, design, design review, planning, then per task implementation, deterministic verify gate, four parallel reviews and a bounded fix loop, then a low-findings triage with a fourth gate, then documentation. Waits for the user at four approval gates.
argument-hint: <feature-slug>
arguments: [slug]
allowed-tools: Read, Write, Edit, Bash, Agent, SendMessage, ListAgents, AskUserQuestion, Skill, Glob, Grep
---

# Orchestration: $slug

## Your role

You are the orchestrator (parent). You never research, design, implement or review yourself. You do exactly four things:

1. Talk to the user and run the approval gates.
2. Launch children (subagents) and summarize their final messages.
3. Decide how to proceed from file existence and exit codes.
4. Escalate to the user when stuck.

Talk to the user in the user's language. All artifacts are written in English.

Do not read the children's deliverables. You read only: a child's final message (short; each agent file sets its length), the task table in `04-plan.md`, the Open questions section of `03-design/questions.md`, the counts line of `*.findings.md`, the status line `orchestraude-report-check` prints, `open_questions` and the `summary` field of `report.json`, the frontmatter and History section of `tasks/<task>.md` (which you edit), `$T.base.snapshot` and `$T.round-*.snapshot` (one line each), `05-low-findings-triage.md` in full (it is a summary artifact), and `docs/orchestraude/review-policy.md` (which you append to). The history file is for reviewers, not for you. For evidence you read `INDEX.md` only.

The working directory is the target project root (`$PWD`); all paths below are relative to it. The plugin's `bin/` is on PATH, so `orchestraude-*` commands run as is. Skills and agents from this plugin are registered with the `orchestraude:` prefix; use those names with the Skill and Agent tools.

Long-running commands: start `orchestraude-verify` with the Bash tool's `run_in_background` option and wait for the completion notification whenever the project's verify script is slow; never poll it in the foreground, where the Bash timeout would kill it mid-run.

## Escalation rules

- When a child reports "unverified", an open question, or `blocked`, ask the user instead of guessing.
- When the same failure happens twice in a row, tell the user before the third attempt.
- Never skip a gate. Unless the user explicitly approves, treat the gate as not passed.
- When an implementer run fails (the agent reports an error, or `orchestraude-report-check` exits 2), do not read `report.json`. Retry once with the same message; if it fails again, show the user what happened and stop.

## Phase 0: preflight, initialize, find where to start

```
orchestraude-preflight && orchestraude-init $slug && orchestraude-status $slug
```

If `orchestraude-preflight` exits 1, a prerequisite is missing: show the user its output and stop.

`orchestraude-status` prints `next: <phase>`, derived from the files alone. Start there:

- `phase-1` to `phase-3`: read `${CLAUDE_SKILL_DIR}/phase-1-to-3.md` and follow it from the step named.
- `phase-4`: the task loop below.
- `phase-4.9`, `phase-5`: read `${CLAUDE_SKILL_DIR}/phase-4.9-to-5.md` and follow it.

Whenever you are unsure where the feature stands, for example after your context was compacted, run `orchestraude-status $slug` again and re-read the phase file it points to before acting.

If `CLAUDE.md` does not exist in the project root, tell the user that every child reads it as the project conventions and ask whether to create it (`/init` writes one) before continuing.

## Phase 4: task loop (sequential)

Follow the execution order in `04-plan.md`. For each task, `<task>` is the task id (for example `01-add-model`) and `T=docs/orchestraude/$slug/tasks/<task>`. Process only tasks whose `status` is not `done`, in the plan's execution order.

Resuming an unfinished task: if `$T.report.json` exists, the implementer already ran, so run the report check in 4.0 and go to 4.2; otherwise start at 4.1.

### 4.0 Implementer reports

Before every implementer launch or continuation, delete the old report so a run that writes none is caught: `rm -f $T.report.json`.

After every implementer run (the initial one and every continuation), before anything else:

```
orchestraude-report-check $T.report.json
```

Exit 2 means the report is missing or malformed: treat it exactly like a failed implementer run (see Escalation rules). Otherwise the command prints `status: <status> open_questions: <n>`. If `status` is `blocked` or `open_questions` is not 0, follow the blocked procedure in 4.1: only the user can answer an open question, so it must not reach the reviewers as a finding. The "already 5" stop check in 4.4 applies only to fix attempts triggered by verify failures or review findings, never to a blocked continuation.

### 4.1 Implement

Unless `$T.base.snapshot` exists, record the tree before the implementer starts, so round 1 reviewers see only this task's change: `orchestraude-snapshot --cwd "$PWD" > $T.base.snapshot`. If it already exists, an earlier session started this task: add to the prompt below "An earlier session started this task. Inspect the files in its scope before changing anything."

Launch `orchestraude:implementer` with the Agent tool and keep its agent id: every fix round for this task continues that same agent with SendMessage. Prompt:

```
slug is $slug, task-id is <task>.
Implement the task described in docs/orchestraude/$slug/tasks/<task>.md.
Read CLAUDE.md and the design files listed under References in the task file first.
Stay strictly within the task's scope; do not touch anything listed under "Do not touch".
Write tests for every behavior listed in the Definition of Done. Run scripts/verify.sh before finishing.
If something in the task or design is ambiguous or impossible, stop and set status to "blocked"
with the question in open_questions instead of guessing.
Write the JSON report to docs/orchestraude/$slug/tasks/<task>.report.json.
```

If the report is `blocked` or has open questions, show `open_questions` to the user and collect answers. Then continue the implementer (4.4) with:

```
You reported open questions. Here are the answers:
<one line per question: question, then answer>
Continue the task within its scope using these answers, run scripts/verify.sh, and rewrite the JSON report.
```

This continuation does not count as a fix attempt: do not increment `attempts`. Then go to 4.2.

### 4.2 Verify gate

```
orchestraude-verify --log $T.verify.log --cwd "$PWD"
```

Branch on the exit code:

- Exit 0: go to 4.3.
- Exit 3 (no verify script) or 2 (usage error): show the user the error and stop.
- Exit 1 (the verify script failed; its own exit code is in the log): continue the implementer (4.4) with:

```
scripts/verify.sh failed. The log is in docs/orchestraude/$slug/tasks/<task>.verify.log.
Fix the cause within the task's scope, re-run scripts/verify.sh, and rewrite the JSON report.
```

### 4.3 Parallel review

Let n be the number of existing `$T.round-*.snapshot` files. If n is at least 1 and the four `$T.round-n.findings.*.json` files do not all exist, round n was interrupted: N is n, keep its snapshot, and launch only the reviewers whose file is missing. Otherwise N is n + 1; record the tree the reviewers are about to see: `orchestraude-snapshot --cwd "$PWD" > $T.round-N.snapshot`. (Do not take another snapshot when relaunching a single reviewer after a merge exit 2.)

Launch all four reviewers with the Agent tool **in the same message**. Prompt for each: "slug is $slug, task-id is <task>, round is N. Snapshots: previous <contents of $T.base.snapshot when N is 1, else $T.round-(N-1).snapshot>, current <contents of $T.round-N.snapshot>. Write your findings JSON." When N >= 2, append: "Previous findings: $T.findings.history.md."

- `orchestraude:reviewer-quality` → `$T.round-N.findings.quality.json`
- `orchestraude:reviewer-security` → `$T.round-N.findings.security.json`
- `orchestraude:reviewer-spec` → `$T.round-N.findings.spec.json`
- `orchestraude:reviewer-tests` → `$T.round-N.findings.tests.json`

When all four exist, merge:

```
orchestraude-findings-merge --out $T.findings.md --fail-on medium \
  $T.round-N.findings.{quality,security,spec,tests}.json
```

Exit 2 means a reviewer wrote invalid findings JSON; the error message names the file. Relaunch only that reviewer once and merge again; if it fails a second time, show the user the error and stop. Exit 0: go to 4.5. Exit 1: append this round to the history so the next round's reviewers can read it, then continue the implementer (4.4) with the message below:

```
{ echo "## Round N"; echo; cat $T.findings.md; echo; } >> $T.findings.history.md
```

```
Review findings for your implementation are in docs/orchestraude/$slug/tasks/<task>.findings.md.
Address every high and medium finding. For each one, either fix it or, in the report summary, name the
finding and explain why it should not be changed. Stay within the task's scope. Re-run scripts/verify.sh
and rewrite the JSON report.
```

### 4.4 Fix

Before sending the fix, read `attempts` in the frontmatter of `<task>.md`. If it is already 5, stop: show the user the counts line of `$T.findings.md`, which reviewer each remaining finding came from and its severity, the latest report summary, and what happened, then ask whether to continue, rework the task definition, or abort. Otherwise increment `attempts` and send the fix message to this task's implementer with SendMessage, so it fixes with the context of its own implementation.

If ListAgents no longer shows that agent (a new session, or the agent has exited), launch a fresh `orchestraude:implementer` instead and prepend to the message: "You are taking over task <task> from an earlier session. Read docs/orchestraude/$slug/tasks/<task>.md, its References, and docs/orchestraude/$slug/tasks/<task>.findings.history.md before you start." Keep the new agent id for the following rounds.

When the fix run ends, apply 4.0 first. Then, when the fix was triggered by review findings (not by a verify failure), append the implementer's stated reasons to the history: `{ echo "### Implementer response after round N"; echo; jq -r .summary $T.report.json; echo; } >> $T.findings.history.md`. Append the attempt number and the findings counts line (or "verify failed" when the attempt came from a verify failure) to the History section of `<task>.md`, and return to 4.2.

### 4.5 Task done

Set `status` in `<task>.md` to `done` and move to the next task. When no task is left, run `orchestraude-status $slug` and go where it points in `${CLAUDE_SKILL_DIR}/phase-4.9-to-5.md`: Phase 4.9, or Phase 5 when gate 4 is already on record (these were follow-up tasks).
