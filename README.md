# orchestraude

A Claude Code plugin that makes Claude Code the orchestrator and delegates every step to role-specific Claude subagents. Research, design, design review, planning, implementation and review all run inside Claude Code; no external CLI is involved.

## Prerequisites

- Claude Code and `jq`
- macOS or Linux (bash 3.2 or newer)
- In the target project: `scripts/verify.sh`, one executable that runs lint, type checks, build, tests and prints a coverage summary (must be executable; `ORCHESTRAUDE_VERIFY_CMD` takes a single executable path, no arguments)
- In the target project: `CLAUDE.md` with the project conventions; every subagent reads it
- A session whose permission mode lets subagents edit files and run `scripts/verify.sh`: the implementer writes to the working tree directly

## Install

For personal use, copy the plugin into Claude Code's skills directory, where it auto-loads in every session as `orchestraude@skills-dir`:

```
./install.sh
```

The destination is `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/skills/orchestraude` (override with `--dest DIR`). Run `/reload-plugins` to load it without restarting. Re-run `./install.sh` after changing the plugin; it replaces the previous copy. To remove it, delete that directory, or disable it with `claude plugin disable orchestraude@skills-dir`.

While developing, you can instead load the repo directly for one session:

```
claude --plugin-dir /path/to/orchestraude
```

Publishing through a private marketplace (for example a `~/.orchestraude` directory with a `.claude-plugin/marketplace.json`) is a possible later step; it is not set up yet.

## Usage

From the target project root, inside a Claude Code session:

```
/orchestraude:orchestrate <feature-slug>
```

Plugin skills are always namespaced with the plugin name, so the short form `/orchestrate` does not exist.

The flow is: requirements (interactive), research, design, design review, plan, then per task implementation, verify gate, four parallel reviews and a bounded fix loop, then a low-findings triage, then documentation. It stops for explicit approval after requirements, after design, after the plan, and after the triage (four gates).

Each task is implemented by one `implementer` subagent, and every fix round continues that same agent, so it fixes with the context of its own implementation. The orchestrator itself never reads the deliverables; it branches on exit codes, counts lines and the children's short final messages.

## Layout

| Path | Role |
|---|---|
| `bin/orchestraude-verify` | Verify gate: runs `scripts/verify.sh` and keeps the log |
| `bin/orchestraude-report-check` | Validates an implementer report against the schema and prints its status |
| `bin/orchestraude-findings-merge` | Merges review findings and applies a severity threshold |
| `bin/orchestraude-findings-triage` | Merges leftover low findings across all tasks of a feature, deterministically, before the triage agent classifies them |
| `bin/orchestraude-init` | Creates the `docs/orchestraude/` layout |
| `bin/orchestraude-snapshot` | Snapshots the working tree as a commit object so later review rounds diff only the fix |
| `agents/` | researcher, designer, design-reviewer, planner, implementer, reviewer-{quality,security,spec,tests}, triage, doc-writer |
| `skills/` | orchestrate (full flow), define-requirements (interactive), record-evidence (recording rules) |
| `templates/` | Artifact templates |
| `schemas/` | JSON Schemas for findings and reports |
| `install.sh` | Copies the runtime files into the skills directory (see Install) |

Artifacts live under `docs/orchestraude/` in the target project. Evidence (recorded external facts) and decisions (recorded design choices) accumulate across features.

Every agent runs on `claude-sonnet-5`; the reasoning effort per role is set in each agent's frontmatter.

## Environment variables

| Variable | Default | Purpose |
|---|---|---|
| `ORCHESTRAUDE_VERIFY_CMD` | `scripts/verify.sh` | Verify gate command |

## Tests

```
bash tests/run.sh
```

No external dependencies beyond `jq`.
To run the same suite on Linux with Docker:

```
docker run --rm -v "$PWD":/w -w /w alpine:3 sh -c 'apk add -q bash jq git && bash tests/run.sh'
```
