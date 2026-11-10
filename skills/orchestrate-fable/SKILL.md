---
name: orchestrate-fable
description: The orchestrate flow with the design roles (designer, design-reviewer, planner) on Fable 5.2 instead of Opus 5.5. Every other role keeps its model. Started only by the user.
argument-hint: <feature-slug>
arguments: [slug]
allowed-tools: Bash, Skill
disable-model-invocation: true
---

# Orchestration with Fable design roles: $slug

Record the choice for this feature. It is kept in a file so every launch of a design role uses it, also after a resume or a context compaction:

```
orchestraude-preflight && orchestraude-init $slug && echo fable > docs/orchestraude/$slug/design-model
```

If the command fails, show the user the error and stop.

Then invoke the `orchestraude:orchestrate` skill with `$slug` and follow it. It is the same flow; `orchestraude-status` now also prints `design-model: fable`, and the phase files say what to do with that line.
