#!/usr/bin/env bash
# blinder.sh — Claude-native Spec-Driven Development harness CLI (v3)

set -euo pipefail

BLINDER_VERSION="0.4.0"

# Find script directory and root directory of blinder installation
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BLINDER_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors
RED=$'\e[0;31m'
GREEN=$'\e[0;32m'
YELLOW=$'\e[0;33m'
BLUE=$'\e[0;34m'
CYAN=$'\e[0;36m'
GREY=$'\e[0;90m'
NC=$'\e[0m'

info()  { printf "${BLUE}[INFO]${NC}  %s\n" "$1"; }
ok()    { printf "${GREEN}[OK]${NC}    %s\n" "$1"; }
warn()  { printf "${YELLOW}[WARN]${NC}  %s\n" "$1"; }
error() { printf "${RED}[ERROR]${NC} %s\n" "$1"; exit 1; }

now_utc() { date -u +%Y-%m-%dT%H:%M:%SZ; }

require_jq() {
  command -v jq >/dev/null 2>&1 || error "jq is required but not installed. Install jq and retry."
}

# init/upgrade need the template library; the vendored blinder/cli.sh does not have it.
require_templates() {
  [ -d "$BLINDER_ROOT/templates" ] || error "This command needs the source blinder CLI (it reads templates). Run it via the repo path or alias, e.g. /path/to/blinder/scripts/blinder.sh $1 — not the vendored blinder/cli.sh."
}

stamp_version() {
  local sha; sha=$(git -C "$BLINDER_ROOT" rev-parse --short HEAD 2>/dev/null || echo "unknown")
  printf 'blinder %s (%s) %s\n' "$BLINDER_VERSION" "$sha" "$(now_utc)" > blinder/.version
}

show_help() {
  cat <<EOF
Blinder — Claude-native Spec-Driven Development harness

Usage:
  blinder.sh init   [--name "project-name"]
  blinder.sh new    "title" [--description "..."] [--acceptance "a, b, c"]
                    [--depends-on "FR-0001,FR-0002"] [--epic "name"]
                    [--type feature|fix] [--fixes "FR-0001"] [--no-sdd]
  blinder.sh set    <FR-ID> <status> [--reason "..."]
  blinder.sh log    "message"
  blinder.sh status
  blinder.sh next
  blinder.sh roadmap
  blinder.sh upgrade [--dry-run]
  blinder.sh help

Commands:
  init      Scaffold the harness into the current directory (Claude Code).
  upgrade   Refresh the harness-owned files in an existing project from current
            templates (preserves feature_list, specs, init.sh tuning, your docs).
            Run from the project root via the source CLI; needs a clean git tree.
  new       Register a tracked unit of work (assigns FR-XXXX). --type fix marks a
            fix (lighter flow); --fixes links it to the feature(s) it repairs.
  set       Transition a feature's status (validates value, enforces one in_progress,
            bumps 'updated', sets/clears blocked_reason). Use this — never hand-edit JSON.
  log       Append a one-line entry to history.md for a small change too minor to
            be a tracked feature/fix (the "chore" lane). No unit, no cycle.
  status    Print a dashboard of all features, their state and dependencies.
  next      Print the next actionable feature (deps satisfied), or nothing.
  roadmap   Regenerate blinder/roadmap.md (a human-readable board) from feature_list.json.
            Also regenerated automatically by 'new' and 'set'.
  help      Show this help.

Lifecycle:
  pending -> [discussion] -> discussed -> [spec] -> spec_ready
          -> (HUMAN APPROVES) -> in_progress -> [implement/TDD]
          -> implemented -> [review] -> done       (blocked / deferred any time)
EOF
}

