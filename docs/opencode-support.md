# Plan: multi-agent target support (Claude Code + OpenCode)

> Status: **planned, not started.** This is the agreed design for letting one Blinder
> project be driven by Claude Code, OpenCode, or both. Companion to `DESIGN.md` (see the
> proposed **D16** at the bottom). Persist of the discussion that produced it.

## Why

Blinder is already ~80% tool-agnostic: `blinder/cli.sh`, `blinder/init.sh`,
`feature_list.json`, the specs/progress/docs tree, and the **role-prompt bodies** are
plain bash + Markdown. Only a thin shell is Claude-specific — the agent frontmatter, the
verification hook, and the always-loaded entrypoint doc. The goal is to **generate that
thin shell per target from one source**, never fork the template tree per tool.

## Compatibility map

| Concern | Claude Code | OpenCode | Resolution |
|---|---|---|---|
| Instructions file | `CLAUDE.md` (primary) | `AGENTS.md` (primary; `CLAUDE.md` only as fallback) | `AGENTS.md` is the shared map; Leader rules live in a shared `leader.md` both reference |
| Subagent defs | `.claude/agents/*.md` — `name, description, tools, model, effort` | `.opencode/agents/*.md` — `description, mode, model, temperature, permission, steps` | Different dir + schema → **transform** from the Claude-canonical source |
| Model / effort / temperature | pinned per role (`model:`, `effort:`) | many providers; user-configured | **Not pinned on OpenCode** (see Decision 2) — Claude-only feature for v1 |
| Verification hook | `.claude/settings.json` `PostToolUse` runs `bash blinder/init.sh` | no declarative hook — a JS/TS plugin (`.opencode/plugins/`) on the `file.edited` event | ship a small plugin; verification *content* stays in `init.sh` |
| Subagent dispatch | `Agent`/`Task` tool | primary agent auto-delegates or `@mention` | neutral prose names both |
| Interactive Q&A | `AskUserQuestion` | native "question" system exists but exposure is inconsistent (issues #5960, #13752) | **graceful degradation** to plain-chat Q&A |

## Decisions folded in (from discussion)

**D-1 — subagent source of truth: Claude-canonical + transform.** The existing
Claude-style role `.md` stay canonical. `install_agents.sh` gains an OpenCode emitter that
transforms frontmatter. (Rejected: a neutral metadata block → emit both — more upfront
churn for a second target; revisit if a third agent appears.)

**D-2 — Leader instructions live in one shared file.** Extract the orchestration body into
neutral **`blinder/docs/leader.md`**. `CLAUDE.md` shrinks to a banner + `@blinder/docs/leader.md`
import + the "read AGENTS.md at startup" pointer. OpenCode lists `leader.md` in
`opencode.json`'s `instructions` array (OpenCode does **not** auto-follow Markdown
references, so it must be the config array, not a link). `AGENTS.md` stays the
always-loaded map — no rulebook bloat.

