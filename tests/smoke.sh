#!/usr/bin/env bash
# tests/smoke.sh — deterministic scaffolding smoke test for Blinder.
#
# Pure bash + jq; NO live agent run (no Claude/OpenCode LLM calls). It scaffolds
# throwaway projects under a temp dir and asserts the generated shell per target:
# the default Claude path stays intact, `--agent opencode|both` emit the right
# files, the OpenCode frontmatter transform is correct, and `upgrade --agent` is
# union/add-only with project-owned config preserved.
#
# Run from anywhere:  bash tests/smoke.sh
# Exit 0 = all assertions passed; 1 = at least one failed (or a fatal setup error).
# The backlogged bats + shellcheck suite (docs/BACKLOG.md) would formalize this.

set -uo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLI="$SRC/scripts/blinder.sh"
GREEN=$'\e[32m'; RED=$'\e[31m'; DIM=$'\e[2m'; NC=$'\e[0m'

command -v jq  >/dev/null 2>&1 || { echo "${RED}fatal:${NC} jq is required"; exit 1; }
command -v git >/dev/null 2>&1 || { echo "${RED}fatal:${NC} git is required"; exit 1; }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

PASS=0; FAIL=0
assert() { local d="$1"; shift; if "$@" >/dev/null 2>&1; then PASS=$((PASS+1)); printf "  ${GREEN}ok${NC}   %s\n" "$d"; else FAIL=$((FAIL+1)); printf "  ${RED}FAIL${NC} %s\n" "$d"; fi; }
section() { printf "\n${DIM}── %s ──${NC}\n" "$1"; }

# --- helpers (named so `assert` can invoke them) ---------------------------
nogrep()       { ! grep -q "$1" "$2"; }                       # pattern file → true if ABSENT
agents_eq()    { [ "$(cat "$1/blinder/.agents" 2>/dev/null)" = "$2" ]; }
json_eq()      { [ "$(jq -r "$2" "$1" 2>/dev/null)" = "$3" ]; }
oc_instr_has() { jq -e --arg p "$2" '(.instructions // []) | index($p) != null' "$1" >/dev/null 2>&1; }
run_init_sh()  { ( cd "$1" && bash blinder/init.sh >/dev/null 2>&1 ); }

scaffold()   { local d="$1"; shift; mkdir -p "$d"; ( cd "$d" && git init -q && "$CLI" init --name t "$@" >/dev/null 2>&1 ); }
commit_all() { ( cd "$1" && git add -A && git -c user.email=t@t.c -c user.name=t commit -qm baseline >/dev/null 2>&1 ); }
do_upgrade() { local d="$1"; shift; ( cd "$d" && "$CLI" upgrade "$@" >/dev/null 2>&1 ); }

# Assert one transformed OpenCode agent file: $1=projdir $2=role $3=expected bash perm
assert_oc_agent() {
  local f="$1/.opencode/agents/$2.md" b="$3"
  assert "[$2] file exists"          test -f "$f"
  assert "[$2] mode: subagent"       grep -q '^mode: subagent' "$f"
  assert "[$2] dropped name:"        nogrep '^name:' "$f"
  assert "[$2] dropped model:"       nogrep '^model:' "$f"
  assert "[$2] dropped effort:"      nogrep '^effort:' "$f"
  assert "[$2] has permission block" grep -q '^permission:' "$f"
  assert "[$2] edit: allow"          grep -q '^  edit: allow' "$f"
  assert "[$2] bash: $b"             grep -q "^  bash: $b" "$f"
  assert "[$2] webfetch: deny"       grep -q '^  webfetch: deny' "$f"
  assert "[$2] websearch: deny"      grep -q '^  websearch: deny' "$f"
}

# ===========================================================================
section "1. static checks"
assert "bash -n blinder.sh"          bash -n "$SRC/scripts/blinder.sh"
assert "bash -n init.sh"             bash -n "$SRC/templates/init.sh"
assert "bash -n install_agents.sh"   bash -n "$SRC/templates/install/install_agents.sh"
assert "bash -n tests/smoke.sh"      bash -n "$SRC/tests/smoke.sh"
assert "feature_list.json valid"     jq empty "$SRC/templates/config/feature_list.json"
assert "claude_settings.json valid"  jq empty "$SRC/templates/config/claude_settings.json"
assert "opencode.json valid"         jq empty "$SRC/templates/config/opencode.json"
assert "opencode.json lists AGENTS.md"  oc_instr_has "$SRC/templates/config/opencode.json" "AGENTS.md"
assert "opencode.json lists leader.md"  oc_instr_has "$SRC/templates/config/opencode.json" "blinder/docs/leader.md"

