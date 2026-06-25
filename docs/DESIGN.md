# Design decisions & rationale

> Why Blinder is shaped the way it is — including alternatives we rejected. The code
> shows *what*; this shows *why*. Newest decisions are roughly at the bottom; each is a
> point-in-time record (not maintained as live truth). The change history is `git log`.

Blinder distills a method proven across a large real project (a long upfront LLM design
chat → split into docs → built phase-by-phase, with per-phase Q&A capturing decisions).
v3 rebuilt it Claude-native.

---

## D1 — Scaffold, not runtime

Blinder writes prompts/state/hooks; it does **not** call LLM APIs or run an autonomous
loop. **Why:** reliability and quality come from human gates + native agent
orchestration, not a self-driving bash loop. The old `AI_HARNESS_V2_SPEC.md`
autonomous-loop ambition was removed.

## D2 — Claude Code only

Dropped the dual Claude+Antigravity compilation. **Why:** to fully use native
mechanisms — `AskUserQuestion` (discussion), real subagents, editor hooks. `AGENTS.md`
+ role prompts stay plain Markdown so another agent CLI can still read the repo.

## D3 — Main-thread vs subagent split

The **Leader** (main thread) runs planning, discussion, and the approval gate, because
those need to talk to the human (`AskUserQuestion` can't be used from a subagent). Spec
authoring, implementation, and review run as **subagents**. **Why:** subagent contexts
are discarded on return, so heavy reading/editing stays out of the Leader's context —
the single biggest token lever.

## D4 — Discussion phase, then auto-flow to spec

A `pending` feature first goes through **discussion**: the Leader asks questions via
`AskUserQuestion` and records a `decisions.md` "locked decisions" table *before* any
spec. Then it **continues automatically** into spec authoring — no separate "say spec"
step. **Why:** ambiguity dies before code (the highest-value step); and the discussion
Q&A is already the human's first touchpoint, so a second pause was redundant friction.
Two human touchpoints per feature: discussion + spec approval.

## D5 — Planner (macro decomposition)

A main-thread **Planner** turns a big idea into a *thin* set of features (title,
one-line description, epic, dependencies) and inserts them via the CLI. **Why:** matches
how real work starts (a design chat → many phases). It stays thin on purpose — it
decides *what* the features are, not *how* they're built; per-feature decisions are
locked later, when each is picked up (locking everything up front is the big-bang trap).
Re-runnable; appends; never renumbers (stable IDs are sacred).

## D6 — `spec_author` owns the tests (option C)

The agent that writes the spec also writes the **failing test suite**; the implementer
only makes it pass. **Alternatives considered:**
- **A — implementer writes tests (classic TDD):** rejected because it couples the
  test-author and code-author (tests and code can be wrong in the same direction), and
  it blocks using a cheaper implementer.
- **B — a separate `test_author` agent:** rejected because it adds an agent + an extra
  cold-start, and risks signature drift between the test-author's and implementer's
  contexts.
- **C — fold tests into `spec_author` (chosen):** keeps the oracle independent
  (test-author ≠ code-author), reuses the context that already defined the requirements
  and signatures (no extra cold-start, no drift), makes the tests part of what the human
  approves, and needs no new state. The reviewer then **audits code vs spec directly**
  (green tests are an input, not the verdict).

## D7 — Model (and effort) tiering

Enabled by D6: strong model for **discussion / spec_author / reviewer** (judgment),
mid model for the **implementer** (mechanical — make pre-written tests pass). **Why:**
implementation is the highest-token phase, so making it the cheap one concentrates the
savings, and it's safe because it's bracketed by two strong correctness gates. Set per
subagent via `model:` frontmatter; main-thread roles use the session model.

The role prompts now **ship these defaults** rather than leaving the frontmatter blank
(blank inherited the session model, so everything silently ran as one tier): `opus` for
`spec_author`/`reviewer`, `sonnet` for `implementer`. The same axis extends to reasoning
**effort** via the `effort:` frontmatter field (`low`…`max`): `spec_author`/`reviewer`
default to `high`. The implementer ships `model:` but no `effort:` — `xhigh`/`max` are
Opus-class levels and would clamp on Sonnet, so raising implementer effort means moving
it to `opus` first. These files are harness-owned (refreshed by `upgrade`), so per-project
tuning must be re-applied after an upgrade.

## D8 — Three right-sized lanes (feature / fix / chore)

Not every change deserves the full cycle.
- **feature** — full loop.
- **fix** (`new --type fix --fixes FR-X`) — skips discussion; `spec_author` writes a
  short `fix.md` + a failing **regression test**; implementer passes it; reviewer audits.
- **chore** (`cli.sh log "…"`) — a known, localized, non-behavioral edit the **Leader
  makes directly** and logs; no tracked unit, no subagent.

The Leader classifies each request (asking when borderline). **Why leader-does-chores:**
dispatching a subagent for a one-liner means a cold-start + permanent context pollution
on the expensive model; for a genuinely tiny edit that's pure waste. **Guardrail:** if a
"chore" needs investigation or touches logic, it isn't a chore — it's a fix/feature and
gets dispatched. One ledger; lane is a `type` field, not a separate system.

## D9 — Vendored CLI (`blinder/cli.sh`), separate from `init.sh`

`init` copies the CLI into each project as `blinder/cli.sh`. **Why:** agents run
non-interactively, where a shell alias isn't loaded, and a scaffolded project has no
access to the source repo — so feature management must work via a relative path.
`init.sh` is kept **separate** because it's project-owned and tuned (see D12), whereas
`cli.sh` is a disposable snapshot refreshed on upgrade.

## D10 — `set` for safe status transitions

`cli.sh set <id> <status>` validates the value, enforces one `in_progress`, bumps
`updated`, sets/clears `blocked_reason`. **Why:** dogfooding showed an agent *inventing*
`cli set … status` and, finding nothing, hand-editing `feature_list.json` — fragile
(caught only after the fact). An agent improvising around a missing capability is a
feature request. Transitions are permissive on order (allow corrections/re-opens).

## D11 — `roadmap.md` is generated, not maintained

`feature_list.json` is the single source of truth; `roadmap.md` is a board *projected*
from it (`cli.sh roadmap`, auto on `new`/`set`). **Why:** a hand-maintained narrative
duplicated the data and drifted. The board is the committable/GitHub-browsable view;
`status` is the terminal view; both derive from one source.

## D12 — Docs model: records vs. living vs. generated

The source of truth is **code + tests + `blinder/specs/` + `feature_list.json`** — never
a doc. Docs are:
- **Records** (append-only, never drift): per-feature `specs/`, `history.md`, git.
- **Generated projections** (regenerate, don't maintain): `roadmap.md`.
- **Seeds & snapshots** (root `docs/`, the user's space): design inputs persisted from a
  chat, or on-demand docs ("describe the payment flow") generated from current reality.
  Neither is maintained; a provenance header states role + as-of date.

We rejected a "living per-area reference doc maintained every feature + a checkpoint"
approach: it fights drift instead of sidestepping it, and adds per-feature overhead.
Harness reference docs live in **`blinder/docs/`** (architecture, conventions, specs,
CHECKPOINTS); root **`docs/`** is the user's space. **Why the split:** clean invariant —
*everything Blinder owns lives under `blinder/`*; root `docs/` is unambiguously yours.

## D13 — `verify.env` + `blinder upgrade`

Build/test tuning (`PROJECT_COMPILE_CMD`/`PROJECT_TEST_CMD`) lives in project-owned
`blinder/verify.env`, which `init.sh` sources. **Why:** it converts `init.sh` from a file
that's *both* framework and config (so overwriting it loses tuning — a trap we hit) into
a refreshable harness-owned script + a tiny config that upgrade never touches.
`blinder upgrade` then refreshes the harness-owned set, preserves the project-owned set,
regenerates the board, and stamps `blinder/.version`. Gated on a clean git tree (the
undo); `--dry-run` previews. Schema changes stay additive so no data migration is needed.

## D14 — Not self-hosted

Blinder does **not** run its own harness on itself. **Why:** (1) it's bash + Markdown,
and the SDD loop assumes app code with a test runner — poor fit without first adding a
shell test suite; (2) a live instance at the repo root would collide visually with the
`templates/` sources and confuse GitHub visitors. Dogfooding happens via a separate
throwaway project, which captures the value without the confusion. Revisit only with a
real test suite + clear separation + a README note (see `docs/BACKLOG.md`).

## D15 — Optional cross-model reviewer (Codex)

The reviewer can run a **second, independent code-vs-spec audit with a different model**
(Codex, via the standalone `codex` CLI), gated on `REVIEWER_CODEX=1` in the project-owned
`blinder/verify.env`. It is purely additive: the Blinder `reviewer` subagent stays the
orchestrator and owner of the verdict, test-hardening, full verification, CHECKPOINTS,
and state transitions; Codex's findings are *input* it reconciles, not the decision.

**Why:** a different model widens the audit's blind spots — a natural extension of D6
(the oracle should be independent of the code author) and D7 (model tiering) *across
vendors*. **Why the standalone `codex exec` CLI, inside the subagent — not the
`/codex:review` slash command** (the latter is what the `codex-plugin-cc` Claude Code
plugin provides; we use the underlying CLI directly and do **not** depend on that
plugin): (1) plugin slash commands run only on the **main thread**, so a subagent can't
invoke one at all — and routing the review through the Leader would defeat D3 (subagent
contexts are discarded — the whole point of making review a subagent); shelling out to
`codex exec` via Bash keeps it inside the disposable reviewer context. (2) Plain
`/codex:review` is diff-only, read-only, and takes no custom instructions, so it can't
follow the spec or write the verdict — a CLI prompt **pointed at
`requirements.md`/`decisions.md`/`design.md`** makes it spec-aware. **Why opt-in/off by default:** Blinder is otherwise bash + jq + Claude
Code with zero runtime; Codex adds an external dependency (Node 18.18+, ChatGPT sub or
OpenAI key). When the toggle is unset or `codex` isn't on PATH, the reviewer skips the
pass silently — no behavior change, no new requirement for existing projects.

## D16 — Multi-agent targets (Claude Code + OpenCode)

One Blinder project can be driven by Claude Code, OpenCode, or both, selected at
`init --agent claude|opencode|both` (default `claude`) and persisted in `blinder/.agents`
(a missing file ⇒ `claude`, so every pre-existing project is unaffected). This **relaxes
D2** ("Claude Code only") for a second concrete target without reopening the general
multi-tool compilation that D2 rejected.

**Why generate-from-one-source over fork-per-tool:** the CLI, verifier, state, specs/docs,
and role-prompt *bodies* are already tool-agnostic; only the agent frontmatter, the verify
hook, and the entrypoint doc differ. So we generate that thin shell per target and never
duplicate the tree (a forked tree drifts). The Claude-style role prompts stay **canonical**;
an `awk` emitter in `install_agents.sh` transforms them for OpenCode — dropping `name:`
(OpenCode derives the id from the filename) and `model:`/`effort:`, injecting
`mode: subagent`, and mapping the Claude `tools:` allowlist into a `permission:` block (the
modern OpenCode field; `tools:` is deprecated). Leader instructions moved to a shared
`blinder/docs/leader.md` that `CLAUDE.md` `@`-imports and `opencode.json` lists in
`instructions` (OpenCode doesn't auto-follow Markdown refs, so it must be the config array).
`AGENTS.md` stays the always-loaded shared map.

**Why no model/effort/temperature on OpenCode:** OpenCode is multi-provider (the user may
run OpenAI there), so pinning per-role models would hardcode provider slugs and drop
`effort` regardless — instead OpenCode agents inherit the user's configured model (set in
the project-owned `opencode.json`), which makes **model tiering (D7) a Claude-only feature
for now** (documented, with a manual per-`.opencode/agents/*.md` override and a backlog path
to map the implementer to OpenCode's `small_model`). This deletes the biggest implementation
risk (a provider/model slug table).

**Why graceful degradation for questions:** OpenCode's structured question tool isn't
uniformly exposed, so the discussion/approval invariant is "ask the human before any spec,"
satisfied by a structured question tool when present and plain conversation otherwise.

**Verification hook parity:** the Claude `PostToolUse` hook and an OpenCode plugin
(`.opencode/plugins/blinder-verify.ts`, `tool.execute.after`) both just run
`bash blinder/init.sh` — the verifier's *content* stays in one place. The plugin needs the
Bun runtime, but **OpenCode bundles it** (validated against OpenCode 1.17.9: the plugin
loads with no separate `bun` install), so the Claude path's zero-runtime promise is
preserved and OpenCode adds no extra system dependency beyond OpenCode itself.

**`upgrade --agent` is union / add-only:** it can grow the target set but never silently
delete a working shell; `opencode.json` is preserved on upgrade like `.claude/settings.json`
(it's where the user sets their model). Removing/switching a target is a deliberate manual
step (reversible via git); an explicit `--only`/`--replace` flag is deferred to the backlog.
