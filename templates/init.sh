#!/usr/bin/env bash
# init.sh — Environment verification (Language-aware)
# Run this at the start of every session and before marking any feature as done.

set -u
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

ok()   { printf "${GREEN}[OK]${NC}    %s\n" "$1"; }
fail() { printf "${RED}[FAIL]${NC}  %s\n" "$1"; }
warn() { printf "${YELLOW}[WARN]${NC}  %s\n" "$1"; }

EXIT_CODE=0

echo "── 1. Verifying harness files ─────────────────────────"

for f in AGENTS.md feature_list.json progress/current.md docs/architecture.md docs/conventions.md docs/specs.md CHECKPOINTS.md; do
  if [ ! -f "$f" ]; then
    fail "Missing base file: $f"
    EXIT_CODE=1
  else
    ok "Exists $f"
  fi
done

echo ""
echo "── 2. Validating feature_list.json ─────────────────────"

if command -v jq > /dev/null 2>&1; then
  if jq empty feature_list.json 2>/dev/null; then
    ok "feature_list.json is valid JSON"
    # Check at most one in_progress
    IN_PROGRESS=$(jq '[.features[] | select(.status == "in_progress")] | length' feature_list.json)
    if [ "$IN_PROGRESS" -le 1 ]; then
      ok "At most 1 feature in_progress ($IN_PROGRESS)"
    else
      fail "Multiple features in_progress ($IN_PROGRESS) — only 1 allowed"
      EXIT_CODE=1
    fi
  else
    fail "feature_list.json is not valid JSON"
    EXIT_CODE=1
  fi
else
  warn "jq not installed — checking if file exists but cannot validate JSON schema"
  if [ -f feature_list.json ]; then
    ok "feature_list.json exists"
  else
    fail "feature_list.json is missing"
    EXIT_CODE=1
  fi
fi

echo ""
echo "── 3. Detecting Project Language & Running Tests ──────"

TEST_RUNNER_FOUND=false

if [ -f "package.json" ]; then
  ok "Detected Node.js project (package.json)"
  TEST_RUNNER_FOUND=true
  if grep -q '"test"' package.json; then
    echo "Running 'npm test'..."
    if npm test; then
      ok "npm test passed"
    else
      fail "npm test failed"
      EXIT_CODE=1
    fi
  else
    warn "No test script found in package.json"
  fi
fi

if [ -f "requirements.txt" ] || [ -f "pyproject.toml" ] || [ -f "setup.py" ]; then
  ok "Detected Python project"
  TEST_RUNNER_FOUND=true

  # Determine if a virtual environment already exists, or where to create it
  VENV_DIR=""
  if [ -d ".venv" ]; then
    VENV_DIR=".venv"
  elif [ -d "venv" ]; then
    VENV_DIR="venv"
  fi

  if [ -z "$VENV_DIR" ]; then
    echo "Creating virtual environment (.venv)..."
    python3 -m venv .venv || python3 -m venv --without-pip .venv || { fail "venv creation failed"; exit 1; }
    VENV_DIR=".venv"
  fi

  # Activate virtual environment
  source "$VENV_DIR/bin/activate"

  # Ensure pip is available inside the venv
  if ! command -v pip >/dev/null 2>&1; then
    echo "Installing pip..."
    curl -sS https://bootstrap.pypa.io/get-pip.py | python || { fail "pip install failed"; exit 1; }
  fi

  # Only install dependencies if requirements.txt has changed or venv is brand new
  if [ -f "requirements.txt" ]; then
    if [ ! -f "$VENV_DIR/.pip_installed" ] || [ "requirements.txt" -nt "$VENV_DIR/.pip_installed" ]; then
      echo "Installing/updating dependencies from requirements.txt..."
      if pip install -r requirements.txt; then
        touch "$VENV_DIR/.pip_installed"
      else
        fail "requirements install failed"
        EXIT_CODE=1
      fi
    fi
  fi

  # Execute pytest or unittest with pythonpath set
  if command -v pytest > /dev/null 2>&1; then
    echo "Running 'pytest'..."
    if PYTHONPATH=. pytest; then
      ok "pytest passed"
    else
      fail "pytest failed"
      EXIT_CODE=1
    fi
  elif [ -f "manage.py" ]; then
    echo "Running 'python manage.py test'..."
    if python manage.py test; then
      ok "django test passed"
    else
      fail "django test failed"
      EXIT_CODE=1
    fi
  else
    echo "Running 'python -m unittest discover'..."
    if PYTHONPATH=. python -m unittest discover; then
      ok "unittest passed"
    else
      fail "unittest failed"
      EXIT_CODE=1
    fi
  fi
fi

if [ -f "Cargo.toml" ]; then
  ok "Detected Rust project (Cargo.toml)"
  TEST_RUNNER_FOUND=true
  echo "Running 'cargo test'..."
  if cargo test; then
    ok "cargo test passed"
  else
    fail "cargo test failed"
    EXIT_CODE=1
  fi
fi

if [ -f "go.mod" ]; then
  ok "Detected Go project (go.mod)"
  TEST_RUNNER_FOUND=true
  echo "Running 'go test ./...'..."
  if go test ./...; then
    ok "go test passed"
  else
    fail "go test failed"
    EXIT_CODE=1
  fi
fi

if [ "$TEST_RUNNER_FOUND" = false ]; then
  warn "No known project/test files found (package.json, pyproject.toml, Cargo.toml, go.mod). Skipping project-specific tests."
fi

echo ""
echo "── 4. Summary ──────────────────────────────────────────"

if [ $EXIT_CODE -eq 0 ]; then
  ok "All checks passed ✓"
else
  fail "Some checks failed ✗"
fi

exit $EXIT_CODE
