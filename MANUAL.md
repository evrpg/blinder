# Blinder Manual

Blinder is a **scaffolding system** that imprints a disciplined, spec-driven
development (SDD) workflow onto a project and lets **Claude Code** drive it using
its native multi-agent features. It is **not a runtime** — it does not call any
LLM API or run an autonomous loop. It writes files (prompts, state, hooks) that
make Claude Code orchestrate itself reliably.

It distills a method proven across a large real project: lock decisions before
coding, write specs as contracts, track progress on disk so work survives
interruptions, and verify with tests — while keeping token use low.

---

## 1. Core ideas

- **Scaffold, not runtime.** Blinder generates configuration; Claude Code does the work.
- **Spec-driven.** Discussion → spec → approval → implementation → review. No code
  before the spec is approved.
- **Decisions are the contract.** A discussion phase resolves ambiguity with you
  *before* anything is written, recorded as a Locked Decisions table.
- **TDD.** A failing test is written before the code that passes it; the reviewer
  adds edge-case tests after.
- **State lives on disk.** `blinder/feature_list.json` + per-feature spec files are
  the source of truth, so any session can resume exactly where the last stopped.
- **Token-frugal by design** (see §8).

---

## 2. The two-actor model (important)

Some phases must talk to you; some shouldn't pollute the main context.

| Phase | Where it runs | Why |
|-------|---------------|-----|
| **Planning** (macro) | Leader, **main thread** | Splits a big idea into features by chatting with you |
| **Discussion** (micro) | Leader, **main thread** | Uses `AskUserQuestion` — only the main conversation can ask you |
| **Approval gate** | Leader, **main thread** | You approve here |
| **Spec authoring** | **Subagent** | No user interaction needed |
| **Implementation** | **Subagent** | Heavy edits in a context that's discarded on return |
| **Review** | **Subagent** | Read/verify in a discarded context |

The Leader is just Claude Code running under `CLAUDE.md`. Subagents are dispatched
with the `Agent` tool and defined in `.claude/agents/`.

---

## 3. Lifecycle

Two altitudes. **Planning** (macro) is optional and turns a big idea into many
features; the **per-feature loop** (micro) then runs on each one.

```
(big idea / many ideas)
  → [PLANNING · Leader]     split into features → YOU APPROVE → inserted as pending

pending
  → [DISCUSSION · Leader]   ask questions → write decisions.md
  → discussed
  → [SPEC · spec_author]    requirements.md (EARS) + design.md + tasks.md
  → spec_ready
  → ⏸ YOU APPROVE
  → in_progress
  → [IMPLEMENT · implementer]  per task: failing test → code → green
  → implemented
  → [REVIEW · reviewer]     traceability + add edge tests + full suite
  → done
```

`blocked` and `deferred` are reachable from any state, with a recorded reason.

---

## 4. Install & quickstart

Blinder needs `git`, `bash`, and `jq`.

```bash
# 1. New project dir + git (git is required by Claude Code for diffs)
mkdir my-app && cd my-app && git init

# 2. Scaffold the harness (use the absolute path, or set an alias)
/path/to/blinder/scripts/blinder.sh init --name "my-app"

# 3. Fill in the project docs the agents read
$EDITOR docs/architecture.md docs/conventions.md

# 4. Baseline commit
git add . && git commit -m "chore: scaffold blinder harness"

# 5. Register your first feature — in-project, use the vendored CLI
bash blinder/cli.sh new "User login"

# 6. Open Claude Code and say:
#    "Work the next pending feature."
```

Convenience alias — only needed to **bootstrap** new projects (`init`); inside a
project everything runs via `bash blinder/cli.sh …`:

```bash
alias blinder="/path/to/blinder/scripts/blinder.sh"
```

---

## 5. What gets scaffolded

```
my-app/
├── CLAUDE.md                 # Leader instructions (loaded every session)
├── AGENTS.md                 # Navigation map for agents
├── docs/
│   ├── architecture.md       # YOU fill this in
│   ├── conventions.md        # YOU fill this in
│   └── specs.md              # the SDD process reference
├── .claude/
│   ├── settings.json         # PostToolUse hook → fast verification
│   └── agents/               # spec_author, implementer, reviewer subagents
└── blinder/
    ├── feature_list.json     # state: features, status, deps
    ├── cli.sh                # vendored CLI (new/status/next) — runs in-project, no alias needed
    ├── init.sh               # tiered verification (fast / --full); project-owned, self-tunes
    ├── CHECKPOINTS.md         # done-criteria
    ├── roadmap.md            # narrative: how initiatives split into features
    ├── prompts/
    │   ├── decisions.template.md
    │   └── roles/            # planner, discussion, spec_author, implementer, reviewer
    ├── progress/
    │   ├── current.md        # active session (small, read first)
    │   └── history.md        # append-only log of closed features
    └── specs/<id>-<name>/    # one folder per feature (created as you go)
```

