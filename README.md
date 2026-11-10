# orchestraude

A Claude Code plugin that makes Claude Code the orchestrator and delegates every step to role-specific Claude subagents, split between Opus 5.5 and Sonnet 5.5. Research, design, design review, planning, implementation and review all run inside Claude Code; no external CLI is involved.

## Prerequisites

- Claude Code, `git` and `jq`
- macOS or Linux (bash 3.2 or newer)
- The target project is a git repository: each review round diffs snapshots of the working tree
- In the target project: `scripts/verify.sh`, one executable that runs lint, type checks, build, tests and prints a coverage summary (must be executable; `ORCHESTRAUDE_VERIFY_CMD` takes a single executable path, no arguments)
- In the target project: `CLAUDE.md` with the project conventions; every subagent reads it
- A session whose permission mode lets subagents edit files and run `scripts/verify.sh`: the implementer writes to the working tree directly

## Install

This repository is also a plugin marketplace. Inside a Claude Code session:

```
/plugin marketplace add sson0-er/orchestraude
/plugin install orchestraude@orchestraude
```

Pick up new versions with `/plugin marketplace update orchestraude`. To remove it, run `/plugin uninstall orchestraude@orchestraude`.

While developing, you can instead load the repo directly for one session:

```
claude --plugin-dir /path/to/orchestraude
```

## Usage

From the target project root, inside a Claude Code session:

```
/orchestraude:orchestrate <feature-slug>
```

Plugin skills are always namespaced with the plugin name, so the short form `/orchestrate` does not exist.

The flow is: requirements (interactive), research, design, design review, plan, then per task implementation, verify gate, four parallel reviews and a bounded fix loop, then a low-findings triage, then documentation. It stops for explicit approval after requirements, after design, after the plan, and after the triage (four gates).

Running the same command again resumes an interrupted feature. The orchestrator does not rely on memory for this: `orchestraude-status` reads where the feature stands from the files under `docs/orchestraude/<feature-slug>/`, including the gate approvals recorded in `gates.md`.

Each task is implemented by one `implementer` subagent, and every fix round continues that same agent, so it fixes with the context of its own implementation. The orchestrator itself never reads the deliverables; it branches on exit codes, counts lines and the children's short final messages.

## Layout

| Path | Role |
|---|---|
| `bin/orchestraude-preflight` | Checks the prerequisites (jq, git repository, verify script) before any work starts |
| `bin/orchestraude-status` | Prints the next step of a feature from its files, to start, resume or re-orient |
| `bin/orchestraude-verify` | Verify gate: runs `scripts/verify.sh` and keeps the log |
| `bin/orchestraude-report-check` | Validates an implementer report against the schema and prints its status |
| `bin/orchestraude-report-clear` | Deletes a task's old implementer report before the implementer runs again, so a run that writes none is caught; a command instead of `rm` so sessions that ask before every `rm` are not interrupted |
| `bin/orchestraude-findings-merge` | Merges review findings and applies a severity threshold |
| `bin/orchestraude-findings-triage` | Merges leftover low findings across all tasks of a feature, deterministically, before the triage agent classifies them |
| `bin/orchestraude-init` | Creates the `docs/orchestraude/` layout |
| `bin/orchestraude-snapshot` | Snapshots the working tree as a commit object so each review round diffs only the task's change (round 1) or the fix (later rounds) |
| `agents/` | researcher, designer, design-reviewer, planner, implementer, reviewer-{quality,security,spec,tests}, triage, doc-writer |
| `skills/` | orchestrate (full flow), orchestrate-fable (the same flow with the design roles on Fable 5.2), define-requirements (interactive), record-evidence (recording rules), review-rules (findings shape, severity calibration and later rounds shared by the four reviewers) |
| `templates/` | Artifact templates |
| `schemas/` | JSON Schemas for findings and reports |

Artifacts live under `docs/orchestraude/` in the target project. Evidence (recorded external facts) and decisions (recorded design choices) accumulate across features.

## Models

Roles whose mistakes carry into every later task run on Opus; high-volume roles that follow a fixed procedure run on Sonnet. Spec and security review use a different model from the implementer, so the reviewer is less likely to share the implementer's blind spots. The orchestrator itself runs on whatever model the session uses.

| Agent | Model | Effort |
|---|---|---|
| designer, design-reviewer, planner | `claude-opus-5-5` | high |
| reviewer-spec, reviewer-security | `claude-opus-5-5` | high |
| triage | `claude-opus-5-5` | medium |
| implementer | `claude-sonnet-5-5` | high |
| reviewer-quality | `claude-sonnet-5-5` | medium |
| researcher, reviewer-tests | `claude-sonnet-5-5` | medium |
| doc-writer | `claude-sonnet-5-5` | low |

Each agent sets its model and effort in its frontmatter; `tests/test_frontmatter.sh` pins this table.

### Fable variant

```
/orchestraude:orchestrate-fable <feature-slug>
```

runs the same flow with designer, design-reviewer and planner on Fable 5.2 instead of Opus 5.5, at the same effort. Every other role keeps the model in the table. Only the user can start it; Claude never picks it on its own.

The choice is stored in `docs/orchestraude/<feature-slug>/design-model` and holds for the life of the feature: resuming with either command keeps the design roles on Fable. Delete that file to go back to Opus.

## Environment variables

| Variable | Default | Purpose |
|---|---|---|
| `ORCHESTRAUDE_VERIFY_CMD` | `scripts/verify.sh` | Verify gate command |

## Tests

```
bash tests/run.sh
```

No external dependencies beyond `git` and `jq`. GitHub Actions runs the suite on macOS and Linux for every push to `main` and every pull request.
To run the same suite on Linux with Docker:

```
docker run --rm -v "$PWD":/w -w /w alpine:3 sh -c 'apk add -q bash jq git && bash tests/run.sh'
```
