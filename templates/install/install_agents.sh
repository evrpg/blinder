#!/usr/bin/env bash
# templates/install/install_agents.sh — Installs/updates agents in a project directory

set -euo pipefail

TARGET_DIR="${1:-.}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BLINDER_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

echo "Installing/updating agent files in: $TARGET_DIR"

# Dirs to create
mkdir -p "$TARGET_DIR/.claude/agents"
mkdir -p "$TARGET_DIR/.agents/agents"
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

# 3. Build Antigravity (Gemini) Agents (Compile Frontmatter + Shared Prompts into agent.json)
for agent in leader spec_author implementer reviewer; do
  # Initialize variables
  AGENT_NAME=""
  AGENT_DESC=""
  ENABLE_WRITE_TOOLS=false
  ENABLE_MCP_TOOLS=false
  ENABLE_SUBAGENT_TOOLS=false
  
  # Read frontmatter from GEMINI_TEMPLATES_DIR/$agent.md
  while IFS= read -r line; do
    if [[ "$line" =~ ^---$ ]]; then
      continue
    fi
    
    if [[ "$line" =~ ^name:[[:space:]]*(.*)$ ]]; then
      AGENT_NAME="${BASH_REMATCH[1]}"
    elif [[ "$line" =~ ^description:[[:space:]]*(.*)$ ]]; then
      AGENT_DESC="${BASH_REMATCH[1]}"
    elif [[ "$line" =~ ^enable_write_tools:[[:space:]]*(.*)$ ]]; then
      ENABLE_WRITE_TOOLS="${BASH_REMATCH[1]}"
    elif [[ "$line" =~ ^enable_mcp_tools:[[:space:]]*(.*)$ ]]; then
      ENABLE_MCP_TOOLS="${BASH_REMATCH[1]}"
    elif [[ "$line" =~ ^enable_subagent_tools:[[:space:]]*(.*)$ ]]; then
      ENABLE_SUBAGENT_TOOLS="${BASH_REMATCH[1]}"
    fi
  done < "$GEMINI_TEMPLATES_DIR/$agent.md"

  # Create individual agent subdirectory
  AGENT_SUBDIR="$TARGET_DIR/.agents/agents/$agent"
  mkdir -p "$AGENT_SUBDIR"
  
  # Compile agent.json
  jq -n \
    --arg name "$AGENT_NAME" \
    --arg desc "$AGENT_DESC" \
    --argjson enable_write_tools "$ENABLE_WRITE_TOOLS" \
    --argjson enable_mcp_tools "$ENABLE_MCP_TOOLS" \
    --argjson enable_subagent_tools "$ENABLE_SUBAGENT_TOOLS" \
    --rawfile system_prompt "$SHARED_TEMPLATES_DIR/$agent.md" \
    '{name: $name, description: $desc, system_prompt: $system_prompt, enable_write_tools: $enable_write_tools, enable_mcp_tools: $enable_mcp_tools, enable_subagent_tools: $enable_subagent_tools}' \
    > "$AGENT_SUBDIR/agent.json"
done

echo "Agent installation complete."
