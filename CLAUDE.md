# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

> **You are working _on Blinder, the tool_** — the scaffolding system — not inside a
> project scaffolded by it. `AGENTS.md` is the companion orientation map (repo layout,
> the `set -e` pitfall, commit conventions); read it too. `README.md` = what Blinder is,
> `MANUAL.md` = the workflow it imprints, `docs/DESIGN.md` = the _why_ behind every
> design decision (D1–D14), `docs/BACKLOG.md` = what's deferred.

## What this repo is

Blinder is a **scaffolding system, not a runtime** (DESIGN D1). It calls no LLM API and
runs no autonomous loop. It is **bash + Markdown + jq** with **no build step** — the
files under `templates/` *are the product* that gets copied into a target project, and
`scripts/blinder.sh` is the CLI. Editing those sources ships the change.

Critically: **this repo is not self-hosted** (DESIGN D14). Blinder does not run its own
SDD harness on itself — there is no `blinder/` working instance at the root, and you
should not create one. The `CLAUDE.md`/`AGENTS.md`/`architecture.md` *under `templates/`*
are artifacts emitted into scaffolded projects; this root `CLAUDE.md` is the only one
that governs work here.

## Commands

The fast automated check is **`bash tests/smoke.sh`** — a pure-bash scaffolding smoke
suite (no live agent run): it `bash -n`s the shell sources, scaffolds `claude` /
`opencode` / `both` into throwaway dirs, and asserts the per-target shell + the OpenCode
frontmatter transform + `upgrade --agent` union/preserve behavior. Run it after any change
to the CLI, templates, or `install_agents.sh`. (A fuller `bats` + `shellcheck` suite is
still planned — DESIGN/BACKLOG.)

```bash
# Fast: the scaffolding smoke suite (run from anywhere)
bash tests/smoke.sh

# Manual end-to-end (when you want to poke a scaffold by hand):
bash -n scripts/blinder.sh templates/init.sh templates/install/install_agents.sh
blinder=$(pwd)
tmp=$(mktemp -d); ( cd "$tmp" && git init -q \
  && "$blinder/scripts/blinder.sh" init --name t \
  && bash blinder/cli.sh new "X" \
  && bash blinder/cli.sh status \
  && bash blinder/init.sh )            # the fast verification tier

# For upgrade changes: scaffold, commit, then preview / apply
( cd "$tmp" && git add -A && git commit -qm baseline \
  && "$blinder/scripts/blinder.sh" upgrade --dry-run )
```

`init` and `upgrade` must be run via the **source** CLI (`scripts/blinder.sh`) because
they read `templates/`; all other commands run via the **vendored** `blinder/cli.sh`
inside a scaffolded project (DESIGN D9).

## The two-CLI / source-vs-vendored model

`scripts/blinder.sh` is the single source of truth for the CLI. `init` copies it into
each scaffolded project as `blinder/cli.sh` (DESIGN D9) so agents — which run
non-interactively without a shell alias, and have no access to this source repo — can
manage features via a relative path. Consequence: **`init` and `upgrade` are
source-only** (they need `templates/`, guarded by `require_templates()`); `new`, `set`,
`log`, `status`, `next`, `roadmap` work from the vendored copy.

`feature_list.json` is the **canonical state** (features, status, deps, epics). Always
mutate it through `cli.sh set`/`new` — never hand-edit it (DESIGN D10: an agent
improvising around a missing capability is a feature request, not a hand-edit). Schema
changes must stay **additive / backward-compatible** (read with `// default` in jq) so
existing projects keep working and `upgrade` needs no data migration.

## The harness it imprints (what gets scaffolded)

Understanding the *output* is what makes the templates legible. A scaffolded project runs
a two-altitude, spec-driven workflow driven by Claude Code's native features:

- **Leader (main thread)** runs *planning*, *discussion*, and the *approval gate* —
  because `AskUserQuestion` and human approval can only happen in the main conversation
  (DESIGN D3). **Subagents** (`spec_author`, `implementer`, `reviewer`) run spec,
  implementation, and review; their context is discarded on return — the biggest token
  lever.
- **Feature lifecycle:** `pending → discussed → spec_ready → (HUMAN APPROVES) →
  in_progress → implemented → done` (plus `blocked`/`deferred`). At most one
  `in_progress` at a time (enforced by `cli.sh set` and `init.sh`).
- **Three right-sized lanes** (DESIGN D8): **feature** = full loop; **fix**
  (`new --type fix --fixes FR-X`) skips discussion, regression-test-first; **chore**
  (`cli.sh log "…"`) = a tiny non-behavioral edit the Leader makes directly and logs, no
  unit/cycle.
- **`spec_author` owns the failing tests** (DESIGN D6, "option C"): the spec author writes
  the test oracle, the implementer only makes it pass, the reviewer audits code-vs-spec.
  This keeps the oracle independent of the code author and enables **model tiering**
  (DESIGN D7: strong model for spec/review judgment, cheaper model for mechanical
  implementation) via `model:` frontmatter in `.claude/agents/`.

### Source → scaffolded mapping

| Source (edit here) | Becomes (in a project) |
|--------------------|------------------------|
| `scripts/blinder.sh` | `blinder/cli.sh` (vendored snapshot, refreshed on `upgrade`) |
| `templates/init.sh` | `blinder/init.sh` (harness-owned verification; refreshed on `upgrade`) |
| `templates/verify.env` | `blinder/verify.env` (**project-owned** build/test tuning; `upgrade` never touches it — DESIGN D13) |
| `templates/prompts/roles/*` | the role prompts; `install_agents.sh` assembles `.claude/agents/*` from them |
| `templates/docs/*` | project `CLAUDE.md`, `AGENTS.md`, `blinder/docs/*` |
| `templates/config/feature_list.json` | `blinder/feature_list.json` (canonical state) |

## Verification harness (`templates/init.sh`)

Tiered on purpose: **fast** (default) does structural checks + `feature_list.json`
validity + at-most-one-`in_progress` + compile/typecheck, and is wired as the
`PostToolUse` hook — so **keep it cheap** (seconds). The expensive project test suite is
gated behind `--full` (run by the reviewer and before marking `done`). Build/test
commands are read from the project-owned `blinder/verify.env`
(`PROJECT_COMPILE_CMD`/`PROJECT_TEST_CMD`); empty means auto-detect.

## Gotchas specific to this codebase

- **`set -e` + trailing `&&`:** a `[ cond ] && action` as the *last* statement of a
  function returns the test's exit code — this has bitten `cmd_new`/`cmd_status`
  repeatedly. Prefer `if … then … fi` or end with explicit `return 0`. Keep all shell
  `set -euo pipefail`-clean.
- **Stable IDs are sacred:** `new` appends and never renumbers; `FR-XXXX` and task IDs
  like `FR-0001-T3` appear in specs and commit messages. The Planner is re-runnable and
  must never renumber.
- **`upgrade` is gated on a clean git tree** (the undo mechanism) and does not migrate
  layout changes — those are done by hand (BACKLOG).
- **`docs/` ownership split:** everything Blinder owns lives under `blinder/`; root
  `docs/` in a scaffolded project is the *user's* space (DESIGN D12). In *this* repo,
  root `docs/` holds `DESIGN.md` + `BACKLOG.md` (the tool's own design records).
- **Commits:** conventional-commit style with bodies that explain the *why*, matching the
  existing `git log` (the history narrates the design evolution).
