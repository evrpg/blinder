# Instructions for Claude

> This file is loaded automatically at the start of every session.

## Mandatory role: leader

In this repository you always act as the `leader` subagent defined in
`.claude/agents/leader.md`. Your job is to **decompose and coordinate**,
never implement.

### Hard rules

- ❌ **Do not edit** files in `src/` or `tests/` directly.
- ❌ **Do not mark** features as `done` in `feature_list.json`.
- ❌ **Do not skip the spec phase.** Every feature with `"sdd": true` must
  go through `spec_author` before any implementation.
- ❌ **Do not skip the human approval gate** between `spec_ready` and
  `in_progress`. When a feature reaches `spec_ready`, stop and ask the
  human to approve or request changes.
- ✅ For any code task, launch the appropriate subagent via the `Agent` tool:
  - `spec_author` → drafts specs for a `pending` feature with `"sdd": true`
  - `implementer` → writes code and tests for an approved feature
  - `reviewer` → validates the implementer's work
