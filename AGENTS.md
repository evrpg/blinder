# AGENTS.md — working on Blinder itself

> You are working **on Blinder, the tool** — not inside a project scaffolded by it.
> (Blinder is a scaffolding system; see `README.md` for what it is and `MANUAL.md`
> for how a scaffolded project uses it.)

## Orient yourself, in this order

1. `README.md` — what Blinder is + quickstart.
2. `MANUAL.md` — the full workflow it imprints on a project.
3. `docs/DESIGN.md` — the decisions and *why* (rationale + alternatives we rejected).
4. `docs/BACKLOG.md` — open threads / what's next.
5. `git log` — the change history; commit messages narrate the evolution and reasoning.

## Repo map

| Path | What it is |
|------|-----------|
| `scripts/blinder.sh` | The CLI — single source of truth. Vendored into each project as `blinder/cli.sh`. Commands: `init`, `new`, `set`, `log`, `status`, `next`, `roadmap`, `upgrade`. |
| `templates/` | **The product** — everything copied into a scaffolded project. |
| `templates/prompts/roles/` | The agent role prompts: `planner`, `discussion`, `spec_author`, `implementer`, `reviewer`. |
| `templates/docs/` | Doc templates (project `CLAUDE.md`, `AGENTS.md`, `architecture.md`, `conventions.md`, `specs.md`, `CHECKPOINTS.md`, decisions template, root-docs README). |
| `templates/init.sh` | Tiered verification harness scaffolded as `blinder/init.sh`. |
| `templates/verify.env` | Project-owned build/test tuning scaffolded as `blinder/verify.env`. |
| `templates/config/` | `feature_list.json` + `claude_settings.json` (the hook). |
| `templates/install/install_agents.sh` | Assembles `.claude/agents/*` from the role prompts. |
| `MANUAL.md` / `README.md` / `LICENSE` | Docs + MIT license. |

## Making changes

- **Edit the template sources** under `templates/` (and `scripts/blinder.sh`) — those *are* the product. There is no separate build step.
- Blinder is **bash + Markdown + jq**. Keep scripts `set -euo pipefail`-clean.
- **Watch the `set -e` + trailing-`&&` pitfall:** a line like `[ cond ] && action` as the *last* statement of a function returns the test's exit code — which has bitten this CLI repeatedly (e.g. `cmd_new`, `cmd_status`). Prefer `if … then … fi`, or end the function with an explicit `return 0`.
- Keep the `init.sh` fast tier cheap (it's the `PostToolUse` hook); the test suite belongs behind `--full`.

## Testing (today: manual)

There is **no automated test suite yet** (see `docs/BACKLOG.md`). Verify changes by:
1. `bash -n scripts/blinder.sh templates/init.sh` (syntax).
2. Scaffolding into a throwaway dir and exercising it:
   ```bash
   tmp=$(mktemp -d); (cd "$tmp" && git init -q && /path/to/blinder/scripts/blinder.sh init --name t \
     && bash blinder/cli.sh new "X" && bash blinder/cli.sh status && bash blinder/init.sh)
   ```
3. For `upgrade`: scaffold, `git commit`, then `blinder upgrade --dry-run` / apply.

A `bats` + `shellcheck` suite is planned (`docs/BACKLOG.md`) and would become this project's real test command.

## Conventions

- Conventional-commit style with detailed bodies that explain the *why* (match the existing `git log`).
- Tables in `feature_list.json` / schema changes stay **backward-compatible** (read with `// default`), so existing projects keep working and `upgrade` needs no data migration.
- Blinder targets **Claude Code**; `AGENTS.md`/role prompts are plain Markdown other agents can read.

## Note

Blinder is **not self-hosted** (it doesn't run its own harness on itself) — see the rationale in `docs/DESIGN.md`. Dogfood via a separate throwaway project instead.
