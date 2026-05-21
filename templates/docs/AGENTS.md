# AGENTS.md — Navigation map for AI agents

> This file is the **entry point** for any agent working in this repository.
> It is NOT a full rulebook: it is a **map**. Read only what you need,
> when you need it (progressive disclosure).

## 1. Before you start (mandatory)

1. Run `./init.sh` and verify it finishes without errors.
2. Read `progress/current.md` to understand where the last session left off.
3. Read `feature_list.json`. Every new feature (`"sdd": true`) follows
   **Spec Driven Development** — see `docs/specs.md` and §4 below.

## 2. Repository map

| File / folder            | What it contains                                           | When to read it |
|--------------------------|------------------------------------------------------------|-----------------|
| `feature_list.json`      | Task list with status (pending/spec_ready/in_progress/done/blocked) | Always, at start |
| `progress/current.md`    | Current session state                                      | Always, at start |
| `progress/history.md`    | Append-only log of past sessions                           | If you need historical context |
| `specs/<feature>/`       | requirements.md + design.md + tasks.md                     | Before implementing any feature |
| `docs/architecture.md`   | Project architecture and what "good work" looks like        | Before implementing |
| `docs/conventions.md`    | Coding conventions                        | Before writing code |
| `docs/specs.md`          | SDD process: the 3 files, human approval gate, flow        | Before touching any spec |
| `CHECKPOINTS.md`         | Objective evaluation criteria                              | During review |

## 3. Agents

| Agent | Role | Tools | Does NOT |
|-------|------|-------|----------|
| `leader` | Orchestrates workflow, reads state, launches subagents | Read, Search, Run | Write code |
| `spec_author` | Writes specs for pending features | Read, Write, Search | Write app code |
| `implementer` | Writes code + tests following specs | Read, Write, Edit, Run | Skip specs |
| `reviewer` | Approves or rejects implementer's work | Read, Search, Run | Edit code |

## 4. SDD workflow

```
pending → [spec_author] → spec_ready → ⏸ HUMAN → in_progress → [implementer → reviewer] → done
```