cmd_init() {
  PROJECT_NAME=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --name) PROJECT_NAME="$2"; shift 2 ;;
      *) error "Unknown argument: $1" ;;
    esac
  done
  require_jq

  [ -z "$PROJECT_NAME" ] && PROJECT_NAME="$(basename "$(pwd)")"

  if [ -f "blinder/feature_list.json" ]; then
    error "blinder/feature_list.json already exists! Aborting to prevent overwrite."
  fi

  info "Initializing Blinder harness for project: $PROJECT_NAME"

  mkdir -p .claude/agents
  mkdir -p blinder/docs
  mkdir -p blinder/prompts/roles
  mkdir -p blinder/progress
  mkdir -p blinder/specs
  mkdir -p docs

  # Root entrypoints + navigation
  cp "$BLINDER_ROOT/templates/docs/CLAUDE.md"   "./CLAUDE.md"
  cp "$BLINDER_ROOT/templates/docs/AGENTS.md"   "./AGENTS.md"

  # Harness reference docs (project-fillable inputs + methodology + criteria)
  cp "$BLINDER_ROOT/templates/docs/architecture.md" "./blinder/docs/architecture.md"
  cp "$BLINDER_ROOT/templates/docs/conventions.md"  "./blinder/docs/conventions.md"
  cp "$BLINDER_ROOT/templates/docs/specs.md"        "./blinder/docs/specs.md"
  cp "$BLINDER_ROOT/templates/docs/CHECKPOINTS.md"  "./blinder/docs/CHECKPOINTS.md"

  # Shared, tool-neutral Leader orchestration body (CLAUDE.md @-imports it; other
  # agent front-ends load it via their own config). Harness-owned; refreshed on upgrade.
  cp "$BLINDER_ROOT/templates/docs/leader.md"       "./blinder/docs/leader.md"

  # Root docs/ is the user's space (seeds + on-demand snapshots) — see its README
  cp "$BLINDER_ROOT/templates/docs/root_docs_readme.md" "./docs/README.md"

  # Templates
  cp "$BLINDER_ROOT/templates/docs/decisions.md.tmpl"   "./blinder/prompts/decisions.template.md"
  cp "$BLINDER_ROOT/templates/progress/current.md"      "./blinder/progress/current.md"
  cp "$BLINDER_ROOT/templates/progress/history.md"      "./blinder/progress/history.md"
  cp "$BLINDER_ROOT/templates/init.sh"                  "./blinder/init.sh"
  chmod +x "./blinder/init.sh"

  # Project-owned verification config (PROJECT_COMPILE_CMD/PROJECT_TEST_CMD). Kept
  # separate from init.sh so `blinder upgrade` can refresh init.sh without losing tuning.
  cp "$BLINDER_ROOT/templates/verify.env"               "./blinder/verify.env"

  # Vendor the CLI so feature management works in-project without a global install or
  # shell alias (agents run non-interactively). Disposable snapshot — refreshed on upgrade.
  cp "$BLINDER_ROOT/scripts/blinder.sh"                 "./blinder/cli.sh"
  chmod +x "./blinder/cli.sh"
  stamp_version

  # Hook config for Claude Code
  cp "$BLINDER_ROOT/templates/config/claude_settings.json" "./.claude/settings.json"

  # feature_list.json with project name (+ initial generated roadmap board)
  jq --arg name "$PROJECT_NAME" '.project = $name' \
    "$BLINDER_ROOT/templates/config/feature_list.json" > "blinder/feature_list.json"
  write_roadmap

  # Install role prompts + subagents
  bash "$BLINDER_ROOT/templates/install/install_agents.sh" "."

  ok "Blinder harness initialized."
  info "Next steps:"
  echo "  1. Fill blinder/docs/architecture.md and blinder/docs/conventions.md for your project."
  echo "  2. Run: bash blinder/init.sh        (fast verification)"
  echo "  3. Add a feature:  bash blinder/cli.sh new \"My feature\""
  echo "  4. Open Claude Code and say: \"Work the next pending feature.\""
}

