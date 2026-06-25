# Backlog & open threads

> What's not done and what's been deliberately deferred — so a future session can pick
> up without re-deriving it. Rationale for shipped decisions is in `docs/DESIGN.md`;
> history is `git log`.

## High value

### Automated test suite (`bats` + `shellcheck`)
A first automated check now exists: **`tests/smoke.sh`** (pure bash, no live agent run)
covers `bash -n`, the `claude`/`opencode`/`both` scaffolds, the OpenCode frontmatter
transform, and `upgrade --agent` union/preserve behavior. Still missing: `shellcheck`, and
behavioral coverage of the CLI invariants below (the repeated `set -e` + trailing-`&&` bugs
and the cycle-detection jq scope bug would have been caught instantly by these).

Plan (smoke.sh is the start; the rest sketched, not built):
- **shellcheck** gate over `scripts/blinder.sh`, `templates/init.sh`,
  `templates/install/install_agents.sh`.
- **bats** behavioral tests in `tests/bats/`, one file per command + `init_sh.bats`,
  with a `test_helper.bash` that scaffolds a temp project per test.
- Regression anchors for the bugs actually hit: exit codes of `new`/`set`/`status`
  (trailing-`&&`), the one-`in_progress` and invalid-status invariants, 2- and 3-node
  dependency cycles, and `verify.env` survival through `upgrade`.
- Wire as `tests/run.sh` (= shellcheck + bats); this becomes the project's real test
  command (and, if ever self-hosted, its `PROJECT_TEST_CMD`).
- **Start minimal/high-ROI:** shellcheck + `new`/`set`/`status` exit codes + the
  `init_sh` invariants. Expand to `upgrade`/`roadmap`/`next` after.
- Deps: `bats` (apt or git submodule bats-core) + `shellcheck`. No npm/pnpm.

## Deferred / decided-against (with reasons)

- **Self-hosting Blinder on Blinder** — decided against for now (see `docs/DESIGN.md`
  D14: bash/Markdown fit + repo-root confusion). Revisit only *after* the test suite
  exists, with clear live-instance/template separation and a README note.
- **`upgrade` layout migrations** — `upgrade` currently only refreshes harness-owned
  files + regenerates the board; it does **not** move files when the scaffold layout
  changes (e.g. the `docs/ → blinder/docs/` move). Such migrations are rare and done by
  hand for now. `blinder/.version` is stamped so versioned, `.version`-driven migrations
  can be added later if they become frequent.
- **`.claude/settings.json` on upgrade** — left untouched (users may add custom hooks).
  A merge/refresh strategy could be added if the default hook config evolves.

## Multi-agent targets (OpenCode) — follow-ups

Shipped: `--agent claude|opencode|both` on `init`/`upgrade`, persisted in `blinder/.agents`
(see `docs/DESIGN.md` D16, plan in `docs/opencode-support.md`). Deferred from that work:

- **Model tiering on OpenCode via `small_model`** — D16 drops `model:`/`effort:` on OpenCode
  (it inherits the user's configured model), so tiering (D7) is Claude-only for now. A path:
  map the mechanical `implementer` to OpenCode's `small_model` and the judgment roles to the
  main model, without hardcoding provider slugs. Until then, the escape hatch is a manual
  `model:` per `.opencode/agents/*.md`.
- **Explicit `upgrade --agent X --only` / `--replace`** — `upgrade --agent` is union/add-only
  (D-6) so a typo can't delete a working shell; removing/switching a target is manual today
  (delete the shell dir + edit `.agents`, reversible via git). A verbose flag that prints
  exactly what it would delete before doing so would make switching first-class.
- **Generalize to a third agent front-end** — the per-target generator is currently a
  two-branch dispatch (claude/opencode) over a Claude-canonical source. A third target would
  justify revisiting D-1 (a neutral metadata block → emit-all) instead of adding branches.
- **Live plugin-firing test** — the OpenCode verify plugin is parse/registration-validated
  (OpenCode 1.17.9) but its `tool.execute.after` hook hasn't been exercised end-to-end in a
  real session (needs an LLM run). Worth a one-time confirmation in a throwaway project.

## Possible enhancements (not committed to)

- **`docs/seeds/` convention + Planner reads seeds** — formalize the "persist a design
  chat as a seed that feeds planning" flow (discussed in DESIGN D12; not wired).
- **On-demand snapshot generation** as a documented Leader capability ("generate a doc
  describing X from current code/specs", with a provenance header).
- **ID prefixes by type** (`FX-`/`CH-`) — considered; kept a single `FR-` sequence with
  a `type` field instead. Revisit only if the board becomes hard to read.

## Known minor issues

- `init.sh`'s `unittest` fallback can report "Ran 0 tests" in a non-package `tests/`
  layout (a `unittest discover` import quirk). `pytest` is unaffected; documented. Most
  projects set `PROJECT_TEST_CMD` anyway.
- `in_progress_kotlin_gidance.md` at the repo root is an unrelated pre-existing scratch
  note (never part of Blinder). Decide to delete it or add to `.gitignore`.

## Reference

- Public repo: https://github.com/evrpg/blinder
- A worked end-to-end example lived in a sibling `test-project-todo-list/` (throwaway,
  not in this repo) — FR-0001 driven through the full loop.
