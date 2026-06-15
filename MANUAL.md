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
- **Tests as an independent oracle.** `spec_author` writes the failing test suite
  *with* the spec (before approval); the `implementer` only makes those tests pass
  and never edits them; the `reviewer` audits the code against the spec and adds
  more tests. Test-author ≠ code-author, so green means something.
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
  → [SPEC · spec_author]    requirements.md (EARS) + design.md + tasks.md + failing tests
  → spec_ready
  → ⏸ YOU APPROVE (spec + tests)
  → in_progress
  → [IMPLEMENT · implementer]  per task: run its tests → code → green (tests read-only)
  → implemented
  → [REVIEW · reviewer]     audit code vs spec + harden tests + full suite
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
$EDITOR blinder/docs/architecture.md blinder/docs/conventions.md

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
├── docs/                     # YOURS: seeds + on-demand snapshots (not maintained)
│   └── README.md             # what this folder is for
├── .claude/
│   ├── settings.json         # PostToolUse hook → fast verification
│   └── agents/               # spec_author, implementer, reviewer subagents
└── blinder/
    ├── docs/                 # harness reference (agents read these)
    │   ├── architecture.md   # YOU fill this in
    │   ├── conventions.md    # YOU fill this in
    │   ├── specs.md          # the SDD process reference
    │   └── CHECKPOINTS.md    # objective done-criteria
    ├── feature_list.json     # state: features, status, deps
    ├── cli.sh                # vendored CLI (new/set/log/status/next/roadmap)
    ├── init.sh               # tiered verification (fast / --full); project-owned, self-tunes
    ├── roadmap.md            # GENERATED board of feature_list.json (cli.sh roadmap)
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
| `bash blinder/cli.sh new "title" [opts]` | Register a tracked unit; assigns `FR-XXXX`. `--type fix --fixes FR-X` marks a fix linked to what it repairs. |
| `bash blinder/cli.sh set <id> <status> [--reason "…"]` | Transition a feature's status — validates the value, enforces one `in_progress`, bumps `updated`, sets/clears `blocked_reason`. Agents use this for every phase change instead of editing the JSON. |
| `bash blinder/cli.sh log "message"` | Append a one-line entry to `history.md` for a **chore** — a change too small to be a tracked unit. No unit, no cycle. |
| `bash blinder/cli.sh status` | Dashboard: id, status, sdd, deps, title (+ blocked reasons), grouped by epic. |
| `bash blinder/cli.sh next` | Print the next actionable feature (dependencies satisfied). |
| `bash blinder/cli.sh roadmap` | Regenerate `blinder/roadmap.md` — a committable, GitHub-browsable board derived from `feature_list.json` (also auto-regenerated by `new`/`set`). |
| `bash blinder/cli.sh help` | Usage. |

`new` options: `--description "..."`, `--acceptance "a, b, c"`,
`--depends-on "FR-0001,FR-0002"`, `--epic "name"` (group related features),
`--type fix --fixes "FR-0001"` (mark a fix linked to what it repairs), `--no-sdd`.
With a TTY and no flags, `new` prompts you for description and acceptance.

---

## 6.4. Three lanes: feature, fix, chore

Not every change deserves the full cycle. The Leader **classifies** each request and
right-sizes the process (asking you when it's borderline):

| Lane | When | What happens |
|------|------|--------------|
| **Feature** | net-new behavior, design choices | the full loop (§7) |
| **Fix** | something `done` is broken | `bash blinder/cli.sh new "…" --type fix --fixes FR-X` → **skips discussion** → `spec_author` writes `fix.md` + a **failing regression test** → you approve → implement → review |
| **Chore** | no behavior change, a known + localized edit (typo, rename, docs, config) | the **Leader edits it directly**, runs the fast check, and records it with `bash blinder/cli.sh log "…"` — no tracked unit, no subagent |

The line for a chore: the Leader can only do it directly if it doesn't need to go
read the codebase and doesn't touch logic. The moment it would — it's a fix or a
feature, and gets dispatched (so the file-reading happens in a disposable subagent
context, not the Leader's). Fixes stay test-first: the regression test reproduces the
bug, then the implementer makes it pass.

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
4. It inserts each feature with `bash blinder/cli.sh new` (wiring `--depends-on`,
   `--epic`, and a `--description` one-liner). The `blinder/roadmap.md` board
   regenerates automatically — the Planner doesn't hand-write it.

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
   recommended default). Answer them; it writes `decisions.md` and **continues
   automatically** to the spec — no extra "say spec" step.
3. **Spec.** `spec_author` writes `requirements.md`, `design.md`, `tasks.md`, **and
   the failing test suite**; the Leader presents it all, stopping at `spec_ready`.
4. **Approve.** Read the spec **and the tests** — the tests are part of the contract.
   Say **"approved"** → the Leader flips it to `in_progress`. Or ask for changes (see
   below).
5. **Implement.** The `implementer` makes the pre-written tests pass task by task
   (never editing them), runs the full suite, and sets `implemented`.
6. **Review.** The `reviewer` **audits the code against each requirement** (not just
   that tests are green), adds edge-case tests, runs `init.sh --full`, and writes
   `review.md`. If approved → `done` and appended to `history.md`; if rejected → back
   to the implementer with notes.

So per feature there are **two human touchpoints**: the discussion Q&A and the spec
approval. You can stop after any phase and resume later — state is on disk.

### Changing a spec at the approval gate

At `spec_ready`, don't say "approved" — just tell the Leader what you want, and it
routes by depth (keeping `decisions.md → requirements → tasks` in sync). **Let the
Leader make the edits** rather than hand-editing the spec files:

- **Spec tweak** (a requirement is off, a task is missing) and the decisions still
  hold → the Leader has `spec_author` revise the spec in place; it stays
  `spec_ready` and re-presents.
- **A decision was wrong** (the approach should change) → say e.g. *"revisit D2 —
  make storage file-based."* The Leader amends `decisions.md` (re-asking questions
  if needed), then `spec_author` redrafts from it.
- **Just want to talk it through** → discuss in chat; nothing changes until you ask
  for an edit.

Nothing advances to implementation until you approve the current spec.

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

## 8.5. Model tiering (optional, advanced)

The roles split by how much **judgment** they need, which lets you spend a strong
model where it matters and a cheaper one where the work is mechanical:

| Role | Judgment | Suggested model |
|------|----------|-----------------|
| leader / discussion / planner (main thread) | high (ambiguity, questions, routing) | **strong** |
| spec_author (requirements + design + **tests**) | high (defines correctness) | **strong** |
| reviewer (audits code vs spec) | high (correctness judgment) | **strong** |
| implementer (make the pre-written tests pass) | low (mechanical execution) | **mid** |

This is why the test/implement split exists: with `spec_author` (strong) authoring
the tests and the `reviewer` (strong) auditing the code, the **implementer can be a
cheaper model** and still be safe — it's bracketed by two strong correctness gates,
and implementation is usually the highest-token phase, so that's where the savings
concentrate.

How to set it:

- **Main-thread roles** (leader/discussion/planner) use whatever model you launched
  the Claude Code session with — launch with the strong one.
- **Subagents** take a `model:` line in their frontmatter at `.claude/agents/<role>.md`
  (e.g. `model: sonnet`). Set `spec_author` and `reviewer` to a strong model and
  `implementer` to a mid one; omit the line to inherit the session model.

Cautions: don't pick the *weakest* model for the implementer (it still writes real
logic and must match `design.md` signatures), and watch for repeated review
rejections on a feature — that's the signal the implementer is under-resourced for
that work and the rework loop is costing more than a better model would.

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