cmd_new() {
  require_jq
  [ -f "blinder/feature_list.json" ] || error "blinder/feature_list.json not found. Run 'blinder.sh init' first."
  [ $# -lt 1 ] && error "Missing feature title. Usage: blinder.sh new \"feature title\""

  # A leading flag is almost always a mistake — without this guard, `new --help`
  # (or any `-…` first arg) gets stored verbatim as the feature title.
  case "$1" in
    -h|--help|help) show_help; exit 0 ;;
    -*) error "First argument must be the feature title, not a flag ('$1'). Usage: blinder.sh new \"feature title\" [flags]" ;;
  esac

  TITLE="$1"; shift
  SDD=true
  DESC=""
  ACCEPTANCE_RAW=""
  DEPENDS_RAW=""
  EPIC=""
  TYPE="feature"
  FIXES_RAW=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --no-sdd)       SDD=false; shift ;;
      --sdd)          SDD=true; shift ;;
      --description)  DESC="$2"; shift 2 ;;
      --acceptance)   ACCEPTANCE_RAW="$2"; shift 2 ;;
      --depends-on)   DEPENDS_RAW="$2"; shift 2 ;;
      --epic)         EPIC="$2"; shift 2 ;;
      --type)         TYPE="$2"; shift 2 ;;
      --fixes)        FIXES_RAW="$2"; shift 2 ;;
      *) error "Unknown argument: $1" ;;
    esac
  done

  case "$TYPE" in
    feature|fix) ;;
    chore) error "Chores aren't tracked units. Record one with: blinder.sh log \"message\"" ;;
    *) error "Invalid --type '$TYPE' (feature|fix)" ;;
  esac

  # Next ID
  MAX_NUM=$(jq -r '.features[].id' blinder/feature_list.json 2>/dev/null | grep -oE '[0-9]+' | sort -n | tail -1 || true)
  # 10# forces base-10: MAX_NUM is zero-padded (e.g. 0008), and a leading-zero literal
  # in $(( )) is parsed as octal — 0008/0009 are invalid octal and abort the script.
  NEXT_NUM=$([ -z "$MAX_NUM" ] && echo 1 || echo $((10#$MAX_NUM + 1)))
  ID=$(printf "FR-%04d" "$NEXT_NUM")
  NAME=$(echo "$TITLE" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '_' | sed 's/^_//;s/_$//')

  csv_to_json_array() {
    local raw="$1" out="[]" item
    [ -z "$raw" ] && { echo "$out"; return; }
    IFS=',' read -ra ADDR <<< "$raw"
    for item in "${ADDR[@]}"; do
      item=$(echo "$item" | xargs)
      [ -z "$item" ] && continue
      out=$(echo "$out" | jq --arg i "$item" '. += [$i]')
    done
    echo "$out"
  }

  ACCEPTANCE_JSON=$(csv_to_json_array "$ACCEPTANCE_RAW")
  DEPENDS_JSON=$(csv_to_json_array "$DEPENDS_RAW")
  FIXES_JSON=$(csv_to_json_array "$FIXES_RAW")

  # Interactive prompts only when nothing supplied and we have a TTY
  if [ -t 0 ] && [ -t 1 ] && [ -z "$DESC" ] && [ -z "$ACCEPTANCE_RAW" ]; then
    echo -n "Description: "; read -r DESC
    echo "Acceptance criteria (one per line, empty line to finish):"
    while true; do
      echo -n "- "; read -r LINE
      [ -z "$LINE" ] && break
      ACCEPTANCE_JSON=$(echo "$ACCEPTANCE_JSON" | jq --arg i "$LINE" '. += [$i]')
    done
  fi

  [ -z "$DESC" ] && DESC="Implement $TITLE"
  [ "$ACCEPTANCE_JSON" = "[]" ] && ACCEPTANCE_JSON="[\"Verify $TITLE is fully implemented and tested.\"]"

  TS=$(now_utc)
  NEW_FEATURE=$(jq -n \
    --arg id "$ID" --arg name "$NAME" --arg title "$TITLE" --arg desc "$DESC" \
    --argjson sdd "$SDD" --argjson acceptance "$ACCEPTANCE_JSON" \
    --argjson depends "$DEPENDS_JSON" --arg epic "$EPIC" --arg type "$TYPE" \
    --argjson fixes "$FIXES_JSON" --arg ts "$TS" \
    '{id:$id, name:$name, title:$title, description:$desc, type:$type, sdd:$sdd,
      epic:$epic, acceptance:$acceptance, depends_on:$depends, fixes:$fixes,
      status:"pending", blocked_reason:null, created:$ts, updated:$ts}')

  TMP=$(mktemp)
  jq --argjson f "$NEW_FEATURE" '.features += [$f]' blinder/feature_list.json > "$TMP"
  mv "$TMP" blinder/feature_list.json
  write_roadmap

  ok "Created $ID ($TITLE)"
  if [ "$TYPE" != "feature" ]; then info "Type: $TYPE"; fi
  if [ "$FIXES_JSON" != "[]" ]; then info "Fixes: $(echo "$FIXES_JSON" | jq -r 'join(", ")')"; fi
  if [ -n "$EPIC" ]; then info "Epic: $EPIC"; fi
  if [ "$DEPENDS_JSON" != "[]" ]; then info "Depends on: $(echo "$DEPENDS_JSON" | jq -r 'join(", ")')"; fi
}

color_status() {
  case "$1" in
    pending)     printf "%s" "${YELLOW}pending${NC}" ;;
    discussed)   printf "%s" "${CYAN}discussed${NC}" ;;
    spec_ready)  printf "%s" "${BLUE}spec_ready${NC}" ;;
    in_progress) printf "%s" "${CYAN}in_progress${NC}" ;;
    implemented) printf "%s" "${BLUE}implemented${NC}" ;;
    done)        printf "%s" "${GREEN}done${NC}" ;;
    blocked)     printf "%s" "${RED}blocked${NC}" ;;
    deferred)    printf "%s" "${GREY}deferred${NC}" ;;
    *)           printf "%s" "$1" ;;
  esac
}