---

## 6. CLI reference

Two ways to reach the CLI:

- **Bootstrapping a new project** — `init` needs the source repo, so use its path or
  an alias: `blinder init …` (see [Install](#4-install--quickstart)).
- **Inside a scaffolded project** — `init` vendors a copy to `blinder/cli.sh`, so use
  **`bash blinder/cli.sh <cmd>`**. This needs no alias and works for agents running
  non-interactively (which is exactly why the Planner relies on it).

| Command | What it does |
|---------|--------------|
| `blinder init [--name N]` | Scaffold the harness into the current dir (source CLI only). |
| `bash blinder/cli.sh new "title" [opts]` | Register a feature; assigns `FR-XXXX`. |
| `bash blinder/cli.sh status` | Dashboard: id, status, sdd, deps, title (+ blocked reasons), grouped by epic. |
| `bash blinder/cli.sh next` | Print the next actionable feature (dependencies satisfied). |
| `bash blinder/cli.sh help` | Usage. |

`new` options: `--description "..."`, `--acceptance "a, b, c"`,
`--depends-on "FR-0001,FR-0002"`, `--epic "name"` (group related features),
`--no-sdd` (skip the SDD flow for a trivial chore). With a TTY and no flags, `new`
prompts you for description and acceptance. The **Planner** (§6.5) calls `new` for
you when you bring a big idea.

---

## 6.5. Planning a big initiative (optional macro step)

When you have a large idea, or a pile of ideas, you don't have to register features
one by one. Tell the Leader *"plan: &lt;your brain-dump&gt;"* and it runs the
**Planner**:

1. It restates the initiative and asks a few **scope-level** questions (boundaries,
   must-haves vs. later, rough sequencing) — not implementation detail.
2. It proposes a **thin breakdown**: a list of features, each with a title,
   one-line description, an `epic`, dependencies, and why it's its own feature.
3. You approve / edit / reorder / drop / add. **Nothing is inserted until you agree.**
4. It inserts each feature with `blinder.sh new` (wiring `--depends-on` and
   `--epic`) and records the mapping in `blinder/roadmap.md`.

Then the normal per-feature loop (§7) runs on each feature. Two things to know:

- The Planner stays **thin** on purpose — it decides *what* the features are and
  their order, **not how they're built**. Each feature's real decisions are locked
  later, in its own discussion phase, when it's picked up. (Deciding everything up
  front is the big-bang-planning trap and wastes tokens.)
- Re-run the Planner any time to **add** features to an existing plan. It appends
  and never renumbers — feature IDs are stable forever.

A big initiative is therefore just **an epic-tagged chain of features** linked by
`depends_on`. `blinder status` groups the dashboard by epic, and
`blinder/init.sh` verifies the dependency graph references real IDs and has no
cycles.

## 7. Working a feature with Claude Code

1. **Start.** Tell the Leader *"work the next pending feature"* (or name an ID). It
   reads `current.md` + the feature entry.
2. **Discussion.** The Leader asks you a few batched questions (each with a
   recommended default). Answer them; it writes `decisions.md` and stops.
3. **Spec.** Say *"spec it."* The Leader dispatches `spec_author`, which writes
   `requirements.md`, `design.md`, `tasks.md`, then stops at `spec_ready`.
4. **Approve.** Read the spec. Say **"approved"** (or request changes). The Leader
   flips the feature to `in_progress`.
5. **Implement.** The `implementer` does red-green TDD task by task, then runs the
   full suite and sets `implemented`.
6. **Review.** The `reviewer` checks every requirement has a test, adds edge-case
   tests, runs `init.sh --full`, and writes `review.md`. If approved → `done` and
   appended to `history.md`; if rejected → back to the implementer with notes.

You can stop after any phase and resume later — state is on disk.

---

## 8. Token-saving techniques (built in)

These are baked into the prompts and tooling; good to know so you don't undo them:

1. **Subagents isolate heavy work.** Spec/implement/review run in contexts that are
   thrown away on return, so the Leader's conversation stays small. This is the
   biggest lever — let the Leader delegate rather than doing the work itself.
2. **Progressive disclosure.** `AGENTS.md` is a map; each role reads only the files
   it needs. Don't paste whole files into chat — reference `path:line`.
3. **Decision-only Leader.** Keep the Leader's messages short.
4. **Tiered verification.** The edit-time hook runs the *fast* `init.sh`
   (compile/typecheck, seconds). The full test suite runs only at the review gate
   via `init.sh --full`. Don't change the hook to `--full`.
5. **Locked decisions + EARS.** Dense, scannable artifacts that prevent
   re-explaining the same thing — re-litigation is where tokens are wasted.
6. **One feature at a time.** Keeps the working set small.

---

## 9. Verification harness (`blinder/init.sh`)

- `bash blinder/init.sh` — **fast**: structural file checks, `feature_list.json`
  validity, at-most-one `in_progress`, status-enum check, and compile/typecheck for
  the detected stack (`tsc --noEmit`, `cargo check`, `go build`, `gradle compile`,
  `ruff`/`compileall`). This is the `PostToolUse` hook.
- `bash blinder/init.sh --full` — fast checks **plus** the full test suite (`npm
  test`, `pytest`/`unittest`, `cargo test`, `go test`, `gradle test`).

**Make it exact per project.** Auto-detection is a generic default. Once you know
the real commands for *this* project, set them at the top of `blinder/init.sh`:

```bash
PROJECT_COMPILE_CMD="./gradlew compileKotlin -q"   # fast tier
PROJECT_TEST_CMD="./gradlew test -q"               # --full only
```

When set, a command **overrides all auto-detection** for that tier — the check
becomes precise and fast instead of guessed. The `init.sh` lives inside each
project, so it is yours to evolve, and the `implementer`/`reviewer` roles are told
to fill these in when they discover the true commands — so the harness sharpens
itself the more you use Blinder.

---

## 10. Extending a project: Skills and MCP (out of Blinder's scope)

Blinder deliberately does **not** manage Skills or MCP servers — Claude Code already
does, and per-project needs vary. Add them yourself:

**Project Skills** — create `.claude/skills/<name>/SKILL.md` in your project (a skill
is a folder with a `SKILL.md` describing when/how to use it; Claude Code discovers it
automatically). Use skills to teach the agents project-specific procedures (e.g. "how
to run a DB migration", "how to deploy to staging").

**MCP servers** — add a `.mcp.json` at the project root (or configure via Claude
Code's MCP settings) to expose external tools/data (databases, issue trackers,
browsers) to the agents. Reference those tools from your role prompts or
`conventions.md` if a phase should use them.

Keep these orthogonal to the harness: the SDD lifecycle doesn't change, you're just
giving the agents more capabilities.

---

## 11. Troubleshooting

| Symptom | Fix |
|---------|-----|
| Hook is noisy / slow on every edit | Ensure `.claude/settings.json` runs `blinder/init.sh` **without** `--full`. The full suite belongs at the review gate. |
| `init.sh` skips compile | No toolchain detected — add your stack to the §9 detection blocks. |
| Feature stuck in `in_progress` across sessions | Read `blinder/progress/current.md`; the Leader resumes from there. |
| Two features `in_progress` | Violates `one_feature_at_a_time`; `init.sh` fails. Set one back to `pending`/`blocked`. |
| Agent guessed instead of asking | The discussion phase exists to prevent this — make sure the feature passed through `discussed` with a real `decisions.md` before spec/implementation. |
| `jq: command not found` | Install `jq`; the CLI and `init.sh` need it. |

---

## 12. Design notes / FAQ

- **Why no autonomous loop?** Self-driving bash loops are brittle and burn tokens on
  this kind of work; the human gates (discussion + approval) are where quality comes
  from. Blinder keeps Claude Code in the loop, not out of it.
- **Why disk state instead of the harness Task tools?** Task tools are great within a
  session, but disk state survives cold restarts — the whole point is resumability.
  Agents may use Task tools as a scratchpad, but `feature_list.json` + `tasks.md` are
  canonical.
- **Why Claude-only?** To fully exploit native mechanisms (`AskUserQuestion`, plan
  mode, real subagents). `AGENTS.md` stays generic so another CLI can read the repo,
  but the discussion phase specifically relies on Claude Code.
