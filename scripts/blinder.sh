#!/usr/bin/env bash
# blinder.sh — Custom AI Agent Harness CLI

set -euo pipefail

# Find script directory and root directory of blinder installation
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BLINDER_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors
RED=$'\e[0;31m'
GREEN=$'\e[0;32m'
YELLOW=$'\e[0;33m'
BLUE=$'\e[0;34m'
CYAN=$'\e[0;36m'
NC=$'\e[0m'

# Logger helpers
info()  { printf "${BLUE}[INFO]${NC}  %s\n" "$1"; }
ok()    { printf "${GREEN}[OK]${NC}    %s\n" "$1"; }
warn()  { printf "${YELLOW}[WARN]${NC}  %s\n" "$1"; }
error() { printf "${RED}[ERROR]${NC} %s\n" "$1"; exit 1; }

show_help() {
  cat <<EOF
Blinder — Custom AI Agent Harness CLI

Usage:
  blinder.sh init [--name "project-name"]
  blinder.sh new "feature title" [--no-sdd]
  blinder.sh status
  blinder.sh help

Commands:
  init      Scaffold the full harness structure into the current directory.
  new       Add a new feature to feature_list.json.
  status    Pretty-print the status of all features.
  help      Show this help message.
EOF
}

cmd_init() {
  PROJECT_NAME=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --name)
        PROJECT_NAME="$2"
        shift 2
        ;;
      *)
        error "Unknown argument: $1"
        ;;
    esac
  done

  if [ -z "$PROJECT_NAME" ]; then
    PROJECT_NAME="$(basename "$(pwd)")"
  fi

  if [ -f "feature_list.json" ]; then
    error "feature_list.json already exists! Aborting to prevent overwrite."
  fi

  info "Initializing Blinder harness for project: $PROJECT_NAME"

  # Create directories
  mkdir -p .claude/agents
  mkdir -p .agents/agents
  mkdir -p harness/prompts/roles
  mkdir -p progress
  mkdir -p specs
  mkdir -p docs

  # Copy docs and templates
  cp "$BLINDER_ROOT/templates/docs/CLAUDE.md" "./CLAUDE.md"
  cp "$BLINDER_ROOT/templates/docs/GEMINI.md" "./GEMINI.md"
  cp "$BLINDER_ROOT/templates/docs/AGENTS.md" "./AGENTS.md"
  cp "$BLINDER_ROOT/templates/docs/CHECKPOINTS.md" "./CHECKPOINTS.md"
  cp "$BLINDER_ROOT/templates/docs/specs.md" "./docs/specs.md"
  cp "$BLINDER_ROOT/templates/docs/architecture.md" "./docs/architecture.md"
  cp "$BLINDER_ROOT/templates/docs/conventions.md" "./docs/conventions.md"
  cp "$BLINDER_ROOT/templates/progress/current.md" "./progress/current.md"
  cp "$BLINDER_ROOT/templates/progress/history.md" "./progress/history.md"
  cp "$BLINDER_ROOT/templates/config/claude_settings.json" "./.claude/settings.json"
  cp "$BLINDER_ROOT/templates/config/gemini_settings.json" "./.agents/settings.json"
  cp "$BLINDER_ROOT/templates/init.sh" "./init.sh"

  chmod +x "./init.sh"

  # Write customized feature_list.json
  jq --arg name "$PROJECT_NAME" '.project = $name' "$BLINDER_ROOT/templates/config/feature_list.json" > "feature_list.json"

  # Install agents using install_agents.sh helper
  bash "$BLINDER_ROOT/templates/install/install_agents.sh" "."

  ok "Blinder harness initialized successfully!"
  info "Next steps:"
  echo "  1. Review AGENTS.md for the agent layout."
  echo "  2. Run ./init.sh to verify the environment."
  echo "  3. Add a new feature with: blinder.sh new \"My feature\""
}