print_feature_row() {
  local feat="$1" FID FSTATUS FSDD FTITLE FDEPS FREASON PADDED COLORED
  FID=$(echo "$feat"    | jq -r '.id')
  FSTATUS=$(echo "$feat" | jq -r '.status')
  FSDD=$(echo "$feat"   | jq -r '.sdd')
  FTITLE=$(echo "$feat" | jq -r '.title')
  FDEPS=$(echo "$feat"  | jq -r '(.depends_on // []) | join(",")')
  FREASON=$(echo "$feat" | jq -r '.blocked_reason // empty')
  [ -z "$FDEPS" ] && FDEPS="-"
  # color_status emits invisible escape codes; pad the plain text first.
  PADDED=$(printf "%-13s" "$FSTATUS")
  COLORED=${PADDED/$FSTATUS/$(color_status "$FSTATUS")}
  printf "%-9s | %b | %-4s | %-14s | %s\n" "$FID" "$COLORED" "$FSDD" "$FDEPS" "$FTITLE"
  if [ -n "$FREASON" ]; then
    printf "          %sreason: %s%s\n" "$GREY" "$FREASON" "$NC"
  fi
}

cmd_status() {
  require_jq
  [ -f "blinder/feature_list.json" ] || error "blinder/feature_list.json not found. Run 'blinder.sh init' first."

  local FILE="blinder/feature_list.json"
  local SEP="--------------------------------------------------------------------------------"
  PROJECT_NAME=$(jq -r '.project' "$FILE")
  echo "Project: ${GREEN}${PROJECT_NAME}${NC}"
  echo "$SEP"
  printf "%-9s | %-13s | %-4s | %-14s | %s\n" "ID" "STATUS" "SDD" "DEPENDS" "TITLE"
  echo "$SEP"

  # Group by epic only when epics are actually in use; otherwise render flat.
  local N_EPICS
  N_EPICS=$(jq '[.features[].epic // "" | select(. != "")] | unique | length' "$FILE")

  if [ "$N_EPICS" -eq 0 ]; then
    jq -c '.features[]' "$FILE" | while read -r feat; do print_feature_row "$feat"; done
  else
    # Non-empty epics first (sorted), then the no-epic bucket last.
    jq -r '([.features[].epic // ""] | unique) as $e
           | (($e | map(select(. != ""))) + ($e | map(select(. == ""))))
           | .[]' "$FILE" | while IFS= read -r EPIC; do
      if [ -z "$EPIC" ]; then
        echo "${CYAN}▸ (no epic)${NC}"
      else
        echo "${CYAN}▸ ${EPIC}${NC}"
      fi
      jq -c --arg e "$EPIC" '.features[] | select((.epic // "") == $e)' "$FILE" \
        | while read -r feat; do print_feature_row "$feat"; done
    done
  fi
  echo "$SEP"
}

