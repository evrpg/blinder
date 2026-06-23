#!/usr/bin/env bash
# install_agents.sh — Install/update Blinder role prompts + per-target subagents.
#
# Single source of truth: templates/prompts/roles/*.md (Claude-canonical frontmatter).
#   - discussion.md  : main-thread role the Leader follows (no subagent frontmatter)
#   - spec_author.md : subagent (Claude frontmatter — name/description/tools/model/effort)
#   - implementer.md : subagent (Claude frontmatter)
#   - reviewer.md    : subagent (Claude frontmatter)
#
# Role bodies are ALWAYS mirrored into blinder/prompts/roles/ (portable, self-documenting,
# target-agnostic). The per-target subagent shell is generated from those canonical files:
#   claude   → copied verbatim into .claude/agents/   (Claude reads frontmatter + body)
#   opencode → frontmatter transformed into .opencode/agents/ (see Phase 3)
#
# Usage: install_agents.sh [TARGET_DIR] [--agent "claude|opencode|both|claude opencode"]

set -euo pipefail

TARGET_DIR="."
AGENTS="claude"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --agent) AGENTS="$2"; shift 2 ;;
    -*) echo "install_agents.sh: unknown flag '$1'" >&2; exit 1 ;;
    *) TARGET_DIR="$1"; shift ;;
  esac
done
# Normalize "both" → the full set (callers may also pass the expanded set directly).
[ "$AGENTS" = "both" ] && AGENTS="claude opencode"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BLINDER_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ROLES_DIR="$BLINDER_ROOT/templates/prompts/roles"

agent_has() { case " $AGENTS " in *" $1 "*) return 0 ;; *) return 1 ;; esac; }

SUBAGENTS=(spec_author implementer reviewer)

echo "Installing role prompts + subagents into: $TARGET_DIR (agents: $AGENTS)"

# Mirror every role prompt for reference/portability (target-agnostic).
mkdir -p "$TARGET_DIR/blinder/prompts/roles"
cp "$ROLES_DIR"/*.md "$TARGET_DIR/blinder/prompts/roles/"

# claude: the canonical files ARE the Claude subagent format — copy verbatim.
install_claude_agents() {
  mkdir -p "$TARGET_DIR/.claude/agents"
  local agent
  for agent in "${SUBAGENTS[@]}"; do
    cp "$ROLES_DIR/$agent.md" "$TARGET_DIR/.claude/agents/$agent.md"
  done
  echo "  claude  → .claude/agents/: ${SUBAGENTS[*]}"
}

# opencode: transform the Claude-canonical frontmatter into .opencode/agents/*.md.
# Implemented in Phase 3 (drop model/effort, inject `mode: subagent`, map tools→permission).
install_opencode_agents() {
  echo "  opencode → .opencode/agents/: pending (emitter added in a later step)"
}

if agent_has claude;   then install_claude_agents; fi
if agent_has opencode; then install_opencode_agents; fi

echo "Leader + discussion run on the main thread (see blinder/docs/leader.md)."