# ===========================================================================
section "2. default (claude) — must stay intact + leak no opencode artifacts"
D="$WORK/claude"; scaffold "$D"
assert "CLAUDE.md present"            test -f "$D/CLAUDE.md"
assert ".claude/settings.json"       test -f "$D/.claude/settings.json"
for r in spec_author implementer reviewer; do assert ".claude/agents/$r.md" test -f "$D/.claude/agents/$r.md"; done
assert "AGENTS.md present"           test -f "$D/AGENTS.md"
assert "leader.md present"           test -f "$D/blinder/docs/leader.md"
assert ".agents = 'claude'"          agents_eq "$D" "claude"
assert "NO opencode.json"            test ! -f "$D/opencode.json"
assert "NO .opencode/"               test ! -d "$D/.opencode"
# exercise the vendored CLI end-to-end
assert "cli.sh new"                  bash -c "cd '$D' && bash blinder/cli.sh new 'X' >/dev/null"
assert "cli.sh status"               bash -c "cd '$D' && bash blinder/cli.sh status >/dev/null"
assert "cli.sh next"                 bash -c "cd '$D' && bash blinder/cli.sh next >/dev/null"
assert "init.sh passes"              run_init_sh "$D"

# ===========================================================================
section "3. --agent opencode — opencode shell only, transform correct"
D="$WORK/opencode"; scaffold "$D" --agent opencode
assert "NO CLAUDE.md"                test ! -f "$D/CLAUDE.md"
assert "NO .claude/"                 test ! -d "$D/.claude"
assert "AGENTS.md present (shared)"  test -f "$D/AGENTS.md"
assert "leader.md present (shared)"  test -f "$D/blinder/docs/leader.md"
assert "opencode.json present"       test -f "$D/opencode.json"
assert "verify plugin present"       test -f "$D/.opencode/plugins/blinder-verify.ts"
assert ".agents = 'opencode'"        agents_eq "$D" "opencode"
assert_oc_agent "$D" spec_author deny
assert_oc_agent "$D" implementer allow
assert_oc_agent "$D" reviewer    allow
assert "init.sh passes"              run_init_sh "$D"

# ===========================================================================
section "4. --agent both — both shells present"
D="$WORK/both"; scaffold "$D" --agent both
assert "CLAUDE.md present"           test -f "$D/CLAUDE.md"
assert ".claude/agents present"      test -f "$D/.claude/agents/spec_author.md"
assert "opencode.json present"       test -f "$D/opencode.json"
assert ".opencode/agents present"    test -f "$D/.opencode/agents/spec_author.md"
assert "verify plugin present"       test -f "$D/.opencode/plugins/blinder-verify.ts"
assert ".agents = 'claude opencode'" agents_eq "$D" "claude opencode"
assert "init.sh passes"              run_init_sh "$D"

# ===========================================================================
section "5. invalid --agent is rejected"
D="$WORK/bad"; mkdir -p "$D"
assert "init --agent bogus fails"    bash -c "cd '$D' && git init -q && ! '$CLI' init --name t --agent bogus >/dev/null 2>&1"

# ===========================================================================
section "6. upgrade --agent is union/add-only (D-6)"
# claude → add opencode ⇒ {claude, opencode}, no swap
D="$WORK/up_add"; scaffold "$D"; commit_all "$D"; do_upgrade "$D" --agent opencode
assert "claude+opencode ⇒ union"     agents_eq "$D" "claude opencode"
assert "  kept CLAUDE.md"            test -f "$D/CLAUDE.md"
assert "  added .opencode/agents"    test -f "$D/.opencode/agents/reviewer.md"
assert "  init.sh passes"            run_init_sh "$D"

# opencode → plain upgrade ⇒ stays opencode-only (no CLAUDE.md appears)
D="$WORK/up_plain"; scaffold "$D" --agent opencode; commit_all "$D"; do_upgrade "$D"
assert "opencode stays opencode"     agents_eq "$D" "opencode"
assert "  still NO CLAUDE.md"        test ! -f "$D/CLAUDE.md"
assert "  init.sh passes"            run_init_sh "$D"

# legacy project (no .agents) → plain upgrade ⇒ stamped 'claude'
D="$WORK/up_legacy"; scaffold "$D" --agent opencode; rm -f "$D/blinder/.agents"
# fake a pre-multi-agent claude project: add CLAUDE.md, drop opencode shell marker
cp "$SRC/templates/docs/CLAUDE.md" "$D/CLAUDE.md"; commit_all "$D"; do_upgrade "$D"
assert "missing .agents ⇒ 'claude'"  agents_eq "$D" "claude"

# ===========================================================================
section "7. upgrade preserves project-owned opencode.json (user's model)"
D="$WORK/preserve"; scaffold "$D" --agent opencode
( cd "$D" && jq '. + {"model":"openai/gpt-5"}' opencode.json > o.tmp && mv o.tmp opencode.json )
commit_all "$D"; do_upgrade "$D"
assert "user model survives upgrade" json_eq "$D/opencode.json" '.model' 'openai/gpt-5'
assert "plugin refreshed (exists)"   test -f "$D/.opencode/plugins/blinder-verify.ts"

# ===========================================================================
printf "\n${DIM}────────────────────────────────────────${NC}\n"
if [ "$FAIL" -eq 0 ]; then
  printf "${GREEN}PASS${NC} — %d assertions, 0 failures\n" "$PASS"; exit 0
else
  printf "${RED}FAIL${NC} — %d passed, %d failed\n" "$PASS" "$FAIL"; exit 1
fi
