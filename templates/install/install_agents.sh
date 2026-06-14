#!/usr/bin/env bash
# install_agents.sh — Install/update Blinder role prompts + Claude subagents.
#
# Single source of truth: templates/prompts/roles/*.md
#   - discussion.md  : main-thread role the Leader follows (no subagent frontmatter)
#   - spec_author.md : subagent (has Claude frontmatter)
#   - implementer.md : subagent (has Claude frontmatter)
#   - reviewer.md    : subagent (has Claude frontmatter)
#
# Subagent prompts are copied verbatim into .claude/agents/ (Claude Code reads
# frontmatter + body from there). All role prompts are also mirrored into
# blinder/prompts/roles/ so the harness is self-documenting and portable.

set -euo pipefail

TARGET_DIR="${1:-.}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BLINDER_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ROLES_DIR="$BLINDER_ROOT/templates/prompts/roles"

echo "Installing Claude subagents + role prompts into: $TARGET_DIR"

mkdir -p "$TARGET_DIR/.claude/agents"
mkdir -p "$TARGET_DIR/blinder/prompts/roles"

# Mirror every role prompt for reference/portability.
cp "$ROLES_DIR"/*.md "$TARGET_DIR/blinder/prompts/roles/"

# Install the three subagents Claude Code can dispatch.
for agent in spec_author implementer reviewer; do
  cp "$ROLES_DIR/$agent.md" "$TARGET_DIR/.claude/agents/$agent.md"
done

echo "Done. Subagents: spec_author, implementer, reviewer."
echo "Leader + discussion run on the main thread (see CLAUDE.md)."
