# 🧠 Blinder

**A scaffolding system that imprints a disciplined, spec-driven development (SDD)
workflow onto any project — and lets [Claude Code](https://claude.com/claude-code)
drive it with its native multi-agent features.**

![shell: bash](https://img.shields.io/badge/shell-bash-121011)
![requires: jq](https://img.shields.io/badge/requires-jq-blue)
![runtime: Claude Code](https://img.shields.io/badge/runtime-Claude%20Code-8A2BE2)
![status: experimental](https://img.shields.io/badge/status-experimental-orange)

Blinder is **not a runtime**. It does not call any LLM API or run an autonomous
loop. It writes the prompts, on-disk state, and editor hooks that make Claude Code
orchestrate *itself* reliably:

- **Lock decisions with you before any code** (a discussion phase that asks real questions).
- **Write specs as contracts** (EARS requirements → design → tasks, with stable IDs).
- **Implement test-first** (red-green TDD; the reviewer adds edge-case tests).
- **Track everything on disk** so work resumes after any interruption.
- **Stay token-frugal** by design.

> 📖 Deep documentation lives in **[MANUAL.md](./MANUAL.md)**. This README is the tour.

---

## Contents

- [Why](#why)
- [How it works](#how-it-works)
- [Requirements](#requirements)
- [Install](#install)
- [Quickstart](#quickstart)
- [CLI reference](#cli-reference)
- [What gets scaffolded](#what-gets-scaffolded)
- [Concepts](#concepts)
- [Token efficiency](#token-efficiency)
- [This repository](#this-repository)
- [Extending: Skills & MCP](#extending-skills--mcp)
- [FAQ](#faq)
- [Prior art](#prior-art)
- [Contributing](#contributing)
- [License](#license)

---

## Why

AI coding agents are strongest when the *environment* around them is structured:
clear contracts, deterministic checks, human gates at the right moments, and state
that survives a restart. Left unstructured, they guess, re-litigate decisions, and
burn tokens re-deriving context.

Blinder encodes a method proven across a large real project — lock decisions first,
specify before building, test-drive, review, and keep an on-disk dashboard — and
makes it reproducible in any new repo with one command. It targets **Claude Code**
specifically so it can use native mechanisms: `AskUserQuestion` for the discussion
phase, real subagents for spec/implement/review, and editor hooks for verification.

## How it works

Two altitudes. **Planning** (macro, optional) turns a big idea into many features;
the **per-feature loop** (micro) runs on each one.

```
(big idea / many ideas)
  → [PLANNER]        split into thin, ordered features → YOU APPROVE → inserted as pending

pending
  → [DISCUSSION]     ask questions (AskUserQuestion) → write decisions.md   ← main thread
  → discussed
  → [SPEC]           requirements.md (EARS) + design.md + tasks.md          ← subagent
  → spec_ready
  → ⏸ YOU APPROVE
  → in_progress
  → [IMPLEMENT]      per task: failing test → minimal code → green (TDD)    ← subagent
  → implemented
  → [REVIEW]         requirement→test traceability + add edge tests + full suite ← subagent
  → done
                     (blocked / deferred reachable any time, with a reason)
```

**The main-thread / subagent split is deliberate.** `AskUserQuestion` and the
approval gate can only happen in the main conversation, so the **Leader** runs
*planning*, *discussion*, and *approval* itself. Spec, implementation, and review
run as **subagents** whose context is discarded on return — which keeps the
Leader's context small and is the single biggest token win.

A large initiative is therefore just an **epic-tagged chain of features** linked by
`depends_on`. Each one gets its *own* discussion, spec, approval, and review gate.

## Requirements

- **[Claude Code](https://claude.com/claude-code)** — the runtime that drives the workflow.
- **git** — Claude Code uses it for diffs; also your project history.
- **bash** and **[jq](https://jqlang.github.io/jq/)** — used by the CLI and the verification harness.

## Install

```bash
git clone https://github.com/<you>/blinder.git
# optional: add a convenience alias to your shell profile
echo 'alias blinder="'"$PWD"'/blinder/scripts/blinder.sh"' >> ~/.bashrc
```

There is nothing to build — Blinder is bash + templates.

## Quickstart

```bash
# 1. New project + git (mandatory: Claude Code relies on a git repo)
mkdir my-app && cd my-app && git init

# 2. Scaffold the harness
blinder init --name "my-app"          # or: /path/to/blinder/scripts/blinder.sh init

# 3. Fill in the two docs the agents read before coding
$EDITOR docs/architecture.md docs/conventions.md

# 4. Baseline commit
git add . && git commit -m "chore: scaffold blinder harness"

# 5a. Register a single feature…
blinder new "User login"

# 5b. …or bring a big idea and let the Planner split it:
#     open Claude Code and say:  "plan: <your brain-dump>"

# 6. Drive it — open Claude Code and say:
#     "Work the next pending feature."
```

## CLI reference

| Command | Description |
|---------|-------------|
| `blinder init [--name N]` | Scaffold the harness into the current directory. |
| `blinder new "title" [opts]` | Register a feature; assigns the next `FR-XXXX` id. |
| `blinder status` | Dashboard of all features — state, deps, blocked reasons — grouped by epic. |
| `blinder next` | Print the next actionable feature (all dependencies satisfied). |
| `blinder help` | Usage. |

**`new` options:** `--description "…"` · `--acceptance "a, b, c"` ·
`--depends-on "FR-0001,FR-0002"` · `--epic "name"` · `--no-sdd` (skip the SDD flow
for a trivial chore). With an interactive terminal and no flags, `new` prompts you
for the description and acceptance criteria. The **Planner** calls `new` for you
when you bring an initiative.

## What gets scaffolded

```
my-app/
├── CLAUDE.md                 # Leader instructions (loaded every Claude Code session)
├── AGENTS.md                 # Navigation map for agents
├── docs/
│   ├── architecture.md       # YOU fill this in
│   ├── conventions.md        # YOU fill this in
│   └── specs.md              # the SDD process reference
├── .claude/
│   ├── settings.json         # PostToolUse hook → fast verification after edits
│   └── agents/               # spec_author · implementer · reviewer (subagents)
└── blinder/
    ├── feature_list.json     # canonical state: features, status, deps, epics
    ├── init.sh               # tiered verification (fast / --full); self-tunes per project
    ├── CHECKPOINTS.md        # objective done-criteria
    ├── roadmap.md            # narrative: how initiatives split into features
    ├── prompts/
    │   ├── decisions.template.md
    │   └── roles/            # planner · discussion · spec_author · implementer · reviewer
    ├── progress/
    │   ├── current.md        # active session (small; read first)
    │   └── history.md        # append-only log of closed features
    └── specs/<id>-<name>/    # one folder per feature (created as you go)
```

## Concepts

- **Feature states:** `pending → discussed → spec_ready → in_progress → implemented →
  done`, plus `blocked` / `deferred` (with a recorded reason). At most one feature is
  `in_progress` at a time.
- **Locked decisions** (`decisions.md`): a `| # | Topic | Decision | Rationale |`
  table the discussion phase produces with you. The spec and code trace back to it.
- **EARS requirements:** every requirement uses Easy Approach to Requirements Syntax
  ("When `<trigger>`, the system shall `<response>`") and a stable label `R1, R2, …`.
- **Stable task IDs:** `FR-0001-T3` — referenced in `tasks.md` and commit messages,
  never renumbered.
- **TDD:** the implementer writes a failing test before the code for each task; the
  reviewer adds edge/negative/boundary tests. A feature can't reach `done` with a red
  suite.
- **Tiered verification** (`blinder/init.sh`): the fast tier (structural checks +
  `feature_list.json` validity + dependency graph sanity + compile/typecheck) runs on
  the edit hook; `--full` additionally runs the test suite at the review gate.

## Token efficiency

Baked into the prompts and tooling:

1. **Subagents isolate heavy work** in contexts that are discarded on return.
2. **Progressive disclosure** — `AGENTS.md` is a map; each role reads only what it needs.
3. **Decision-only Leader** — short messages; files referenced by `path:line`, not pasted.
4. **Tiered checks** — cheap compile/typecheck on every edit; the full suite only at review.
5. **Locked decisions + EARS** — dense, scannable artifacts that prevent re-litigation.
6. **One feature at a time** — keeps the working set small.

## This repository

```
blinder/
├── README.md            # this file
├── MANUAL.md            # full user manual
├── scripts/blinder.sh   # the CLI (init / new / status / next)
└── templates/           # everything copied into a scaffolded project
    ├── init.sh
    ├── config/          # feature_list.json, claude_settings.json
    ├── docs/            # CLAUDE.md, AGENTS.md, specs.md, CHECKPOINTS.md, stubs, decisions tmpl
    ├── progress/        # current.md, history.md, roadmap.md
    ├── prompts/roles/   # the 5 role prompts (single source of truth)
    └── install/         # install_agents.sh (assembles .claude/agents)
```

The role prompts in `templates/prompts/roles/` are the single source of truth.
`install_agents.sh` copies the three subagent prompts into a project's
`.claude/agents/` and mirrors all five into `blinder/prompts/roles/` for reference.

## Extending: Skills & MCP

Blinder deliberately **does not** manage [Skills](https://docs.claude.com/en/docs/claude-code/skills)
or [MCP](https://modelcontextprotocol.io) servers — Claude Code already does, and
needs vary per project. Add them yourself:

- **Skills:** create `.claude/skills/<name>/SKILL.md` in your project to teach the
  agents project-specific procedures (running migrations, deploying, etc.).
- **MCP:** add `.mcp.json` (or configure via Claude Code) to expose external
  tools/data; reference those tools from your role prompts or `conventions.md`.

These are orthogonal to the SDD loop — you're just giving the agents more
capabilities. See [MANUAL.md §10](./MANUAL.md).

## FAQ

**Is this an autonomous agent loop?** No. The human gates (discussion + approval)
are where quality comes from; Blinder keeps Claude Code *in* the loop, not out of it.

**Why on-disk state instead of in-session task tracking?** Disk survives cold
restarts — the whole point is resumability. `feature_list.json` + `tasks.md` are
canonical.

**Does it work with other agent CLIs?** It's optimized for Claude Code (the
discussion phase relies on its native question mechanism), but `AGENTS.md` and the
role prompts are plain Markdown another tool can read.

## Prior art

Blinder draws on ideas from [AWS Kiro](https://kiro.dev),
[GitHub Spec Kit](https://github.com/github/spec-kit), the BMAD method, and the
[EARS](https://alistairmavin.com/ears/) requirements notation — combined with a
discussion-first, decisions-as-contract approach distilled from a large real-world
project.

## Contributing

Issues and PRs welcome. Because the project is shell + Markdown:

- Keep `scripts/blinder.sh` and `templates/init.sh` POSIX-bash friendly; run
  `bash -n` on them before committing.
- Validate any JSON template with `jq empty`.
- Sanity-check end to end: `blinder init` into a throwaway dir, then `blinder new`,
  `blinder status`, `blinder next`, and `bash blinder/init.sh --full`.

## License

[MIT](./LICENSE) © Eudy Veras.