# Print the first feature that is actionable: not done/deferred/blocked and all
# of its depends_on are done. Respects one_feature_at_a_time (an in_progress
# feature is itself the actionable one).
cmd_next() {
  require_jq
  [ -f "blinder/feature_list.json" ] || error "blinder/feature_list.json not found. Run 'blinder.sh init' first."

  NEXT=$(jq -r '
    . as $root
    | ($root.features | map(select(.status=="done") | .id)) as $done
    | $root.features
    | map(select(.status != "done" and .status != "deferred" and .status != "blocked"))
    | map(select((.depends_on // []) - $done | length == 0))
    | (.[0] // empty)
    | if . == null then "" else "\(.id)\t\(.status)\t\(.title)" end
  ' blinder/feature_list.json)

  if [ -z "$NEXT" ]; then
    info "No actionable feature (all done/blocked/deferred, or dependencies unmet)."
  else
    printf "Next: ${GREEN}%s${NC}\n" "$(echo "$NEXT" | cut -f1)"
    printf "  status: %b\n" "$(color_status "$(echo "$NEXT" | cut -f2)")"
    printf "  title:  %s\n" "$(echo "$NEXT" | cut -f3)"
  fi
}

# Transition a feature's status safely (validates value, enforces one_feature_at_a_time,
# bumps `updated`, sets/clears `blocked_reason`). Agents must use this instead of
# hand-editing feature_list.json.
cmd_set() {
  require_jq
  [ -f "blinder/feature_list.json" ] || error "blinder/feature_list.json not found. Run 'blinder.sh init' first."
  [ $# -lt 2 ] && error "Usage: blinder.sh set <FR-ID> <status> [--reason \"...\"]"

  local ID="$1" ST="$2"; shift 2
  local REASON=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --reason) REASON="$2"; shift 2 ;;
      *) error "Unknown argument: $1" ;;
    esac
  done

  local F="blinder/feature_list.json"
  jq -e --arg id "$ID" 'any(.features[]; .id == $id)' "$F" >/dev/null 2>&1 \
    || error "No such feature: $ID"
  jq -e --arg s "$ST" '(.rules.valid_status | index($s)) != null' "$F" >/dev/null 2>&1 \
    || error "Invalid status '$ST'. Allowed: $(jq -r '.rules.valid_status | join(", ")' "$F")"

  if [ "$ST" = "in_progress" ]; then
    local OTHERS
    OTHERS=$(jq -r --arg id "$ID" '[.features[] | select(.status=="in_progress" and .id != $id) | .id] | join(", ")' "$F")
    [ -n "$OTHERS" ] && error "one_feature_at_a_time: $OTHERS already in_progress. Move it off in_progress first."
  fi

  if { [ "$ST" = "blocked" ] || [ "$ST" = "deferred" ]; } && [ -z "$REASON" ]; then
    warn "no --reason given for '$ST'; keeping any existing reason."
  fi

  local TS TMP; TS=$(now_utc); TMP=$(mktemp)
  jq --arg id "$ID" --arg s "$ST" --arg ts "$TS" --arg reason "$REASON" '
    (.features[] | select(.id == $id)) |= (
      .status = $s
      | .updated = $ts
      | .blocked_reason = (
          if ($s == "blocked" or $s == "deferred")
          then (if $reason != "" then $reason else .blocked_reason end)
          else null end)
    )' "$F" > "$TMP" && mv "$TMP" "$F"
  write_roadmap

  ok "$ID → $ST"
  if [ "$ST" = "blocked" ] || [ "$ST" = "deferred" ]; then
    local R; R=$(jq -r --arg id "$ID" '.features[] | select(.id==$id) | .blocked_reason // empty' "$F")
    [ -n "$R" ] && info "reason: $R"
  fi
  return 0
}

# (Re)generate blinder/roadmap.md — a human-readable board derived from
# feature_list.json (the single source of truth). Silent helper; safe to call after
# any mutation. Grouped by epic, newest source data each time.
write_roadmap() {
  local F="blinder/feature_list.json" OUT="blinder/roadmap.md"
  [ -f "$F" ] || return 0
  local PROJECT; PROJECT=$(jq -r '.project' "$F")
  {
    echo "# Roadmap — $PROJECT"
    echo ""
    echo '<!-- AUTO-GENERATED from blinder/feature_list.json by `blinder/cli.sh roadmap`. Do not edit by hand. -->'
    echo ""
    if [ "$(jq '.features | length' "$F")" -eq 0 ]; then
      echo '_No features yet. Add one: `blinder/cli.sh new "title"`._'
    else
      jq -r '"_\(.features|length) items — " + ([.features[].status] | group_by(.) | map("\(.[0]): \(length)") | join(", ")) + "_"' "$F"
      echo ""
      jq -r '([.features[].epic // ""] | unique) as $e
             | (($e | map(select(. != ""))) + ($e | map(select(. == ""))))
             | .[]' "$F" \
      | while IFS= read -r EPIC; do
          if [ -z "$EPIC" ]; then echo "## (no epic)"; else echo "## Epic: $EPIC"; fi
          echo ""
          echo "| Feature | Type | Status | Depends on | Title | Description |"
          echo "|---------|------|--------|------------|-------|-------------|"
          jq -r --arg e "$EPIC" '.features[] | select((.epic // "") == $e)
            | "| \(.id) | \(.type // "feature") | \(.status) | \(((.depends_on // []) | if length == 0 then "—" else join(", ") end)) | \(.title) | \(if ((.fixes // []) | length) > 0 then "fixes " + ((.fixes) | join(",")) + " — " else "" end)\(.description // "") |"' "$F"
          echo ""
        done
    fi
  } > "$OUT"
}

cmd_roadmap() {
  require_jq
  [ -f "blinder/feature_list.json" ] || error "blinder/feature_list.json not found. Run 'blinder.sh init' first."
  write_roadmap
  ok "Regenerated blinder/roadmap.md"
}

# Record a small change (the "chore" lane) without creating a tracked unit. Appends
# a timestamped line to history.md. For changes too minor to warrant feature/fix flow.
cmd_log() {
  [ $# -lt 1 ] && error "Usage: blinder.sh log \"message\""
  [ -d "blinder/progress" ] || error "blinder/progress not found. Run 'blinder.sh init' first."
  local MSG="$1" TS; TS=$(now_utc)
  printf -- '- `[chore]` %s — %s\n' "$TS" "$MSG" >> blinder/progress/history.md
  ok "Logged to blinder/progress/history.md"
}

# Refresh the harness-owned files in an existing project from the current templates,
# while preserving everything project-owned. Run from the project root via the SOURCE
# CLI (needs templates). Gated on a clean git tree; --dry-run previews the plan.
cmd_upgrade() {
  require_jq
  require_templates upgrade
  [ -f "blinder/feature_list.json" ] || error "Not a blinder project (no blinder/feature_list.json)."

  local DRY=false
  [ "${1:-}" = "--dry-run" ] && DRY=true

  # dest::source pairs — harness-owned files that are safe to overwrite.
  local REFRESH=(
    "CLAUDE.md::templates/docs/CLAUDE.md"
    "AGENTS.md::templates/docs/AGENTS.md"
    "blinder/docs/leader.md::templates/docs/leader.md"
    "blinder/docs/specs.md::templates/docs/specs.md"
    "blinder/docs/CHECKPOINTS.md::templates/docs/CHECKPOINTS.md"
    "blinder/prompts/decisions.template.md::templates/docs/decisions.md.tmpl"
    "blinder/init.sh::templates/init.sh"
    "blinder/cli.sh::scripts/blinder.sh"
  )

  if [ "$DRY" = true ]; then
    info "Dry run — no changes will be made."
  elif git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    [ -n "$(git status --porcelain)" ] && error "Working tree is dirty. Commit or stash first — upgrade overwrites harness files; a clean tree keeps it reversible. (Preview with --dry-run.)"
  else
    warn "Not a git repo — upgrade won't be easily reversible. Consider 'git init' first."
  fi

  echo "── Refresh (harness-owned, overwritten) ──"
  local pair dest src
  for pair in "${REFRESH[@]}"; do
    dest="${pair%%::*}"; src="${pair##*::}"
    echo "  $dest"
    if [ "$DRY" = false ]; then mkdir -p "$(dirname "$dest")"; cp "$BLINDER_ROOT/$src" "$dest"; fi
  done
  echo "  blinder/prompts/roles/* + .claude/agents/* (role prompts)"
  [ "$DRY" = false ] && bash "$BLINDER_ROOT/templates/install/install_agents.sh" "." >/dev/null
  if [ ! -f blinder/verify.env ]; then
    echo "  blinder/verify.env (missing — will be created from template)"
    [ "$DRY" = false ] && cp "$BLINDER_ROOT/templates/verify.env" blinder/verify.env
  fi

  echo "── Preserve (untouched) ──"
  echo "  feature_list.json · specs/ · progress/ · docs/architecture.md · docs/conventions.md"
  echo "  blinder/verify.env · root docs/ · .claude/settings.json · src/ & tests/"
  echo "── Regenerate ── blinder/roadmap.md"

  if [ "$DRY" = true ]; then
    info "Dry run complete. Re-run without --dry-run to apply (commit any changes first)."
    return 0
  fi

  chmod +x blinder/init.sh blinder/cli.sh
  write_roadmap
  stamp_version
  ok "Upgraded — $(cat blinder/.version)"
  info "Review with 'git diff', then verify: bash blinder/init.sh"
}

[ $# -lt 1 ] && { show_help; exit 1; }
CMD="$1"; shift
case "$CMD" in
  init)            cmd_init "$@" ;;
  new)             cmd_new "$@" ;;
  set)             cmd_set "$@" ;;
  log)             cmd_log "$@" ;;
  status)          cmd_status ;;
  next)            cmd_next ;;
  roadmap)         cmd_roadmap ;;
  upgrade)         cmd_upgrade "$@" ;;
  help|--help|-h)  show_help ;;
  *)               error "Unknown command: $CMD. Run 'blinder.sh help'." ;;
esac
