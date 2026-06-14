# AGENTS.md — Navigation map for AI agents

> The **entry point** for any agent in this repo. It is a *map*, not a rulebook.
> Read only what your role needs, when you need it (progressive disclosure —
> this also keeps token use low).

## Before you start

1. Run `bash blinder/init.sh` (fast) and confirm it passes.
2. Read `blinder/progress/current.md` — where the last session left off.
3. Check the active feature in `blinder/feature_list.json` (or `bash blinder/cli.sh next`).

## Repository map

| Path | Contains | Read it when |
|------|----------|--------------|
| `blinder/cli.sh` | Vendored CLI — `new` / `status` / `next` (run `bash blinder/cli.sh …`) | Registering features; checking state |
| `blinder/feature_list.json` | Feature list: status, deps, sdd flag | At start |
| `blinder/progress/current.md` | Current session state (small) | At start |
| `blinder/progress/history.md` | Append-only log of closed features | Only for historical context |
| `blinder/roadmap.md` | Narrative: how an initiative was split into features (per epic) | Planning; understanding why a feature exists |
| `blinder/specs/<id>-<name>/decisions.md` | **Locked decisions** (the contract) | Before spec & implementation |
| `blinder/specs/<id>-<name>/requirements.md` | EARS requirements `R1..Rn` | Before implementation & review |
| `blinder/specs/<id>-<name>/design.md` | Technical design | Before implementation |
| `blinder/specs/<id>-<name>/tasks.md` | Task checklist `…-T1..Tn` | During implementation |
| `blinder/specs/<id>-<name>/review.md` | Reviewer verdict | After review |
| `docs/architecture.md` | Project architecture | Before implementing |
| `docs/conventions.md` | Coding & commit conventions | Before writing code |
| `docs/specs.md` | The SDD process (discussion → spec → TDD → review) | Before touching a spec |
| `blinder/CHECKPOINTS.md` | Objective done-criteria | During review |
| `blinder/prompts/roles/*.md` | The role prompts | Reference |

## Roles

| Role | Runs where | Does | Does NOT |
|------|-----------|------|----------|
| **leader** | main thread (`CLAUDE.md`) | Orchestrate; run planning/discussion/approval; dispatch subagents; update state | Write app code; skip gates |
| **planner** | main thread | Split an initiative into features (thin); insert via `blinder/cli.sh new`; keep `roadmap.md` | Design or implement; lock per-feature detail |
| **discussion** | main thread | Ask the human (`AskUserQuestion`); write `decisions.md` | Guess decisions |
| **spec_author** | subagent | Write requirements/design/tasks from decisions | Write code or tests |
| **implementer** | subagent | Red-green TDD per task | Skip the spec; gold-plate |
| **reviewer** | subagent | Traceability + add edge tests + full suite | Edit feature code |

## Lifecycle

```
(big idea) → [planner] → features inserted (pending, deps, epic)   ← macro, optional
pending → [discussion] → discussed → [spec_author] → spec_ready
       → ⏸ HUMAN → in_progress → [implementer/TDD] → implemented → [reviewer] → done
       (blocked / deferred reachable any time, with a recorded reason)
```

## Task status legend (in `tasks.md`)

`[ ]` todo · `[~]` in progress · `[x]` done · `[!]` blocked · `[-]` deferred
