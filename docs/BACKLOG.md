# Backlog & open threads

> What's not done and what's been deliberately deferred — so a future session can pick
> up without re-deriving it. Rationale for shipped decisions is in `docs/DESIGN.md`;
> history is `git log`.

## High value

### Automated test suite (`bats` + `shellcheck`)
Blinder has **zero automated tests today** — every change has been verified by hand in
`/tmp`. The repeated `set -e` + trailing-`&&` bugs and the cycle-detection jq scope bug
would have been caught instantly by a suite.

Plan (sketched, not built):
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
