#!/usr/bin/env bash
# templates/install/install_agents.sh — Installs/updates agents in a project directory

set -euo pipefail

TARGET_DIR="${1:-.}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BLINDER_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

echo "Installing/updating agent files in: $TARGET_DIR"

# Dirs to create
mkdir -p "$TARGET_DIR/.claude/agents"
mkdir -p "$TARGET_DIR/.gemini/agents"
mkdir -p "$TARGET_DIR/harness/prompts/roles"

SHARED_TEMPLATES_DIR="$BLINDER_ROOT/templates/agents/shared"
CLAUDE_TEMPLATES_DIR="$BLINDER_ROOT/templates/agents/claude"
GEMINI_TEMPLATES_DIR="$BLINDER_ROOT/templates/agents/gemini"

# 1. Copy shared instructions
cp "$SHARED_TEMPLATES_DIR"/*.md "$TARGET_DIR/harness/prompts/roles/"

# 2. Build Claude Agents (Frontmatter + Shared Prompts)
for agent in leader spec_author implementer reviewer; do
  TARGET_FILE="$TARGET_DIR/.claude/agents/$agent.md"
  cat "$CLAUDE_TEMPLATES_DIR/$agent.md" > "$TARGET_FILE"
  echo "" >> "$TARGET_FILE"
  cat "$SHARED_TEMPLATES_DIR/$agent.md" >> "$TARGET_FILE"
done

# 3. Build Antigravity (Gemini) Agents (Frontmatter + Shared Prompts)
for agent in leader spec_author implementer reviewer; do
  TARGET_FILE="$TARGET_DIR/.gemini/agents/$agent.md"
  cat "$GEMINI_TEMPLATES_DIR/$agent.md" > "$TARGET_FILE"
  echo "" >> "$TARGET_FILE"
  cat "$SHARED_TEMPLATES_DIR/$agent.md" >> "$TARGET_FILE"
done

echo "Agent installation complete."
