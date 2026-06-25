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

# Transform a Claude-canonical subagent .md into OpenCode format on stdout:
#   - drop `name:` (OpenCode derives the id from the filename)
#   - drop `model:` and `effort:` from the *source* — but if the *existing target*
#     file already has them (user set them), preserve those values (project-owned,
#     never overwritten — same pattern as verify.env).
#   - inject `mode: subagent`
#   - map the Claude `tools:` ALLOWLIST into a `permission:` block (the modern field;
#     `tools:` is deprecated): a capability is `allow` iff its Claude tool is listed,
#     else `deny`. Read-type tools (read/grep/glob/list) stay at OpenCode's default
#     allow. We gate the meaningful ones: edit (file writes), bash, webfetch, websearch.
#   - keep the prompt body verbatim.
#
# Usage: opencode_transform <src.md> [existing-target.md]
opencode_transform() {
  local src="$1" existing="${2:-}"
  local pmodel="" peffort="" pvariant=""
  if [ -f "$existing" ]; then
    pmodel=$(awk   'f==1 && /^model:/   {sub(/^model:[ \t]*/,"");   print; exit} /^---/{f++}' "$existing")
    peffort=$(awk  'f==1 && /^effort:/  {sub(/^effort:[ \t]*/,"");  print; exit} /^---/{f++}' "$existing")
    pvariant=$(awk 'f==1 && /^variant:/ {sub(/^variant:[ \t]*/,""); print; exit} /^---/{f++}' "$existing")
  fi
  awk -v pmodel="$pmodel" -v peffort="$peffort" -v pvariant="$pvariant" '
    NR==1 && $0=="---" { infm=1; next }
    infm && $0=="---" {
      infm=0
      editp = (tools ~ /(^|[, ])(Edit|Write)([, ]|$)/) ? "allow" : "deny"
      bashp = (tools ~ /(^|[, ])Bash([, ]|$)/)         ? "allow" : "deny"
      wfp   = (tools ~ /(^|[, ])WebFetch([, ]|$)/)     ? "allow" : "deny"
      wsp   = (tools ~ /(^|[, ])WebSearch([, ]|$)/)    ? "allow" : "deny"
      print "---"
      print "description: " desc
      print "mode: subagent"
      if (pmodel   != "") print "model: "   pmodel
      if (peffort  != "") print "effort: "  peffort
      if (pvariant != "") print "variant: " pvariant
      print "permission:"
      print "  edit: " editp
      print "  bash: " bashp
      print "  webfetch: " wfp
      print "  websearch: " wsp
      print "---"
      next
    }
    infm {
      if ($0 ~ /^description:[ \t]*/) { d=$0; sub(/^description:[ \t]*/,"",d); desc=d }
      if ($0 ~ /^tools:[ \t]*/)       { t=$0; sub(/^tools:[ \t]*/,"",t);       tools=t }
      next
    }
    { print }
  ' "$src"
}

# opencode: emit the transformed subagents into .opencode/agents/ (id = filename).
install_opencode_agents() {
  mkdir -p "$TARGET_DIR/.opencode/agents"
  local agent tgt
  for agent in "${SUBAGENTS[@]}"; do
    tgt="$TARGET_DIR/.opencode/agents/$agent.md"
    opencode_transform "$ROLES_DIR/$agent.md" "$tgt" > "$tgt.tmp" && mv "$tgt.tmp" "$tgt"
  done
  echo "  opencode → .opencode/agents/: ${SUBAGENTS[*]} (model/effort preserved if set; tools→permission)"
}

if agent_has claude;   then install_claude_agents; fi
if agent_has opencode; then install_opencode_agents; fi

echo "Leader + discussion run on the main thread (see blinder/docs/leader.md)."