cmd_new() {
  if [ ! -f "feature_list.json" ]; then
    error "feature_list.json not found. Please run 'blinder.sh init' first."
  fi

  if [ $# -lt 1 ]; then
    error "Missing feature title. Usage: blinder.sh new \"feature title\""
  fi

  TITLE="$1"
  shift

  SDD=true
  DESC=""
  ACCEPTANCE_RAW=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --no-sdd)
        SDD=false
        shift
        ;;
      --sdd)
        SDD=true
        shift
        ;;
      --description)
        DESC="$2"
        shift 2
        ;;
      --acceptance)
        ACCEPTANCE_RAW="$2"
        shift 2
        ;;
      *)
        error "Unknown argument: $1"
        ;;
    esac
  done

  # Generate next ID FR-XXXX
  MAX_NUM=$(jq '.features[].id' feature_list.json 2>/dev/null | grep -oE '[0-9]+' | sort -n | tail -1 || true)
  if [ -z "$MAX_NUM" ]; then
    NEXT_NUM=1
  else
    NEXT_NUM=$((MAX_NUM + 1))
  fi
  ID=$(printf "FR-%04d" $NEXT_NUM)
  NAME=$(echo "$TITLE" | tr '[:upper:]' '[:lower:]' | tr ' ' '_')

  ACCEPTANCE_JSON="[]"
  if [ -n "$ACCEPTANCE_RAW" ]; then
    # Parse comma separated into JSON array
    IFS=',' read -ra ADDR <<< "$ACCEPTANCE_RAW"
    for item in "${ADDR[@]}"; do
      # strip leading/trailing whitespace
      item=$(echo "$item" | xargs)
      ACCEPTANCE_JSON=$(echo "$ACCEPTANCE_JSON" | jq --arg item "$item" '. += [$item]')
    done
  fi

  # Interactive prompt if stdin is a TTY and we don't have description/acceptance from arguments
  if [ -t 0 ] && [ -t 1 ] && [ -z "$DESC" ] && [ -z "$ACCEPTANCE_RAW" ]; then
    echo -n "Enter feature description: "
    read -r DESC
    echo "Enter acceptance criteria (one per line, press enter on empty line to finish):"
    while true; do
      echo -n "- "
      read -r LINE
      if [ -z "$LINE" ]; then
        break
      fi
      ACCEPTANCE_JSON=$(echo "$ACCEPTANCE_JSON" | jq --arg item "$LINE" '. += [$item]')
    done
  fi

  # Fallback for non-interactive or empty values
  if [ -z "$DESC" ]; then
    DESC="Implement $TITLE"
  fi
  if [ "$ACCEPTANCE_JSON" = "[]" ]; then
    ACCEPTANCE_JSON="[\"Verify $TITLE is fully implemented and tested.\"]"
  fi

  # Create the feature object
  NEW_FEATURE=$(jq -n \
    --arg id "$ID" \
    --arg name "$NAME" \
    --arg title "$TITLE" \
    --arg desc "$DESC" \
    --argjson sdd "$SDD" \
    --argjson acceptance "$ACCEPTANCE_JSON" \
    '{id: $id, name: $name, title: $title, description: $desc, sdd: $sdd, acceptance: $acceptance, status: "pending"}')

  # Append to feature_list.json
  TMP_FILE=$(mktemp)
  jq --argjson new_feat "$NEW_FEATURE" '.features += [$new_feat]' feature_list.json > "$TMP_FILE"
  mv "$TMP_FILE" feature_list.json

  ok "Created new feature: $ID ($TITLE)"
  info "Feature details added to feature_list.json"
}

cmd_status() {
  if [ ! -f "feature_list.json" ]; then
    error "feature_list.json not found. Please run 'blinder.sh init' first."
  fi

  PROJECT_NAME=$(jq -r '.project' feature_list.json)
  echo -e "Project: ${GREEN}$PROJECT_NAME${NC}"
  echo -e "--------------------------------------------------------------------------------"
  printf "%-10s | %-12s | %-4s | %-45s\n" "ID" "STATUS" "SDD" "TITLE"
  echo -e "--------------------------------------------------------------------------------"

  jq -c '.features[]' feature_list.json | while read -r feat; do
    FID=$(echo "$feat" | jq -r '.id')
    FSTATUS=$(echo "$feat" | jq -r '.status')
    FSDD=$(echo "$feat" | jq -r '.sdd')
    FTITLE=$(echo "$feat" | jq -r '.title')

    # Colorize status
    case "$FSTATUS" in
      pending)
        STATUS_COL="${YELLOW}pending${NC}"
        ;;
      spec_ready)
        STATUS_COL="${BLUE}spec_ready${NC}"
        ;;
      in_progress)
        STATUS_COL="${CYAN}in_progress${NC}"
        ;;
      done)
        STATUS_COL="${GREEN}done${NC}"
        ;;
      blocked)
        STATUS_COL="${RED}blocked${NC}"
        ;;
      *)
        STATUS_COL="$FSTATUS"
        ;;
    esac

    printf "%-10s | %-21s | %-4s | %-45s\n" "$FID" "$STATUS_COL" "$FSDD" "$FTITLE"
  done
  echo -e "--------------------------------------------------------------------------------"
}

# Command router
if [ $# -lt 1 ]; then
  show_help
  exit 1
fi

CMD=$1
shift

case "$CMD" in
  init)
    cmd_init "$@"
    ;;
  new)
    cmd_new "$@"
    ;;
  status)
    cmd_status
    ;;
  help|--help|-h)
    show_help
    ;;
  *)
    error "Unknown command: $CMD. Run 'blinder.sh help' for usage."
    ;;
esac
