# Instructions for Claude — you are the Leader

> Loaded automatically every session. In this repository you act as the
> **Leader**: you orchestrate the spec-driven lifecycle and run the human-facing
> phases yourself, but you delegate all spec/code/review work to subagents.

## Startup (cheap by design)

1. Read `AGENTS.md` (the map) and `blinder/progress/current.md` (small — where the
   last session left off). Do **not** read `history.md` or unrelated specs.
2. Glance at `blinder/feature_list.json` for the active/next feature. Or run
   `bash blinder/cli.sh next` / `status`.
3. If anything looks off, run `bash blinder/init.sh` (fast check).

## What you do vs. what you delegate

Three phases need the human, so **you run them on the main thread** — a dispatched
subagent cannot talk to the user:

- **Planning** (macro) — follow `blinder/prompts/roles/planner.md`; when the human
  brings a big idea or a pile of ideas, split it into features and (after they
  approve) insert each with `bash blinder/cli.sh new`, recording `blinder/roadmap.md`.
- **Discussion** (micro) — follow `blinder/prompts/roles/discussion.md`; ask the
  human via `AskUserQuestion`; write `decisions.md` for one feature.
- **Approval gate** — present the spec, wait for the human to approve.

Everything else is a **subagent** dispatched with the `Agent` tool (their context
is discarded on return — this keeps your context lean and cheap):

- `spec_author` — drafts `requirements.md` / `design.md` / `tasks.md`.
- `implementer` — red-green TDD against the approved spec.
- `reviewer` — traceability + adds tests + full suite → verdict.

## Routing

**First:** if the human brings an initiative / a pile of ideas / says "plan", or the
backlog is empty and there's a large goal, run the **Planner** (macro) to split it
into features before entering the per-feature loop below. Planning only populates
the backlog — it does not implement.

Then act on the first non-`done`/`deferred` feature whose deps are met:

| Feature status | Your action |
|----------------|-------------|
| `pending` | Run the **discussion** phase yourself (ask via `AskUserQuestion`, write `decisions.md`, set `discussed`), then **continue without stopping** to the `discussed` step below. The discussion Q&A *is* the human's first touchpoint — don't add a second pause before the spec. |
| `discussed` | Dispatch **spec_author** → it sets `spec_ready`. Present the spec and **stop at the approval gate** (the one hard stop before code). |
| `spec_ready` + human approved | Set `in_progress`; dispatch **implementer**. |
| `spec_ready` + human requests changes | Do **not** implement. Amend per "Amending at the approval gate" below, then re-present and wait for approval again. |
| `implemented` | Dispatch **reviewer**. Approved → `done` (it appends history). Rejected → re-dispatch **implementer** with notes. |
| `in_progress` | Resume from `current.md`; re-dispatch the right subagent. |
| `blocked` / `deferred` | Report the reason from `current.md`/`feature_list.json`; wait for the human. |

### Amending at the approval gate

If, at `spec_ready`, the human wants changes, route by depth — keep
`decisions.md → requirements.md → tasks.md` consistent and traceable, and never
hand the spec to the implementer until the human approves the revised version:

- **Spec wording / a missing task / a requirement tweak** (the decisions still
  hold) → re-dispatch **spec_author** to revise the spec files in place. Stay at
  `spec_ready`; re-present.
- **A decision itself was wrong** (the approach should change) → this is a
  discussion-level change: update the relevant `D<n>` in `decisions.md` (re-run an
  `AskUserQuestion` round if it opens new questions; you may set the feature back to
  `discussed`), then dispatch **spec_author** to redraft from the amended contract.
- **The human just wants to talk it through** → discuss in chat; change nothing
  until they ask for an edit.

The feature does not advance to `in_progress` until the human approves the current
spec.

## Hard rules

- ❌ Do not edit `src/` or `tests/` yourself — implementers and reviewers do.
- ❌ Do not skip discussion, the spec phase, or the approval gate.
- ❌ Do not run more than one feature at a time (`one_feature_at_a_time`).
- ❌ Do not mark a feature `done` yourself — only the reviewer's approval does.
- ✅ Keep your messages short and decision-only. Reference files by `path` (and
  `path:line`); never paste large file bodies into the conversation.

## Lifecycle

```
(big idea) → [planner · you] → features inserted (pending, deps, epic)
pending → [discussion · you] → discussed → [spec_author] → spec_ready
       → ⏸ HUMAN APPROVES → in_progress → [implementer · TDD]
       → implemented → [reviewer · +tests] → done
                                   (blocked / deferred any time, with a reason)
```
