#!/usr/bin/env bash
# init.sh — Blinder verification harness (tiered).
#
#   bash blinder/init.sh            FAST  (default; also the PostToolUse hook)
#                                   structural checks + feature_list.json validity
#                                   + at-most-one in_progress + compile/typecheck.
#   bash blinder/init.sh --full     FAST + the full project test suite.
#                                   Run by the reviewer and before marking done.
#
# Fast is meant to take seconds. The expensive test suite is gated behind --full
# so editing stays cheap (time and tokens).

set -u

FULL=false
[ "${1:-}" = "--full" ] && FULL=true

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'; NC='\033[0m'
ok()   { printf "${GREEN}[OK]${NC}    %s\n" "$1"; }
fail() { printf "${RED}[FAIL]${NC}  %s\n" "$1"; }
warn() { printf "${YELLOW}[WARN]${NC}  %s\n" "$1"; }

EXIT_CODE=0

# ── PROJECT-SPECIFIC (edit me) ─────────────────────────────────────────────
# Fill these in once you know the real commands for THIS project. When set, a
# command OVERRIDES the generic auto-detection below — making the check exact and
# fast instead of guessed. Leave empty to keep auto-detection.
#
# Agents (implementer/reviewer): when you learn the project's true build/test
# command, set it here so every future run is precise. The harness gets sharper
# the more it is used.
#
#   PROJECT_COMPILE_CMD="./gradlew compileKotlin -q"
#   PROJECT_TEST_CMD="./gradlew test -q"
PROJECT_COMPILE_CMD=""   # runs on every check (fast tier)
PROJECT_TEST_CMD=""      # runs only with --full
# ───────────────────────────────────────────────────────────────────────────

# Detect Python by a manifest OR the presence of any .py source.
HAS_PYTHON=false
if [ -f "requirements.txt" ] || [ -f "pyproject.toml" ] || [ -f "setup.py" ] \
   || [ -n "$(find . -path ./.git -prune -o -name '*.py' -print -quit 2>/dev/null)" ]; then
  HAS_PYTHON=true
fi

echo "── 1. Harness files ───────────────────────────────────"
for f in AGENTS.md CLAUDE.md blinder/feature_list.json blinder/progress/current.md \
         blinder/docs/architecture.md blinder/docs/conventions.md blinder/docs/specs.md \
         blinder/docs/CHECKPOINTS.md; do
  if [ -f "$f" ]; then ok "exists $f"; else fail "missing $f"; EXIT_CODE=1; fi
done

echo ""
echo "── 2. feature_list.json ───────────────────────────────"
if command -v jq >/dev/null 2>&1; then
  if jq empty blinder/feature_list.json 2>/dev/null; then
    ok "valid JSON"
    IN_PROGRESS=$(jq '[.features[] | select(.status=="in_progress")] | length' blinder/feature_list.json)
    if [ "$IN_PROGRESS" -le 1 ]; then ok "at most 1 in_progress ($IN_PROGRESS)"
    else fail "multiple in_progress ($IN_PROGRESS) — only 1 allowed"; EXIT_CODE=1; fi
    # Every status must be from the allowed set.
    BAD=$(jq -r '.rules.valid_status as $v | [.features[] | select(.status as $s | ($v | index($s)) == null) | .id] | join(",")' blinder/feature_list.json)
    if [ -n "$BAD" ]; then fail "invalid status on: $BAD"; EXIT_CODE=1; fi

    # depends_on must reference existing feature IDs.
    UNKNOWN=$(jq -r '
      [.features[].id] as $ids
      | [ .features[] | .id as $fid | (.depends_on // [])[]
          | select(. as $d | ($ids | index($d)) == null) | "\($fid)->\(.)" ]
      | join(", ")' blinder/feature_list.json)
    if [ -n "$UNKNOWN" ]; then fail "unknown dependency references: $UNKNOWN"; EXIT_CODE=1; fi

    # depends_on graph must be acyclic (Kahn: remove satisfiable nodes to fixpoint).
    CYCLE=$(jq -r '
      def ready($ids): .done as $done
        | [ .rem[]
            | select((((.deps | map(select(. as $d | $ids | index($d)))) - $done) | length) == 0)
            | .id ];
      [.features[] | {id, deps: (.depends_on // [])}] as $nodes
      | [$nodes[].id] as $ids
      | {rem: $nodes, done: []}
      | until((ready($ids) | length) == 0;
          ready($ids) as $r
          | {rem: [.rem[] | select(.id as $i | ($r | index($i)) == null)],
             done: (.done + $r)})
      | .rem | map(.id) | join(", ")' blinder/feature_list.json)
    if [ -n "$CYCLE" ]; then fail "dependency cycle among: $CYCLE"; EXIT_CODE=1; fi
  else
    fail "feature_list.json is not valid JSON"; EXIT_CODE=1
  fi
else
  warn "jq not installed — cannot validate JSON"
  [ -f blinder/feature_list.json ] || { fail "feature_list.json missing"; EXIT_CODE=1; }
fi

echo ""
echo "── 3. Compile / typecheck ─────────────────────────────"
COMPILE_RAN=false
run() { echo "  \$ $*"; "$@"; }

# A project-specific command (when set) replaces all auto-detection below.
AUTO_COMPILE=true
if [ -n "$PROJECT_COMPILE_CMD" ]; then
  AUTO_COMPILE=false
  COMPILE_RAN=true
  echo "  \$ $PROJECT_COMPILE_CMD   (PROJECT_COMPILE_CMD)"
  if bash -c "$PROJECT_COMPILE_CMD"; then ok "project compile"; else fail "project compile"; EXIT_CODE=1; fi
fi

if $AUTO_COMPILE && [ -f "tsconfig.json" ]; then
  COMPILE_RAN=true
  if command -v npx >/dev/null 2>&1; then
    if run npx --no-install tsc --noEmit; then ok "tsc --noEmit"; else fail "tsc --noEmit"; EXIT_CODE=1; fi
  else warn "npx not found — skipping tsc"; fi
elif $AUTO_COMPILE && [ -f "package.json" ]; then
  COMPILE_RAN=true; ok "Node project (no tsconfig — no typecheck step)"
fi

if $AUTO_COMPILE && [ -f "Cargo.toml" ]; then
  COMPILE_RAN=true
  if run cargo check --quiet; then ok "cargo check"; else fail "cargo check"; EXIT_CODE=1; fi
fi

if $AUTO_COMPILE && [ -f "go.mod" ]; then
  COMPILE_RAN=true
  if run go build ./...; then ok "go build"; else fail "go build"; EXIT_CODE=1; fi
fi

if $AUTO_COMPILE && { [ -f "build.gradle" ] || [ -f "build.gradle.kts" ]; }; then
  COMPILE_RAN=true
  if [ -x "./gradlew" ]; then
    if run ./gradlew compileKotlin compileJava -q; then ok "gradle compile"; else fail "gradle compile"; EXIT_CODE=1; fi
  else warn "no ./gradlew wrapper — skipping compile"; fi
fi

if $AUTO_COMPILE && [ "$HAS_PYTHON" = true ]; then
  COMPILE_RAN=true
  if command -v ruff >/dev/null 2>&1; then
    if run ruff check .; then ok "ruff"; else fail "ruff"; EXIT_CODE=1; fi
  fi
  TARGET="."; [ -d "src" ] && TARGET="src"
  if run python3 -m compileall -q "$TARGET"; then ok "python compileall ($TARGET)"; else fail "python compile"; EXIT_CODE=1; fi
fi

if [ "$COMPILE_RAN" = false ]; then warn "no known toolchain detected — skipped compile/typecheck"; fi

if [ "$FULL" = true ]; then
  echo ""
  echo "── 4. Test suite (--full) ─────────────────────────────"
  TESTED=false

  # A project-specific command (when set) replaces all auto-detection below.
  AUTO_TEST=true
  if [ -n "$PROJECT_TEST_CMD" ]; then
    AUTO_TEST=false
    TESTED=true
    echo "  \$ $PROJECT_TEST_CMD   (PROJECT_TEST_CMD)"
    if bash -c "$PROJECT_TEST_CMD"; then ok "project tests"; else fail "project tests"; EXIT_CODE=1; fi
  fi

  if $AUTO_TEST && [ -f "package.json" ] && grep -q '"test"' package.json; then
    TESTED=true
    if run npm test --silent; then ok "npm test"; else fail "npm test"; EXIT_CODE=1; fi
  fi

  if $AUTO_TEST && [ "$HAS_PYTHON" = true ]; then
    TESTED=true
    if command -v pytest >/dev/null 2>&1; then
      if PYTHONPATH=. pytest -q; then ok "pytest"; else fail "pytest"; EXIT_CODE=1; fi
    else
      START="."; [ -d "tests" ] && START="tests"
      if PYTHONPATH=. python3 -m unittest discover -s "$START" -q; then ok "unittest ($START)"; else fail "unittest"; EXIT_CODE=1; fi
    fi
  fi

  if $AUTO_TEST && [ -f "Cargo.toml" ]; then
    TESTED=true
    if run cargo test --quiet; then ok "cargo test"; else fail "cargo test"; EXIT_CODE=1; fi
  fi

  if $AUTO_TEST && [ -f "go.mod" ]; then
    TESTED=true
    if run go test ./...; then ok "go test"; else fail "go test"; EXIT_CODE=1; fi
  fi

  if $AUTO_TEST && { [ -f "build.gradle" ] || [ -f "build.gradle.kts" ]; }; then
    TESTED=true
    if [ -x "./gradlew" ] && run ./gradlew test -q; then ok "gradle test"; else fail "gradle test"; EXIT_CODE=1; fi
  fi

  if [ "$TESTED" = false ]; then warn "no test runner detected — nothing to run"; fi
fi

echo ""
echo "── Summary ────────────────────────────────────────────"
if [ $EXIT_CODE -eq 0 ]; then
  ok "$([ "$FULL" = true ] && echo 'full' || echo 'fast') checks passed ✓"
else
  fail "checks failed ✗"
fi
exit $EXIT_CODE