**D-3 — no model/effort/temperature defaults on OpenCode.** Because OpenCode is
multi-provider (the user runs OpenAI there), pinning per-role models would force us to
hardcode provider/model slugs and drop `effort` anyway. Instead, OpenCode agents inherit
the user's configured model. Consequence: **model tiering (DESIGN D7) is Claude-only for
v1.** All OpenCode roles run on one model. Documented limitation, with a manual override
escape hatch (`model:` per `.opencode/agents/*.md`) and a backlog path (map implementer to
OpenCode's `small_model`). This deletes the biggest implementation risk (slug tables).

**D-4 — graceful degradation for interactive questions.** Discussion/approval run on the
primary agent (OpenCode's "main thread" equivalent). The invariant is "ask the human
before spec," not a specific widget. Use a structured question tool if available; otherwise
conduct the same Q&A in conversation.

**D-5 — target selection is project state.** `blinder init --agent claude|opencode|both`
(default `claude`; flag style matches `--name`, which is the *project name* — distinct).
Persisted in **`blinder/.agents`** (e.g. `claude` or `claude opencode`). Missing file ⇒
assume `claude` (covers all existing projects, backward-compatible).

**D-6 — `upgrade --agent` is union / add-only.** `upgrade --agent X` means "ensure X is
present," result = `existing ∪ requested`; it never removes a target. A typo can't delete a
working shell. Adding a target later is the documented path:

| Start (`init …`) | Then `upgrade --agent …` | Result |
|---|---|---|
| `--agent opencode` | `--agent both` | `{claude, opencode}` — adds claude |
| `--agent opencode` | `--agent claude` | `{claude, opencode}` — same as both |
| `--agent claude` | `--agent opencode` | `{claude, opencode}` — **adds, does not swap** |
| `--agent claude` | `--agent both` | `{claude, opencode}` |

`init` is declarative (a fresh project): `init --agent opencode` is opencode-only. Only
`upgrade` is union. **Removing/switching a target stays deliberate** — v1: manual (delete
the shell dir + edit `.agents`, reversible via git, documented in MANUAL); future: an
explicit verbose `upgrade --agent X --only`/`--replace` that prints what it deletes
(backlog).

## Implementation phases

Each phase is an independent conventional commit; `main` stays shippable throughout. The
default (no flag) Claude path must remain byte-identical to today at every step.

### Phase 0 — Neutralize tool-coupled prose *(low risk, no behavior change, ship first)*
Files: `templates/prompts/roles/{discussion,planner,implementer,reviewer,spec_author}.md`,
`templates/docs/{specs.md,AGENTS.md}`, and the new `leader.md`.
- `AskUserQuestion` → "your interactive question tool (Claude Code: `AskUserQuestion`;
  OpenCode: the question tool — otherwise ask in conversation)".
- "dispatched with the `Agent` tool" → "dispatch a subagent (Claude Code: `Agent` tool;
  OpenCode: `@`-mention / auto-delegation)".
- Add to the discussion role: if no structured question tool is available, run the same
  Q&A in plain conversation. Valid even if OpenCode is never finished.

### Phase 1 — Extract Leader instructions to a shared file
- New `templates/docs/leader.md` = orchestration body now in `templates/docs/CLAUDE.md`
  (classification, routing table, amend rules, hard rules, lifecycle).
- `CLAUDE.md` shrinks to: harness-owned banner + `@blinder/docs/leader.md` + the
  "read AGENTS.md at startup" pointer.
- Scaffolded layout gains `blinder/docs/leader.md` (harness-owned; add to `upgrade` REFRESH).
- *Verify in impl:* Claude `@path` import resolves a `blinder/`-scoped path; inline-pointer
  fallback ready.

### Phase 2 — Generator + init flag
- `scripts/blinder.sh` `cmd_init`: parse/validate `--agent`, write `blinder/.agents`, pass
  target to `install_agents.sh`, emit the right settings file(s) per target.
- `templates/install/install_agents.sh`: gains `--agent <t>`. `claude` → today's behavior.
  `opencode` → run the transform (Phase 3). `both` → both. Bodies always mirror to
  `blinder/prompts/roles/`.

### Phase 3 — OpenCode emitters
**(a) Subagents** → `.opencode/agents/<role>.md`. Simplified transform (no model table):

| Canonical (Claude) | OpenCode | Rule |
|---|---|---|
| filename / `name:` | filename | `name` drops (filename is the id) |
| `description:` | `description:` | passthrough |
| `tools: Read, Edit, …` | tool-permission mapping | map allow/deny per tool |
| `model:` / `effort:` | — | **drop** (D-3: inherit user's config) |
| — | `mode: subagent` | inject constant |

Implementation: a small `bash`/`awk` frontmatter rewriter (flat `key: value`, no YAML lib).

**(b) Entrypoint config** → `templates/config/opencode.json`:
`"instructions": ["AGENTS.md", "blinder/docs/leader.md"]` + plugin registration. No `agent`
model defaults (D-3).

**(c) Verify hook** → `templates/config/blinder-verify.plugin.ts` → `.opencode/plugins/`,
using `file.edited` (and/or `tool.execute.after`) to run `bash blinder/init.sh` via Bun `$`.

### Phase 4 — `upgrade` awareness
- `cmd_upgrade` reads `blinder/.agents`; refreshes the shared set (incl. `leader.md`)
  always, and the per-target shell (`.claude/*` and/or `.opencode/*`) conditionally.
- Add `leader.md`, OpenCode agents, `opencode.json`, the plugin to REFRESH for projects
  that use them. `verify.env` stays project-owned/untouched (D13).
- `--agent` on `upgrade` = **union/add-only** (D-6). Updates `blinder/.agents`.

### Phase 5 — Docs
- `DESIGN.md`: add **D16 — multi-agent targets** (draft below).
- `MANUAL.md` / `README.md`: document `--agent`; the OpenCode prerequisite (Bun runtime for
  the plugin); the question-tool degradation; and the **limitation** — no
  model/effort/temperature defaults on OpenCode, tiering is Claude-only, with the manual
  per-agent override and the "adding / switching / removing a target" recipes.
- `BACKLOG.md`: park (1) `effort:`/model tiering on OpenCode via `small_model`, (2) the
  explicit `--only`/`--replace` removal flag, (3) generalization to a third agent.

### Phase 6 — Verification
- `bash -n` on all shell; the existing fast smoke test for `claude` must stay identical.
- New smoke: `init --agent opencode` and `--agent both` into throwaway dirs; assert
  `.opencode/agents/*.md` exist with transformed frontmatter (and **no** `model:`/`effort:`),
  `opencode.json` + plugin present, `blinder/.agents` written, and (for `both`) `.claude/*`
  also present. The backlogged `bats` + `shellcheck` suite would formalize this.

## Risks / verify during implementation (not assumed)
1. **OpenCode agent tool-restriction syntax** — `permission` vs a `tools` map; confirm the
   exact field before writing the transform.
2. **OpenCode question tool exposure** — confirm whether agents can call it in the user's
   setup; if not, chat degradation is the contract (already designed in).
3. **Claude `@import` of a `blinder/`-scoped file** — confirm path resolution; inline
   fallback ready.
4. **Plugin runtime** — the OpenCode verify hook needs Bun/TS; document as an OpenCode-only
   prerequisite (the Claude path stays zero-runtime).

> Risk previously #1 (exact anthropic model slugs) is **eliminated** by D-3 — Blinder no
> longer pins OpenCode models.

## Sequencing & reversibility
Phases 0–1 are safe, useful standalone, and improve the Claude-only product (they de-couple
prose and split out `leader.md` with zero behavioral change) — natural first PR. Phases 2–4
light up OpenCode behind the `--agent` flag, so `main` stays shippable at each step.

---

## Proposed DESIGN entry

## D16 — Multi-agent targets (Claude Code + OpenCode)

One Blinder project can be driven by Claude Code, OpenCode, or both, selected at
`init --agent claude|opencode|both` (default `claude`) and persisted in `blinder/.agents`.
**Why generate-from-one-source over fork-per-tool:** the CLI, verifier, state, specs/docs,
and role-prompt *bodies* are already tool-agnostic; only the agent frontmatter, the verify
hook, and the entrypoint doc differ, so we generate that thin shell per target and never
duplicate the tree (duplication drifts). The Claude-style role prompts stay **canonical**;
an emitter in `install_agents.sh` transforms them for OpenCode. Leader instructions move to
a shared `blinder/docs/leader.md` that `CLAUDE.md` `@`-imports and `opencode.json` lists in
`instructions` (OpenCode doesn't auto-follow Markdown refs). **Why no model/effort/temperature
on OpenCode:** OpenCode is multi-provider, so pinning would hardcode provider slugs and drop
`effort` regardless — instead OpenCode agents inherit the user's configured model, which
makes **model tiering (D7) a Claude-only feature for now** (documented, with a manual
per-agent override). **Why graceful degradation for questions:** OpenCode's structured
question tool isn't uniformly exposed, so the discussion/approval invariant is "ask before
spec," satisfied by a structured tool when present and plain conversation otherwise.
`upgrade --agent` is **union/add-only** (it can grow the target set but never silently
delete a working shell); removing/switching a target is a deliberate manual step (reversible
via git), with an explicit `--only`/`--replace` flag deferred to the backlog.
