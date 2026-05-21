# 🧠 Blinder: Multi-Agent AI Harness Scaffolding

Blinder is a scaffolding system designed to supercharge AI-assisted development using native multi-agent orchestration. By generating configurations, entry points, and directory structures, it instructs **Claude Code** and **Antigravity CLI** to execute a structured, **Spec-Driven Development (SDD)** lifecycle using their native subagent engines.

> [!IMPORTANT]
> **Blinder is NOT a runtime engine.** It does not execute agent loops or call LLM APIs directly. Instead, it scaffolds project configurations and prompts that guide native AI clients (like Claude Code and Antigravity CLI) to orchestrate themselves using their native subagent systems.

---

## 🏗 Directory Architecture

Running Blinder in a project directory scaffolds the following multi-agent harness structure:

```text
<your-project>/
├── CLAUDE.md                          # Entrypoint for Claude Code (forces Leader role)
├── GEMINI.md                          # Entrypoint for Antigravity CLI (forces Leader role)
├── AGENTS.md                          # System-wide guide mapping agent roles & scopes
├── CHECKPOINTS.md                     # Objective acceptance & quality review criteria
├── feature_list.json                  # Single source of truth for features and statuses
├── init.sh                            # Language-aware environment/test verification script
│
├── .claude/
│   ├── settings.json                  # Pre-configured post-tool-use verification hooks
│   └── agents/
│       ├── leader.md                  # Claude Leader subagent prompt
│       ├── spec_author.md             # Claude Spec Author subagent prompt
│       ├── implementer.md             # Claude Implementer subagent prompt
│       └── reviewer.md                # Claude Reviewer subagent prompt
│
├── .gemini/
│   ├── settings.json                  # Antigravity CLI hook configurations
│   └── agents/
│       ├── leader.md                  # Antigravity Leader subagent prompt
│       ├── spec_author.md             # Antigravity Spec Author subagent prompt
│       ├── implementer.md             # Antigravity Implementer subagent prompt
│       └── reviewer.md                # Antigravity Reviewer subagent prompt
│
├── harness/
│   └── prompts/
│       └── roles/
│           ├── leader.md              # Shared, provider-agnostic Leader prompt
│           ├── spec_author.md         # Shared, provider-agnostic Spec Author prompt
│           ├── implementer.md         # Shared, provider-agnostic Implementer prompt
│           └── reviewer.md            # Shared, provider-agnostic Reviewer prompt
│
├── progress/
│   ├── current.md                     # Dynamic file tracking active session task execution
│   └── history.md                     # Append-only record of completed session activities
│
└── specs/                             # Feature-specific functional specs (EARS format)
```

---

## 🚀 Quickstart: Setting up a Project with Git

AI clients like Claude Code rely heavily on a active Git repository to calculate file diffs, track file history, and manage code updates safely. Thus, a Git repository **must** be initialized before running the harness.

### Step 1: Create a Project Directory
Create and enter the directory where you want to build your project:
```bash
mkdir my-awesome-app && cd my-awesome-app
```

### Step 2: Initialize the Git Repository
Initialize Git. **This step is mandatory** for the AI agents to function properly:
```bash
git init
```

### Step 3: Scaffold the Blinder Harness
Run the initialization command. Provide the absolute path to your [blinder.sh](file:///home/evrpg/Documents/projects/blinder/scripts/blinder.sh) CLI script:
```bash
/home/evrpg/Documents/projects/blinder/scripts/blinder.sh init
```

> [!TIP]
> To run the CLI more conveniently from anywhere, add an alias to your shell profile (e.g., `~/.bashrc` or `~/.zshrc`):
> ```bash
> alias blinder="/home/evrpg/Documents/projects/blinder/scripts/blinder.sh"
> ```
> After reloading your shell, you can simply run:
> ```bash
> blinder init
> ```

### Step 4: Make your Initial Git Commit
Commit the newly scaffolded Blinder files to establish a baseline in your Git history:
```bash
git add .
git commit -m "chore: scaffold Blinder multi-agent harness"
```

### Step 5: Start Coordinating Features
You are now ready to orchestrate development using your AI agents!
1. **Create a new feature request**:
   ```bash
   /home/evrpg/Documents/projects/blinder/scripts/blinder.sh new "User authentication system"
   ```
2. **Open your favorite AI CLI tool**:
   ```bash
   # Start Claude Code
   claude
   
   # Or start Antigravity CLI
   antigravity
   ```
3. **Instruct the agent to start**:
   Simply prompt:
   > "Implement the next pending feature from our feature list."

---

## 🛠 CLI Command Reference

The [blinder.sh](file:///home/evrpg/Documents/projects/blinder/scripts/blinder.sh) script coordinates features and manages states from your host terminal.

### `blinder.sh init`
Initializes the Blinder harness in the current working directory.
```bash
blinder.sh init [--name "custom-project-name"]
```
* **`--name`**: Optional. Sets the project name in `feature_list.json` (defaults to the current directory name).

### `blinder.sh new`
Registers a new feature requirement inside `feature_list.json` and assigns it a unique ID (e.g. `FR-0001`).
```bash
blinder.sh new "feature title" [options]
```
#### Options:
* **`--description "..."`**: Explicitly set the feature description.
* **`--acceptance "criteria 1, criteria 2"`**: Set comma-separated acceptance criteria.
* **`--sdd` / `--no-sdd`**: Toggle Spec-Driven Development flow (enabled by default).

*Note: If run in a TTY terminal without `--description` or `--acceptance` flags, the script prompts you interactively for these values.*

### `blinder.sh status`
Color-coded terminal overview of all registered features and their development states.
```bash
blinder.sh status
```

---

## 🔄 The Multi-Agent Workflow Lifecycle

When you boot the AI client, it reads [CLAUDE.md](file:///home/evrpg/Documents/projects/blinder/templates/docs/CLAUDE.md) or [GEMINI.md](file:///home/evrpg/Documents/projects/blinder/templates/docs/GEMINI.md) and assumes the **Leader** role. The system executes the following loop:

```text
               +-------------------------------------------+
               |                  Leader                   |
               | (Reads status, starts process, manages)   |
               +---------------------+---------------------+
                                     |
                                     v
                        +------------+------------+
                        |      Feature Pending?   |
                        +------------+------------+
                                     |
                                     v (Yes)
                       +-------------+-------------+
                       |        Spec Author        |
                       |  (Generates spec & task)  |
                       +-------------+-------------+
                                     |
                                     v
                       +-------------+-------------+
                       |    ⏸  Human Approval Gate  |
                       | (You approve the spec/task)|
                       +-------------+-------------+
                                     |
                                     v (Approved)
                       +-------------+-------------+
                       |        Implementer        |
                       | (Writes code & unit tests)|
                       +-------------+-------------+
                                     |
                                     v
                       +-------------+-------------+
                       |         Reviewer          |
                       | (Verifies design/checks)  |
                       +-------------+-------------+
                                     |
                 +-------------------+-------------------+
                 |                                       |
                 v (Pass)                                v (Fail)
           +-----+-----+                           +-----+-----+
           |   Done!   |                           | Re-route  |
           +-----------+                           +-----------+
```

### 1. Leader Role
- Checks `feature_list.json` for features requiring attention.
- Orchestrates subagent execution by spawning dedicated helper subagents.
- Manages dynamic state recording in [current.md](file:///home/evrpg/Documents/projects/blinder/templates/progress/current.md) and historical log recording in [history.md](file:///home/evrpg/Documents/projects/blinder/templates/progress/history.md).

### 2. Spec Author Role
- Gathers requirements and writes files in `specs/<feature_name>/`:
  - `requirements.md` (formulated using **EARS Notation**).
  - `design.md` (technical design outline).
  - `tasks.md` (granular, step-by-step TODO checklist).
- Marks the feature status as `spec_ready` and hands control back to the user.

### 3. Human Gate (Approval)
- You review the generated specs and task checklist.
- When satisfied, change the feature status in `feature_list.json` to `in_progress`.

### 4. Implementer Role
- Implements the feature iteratively matching the design and tasks.
- Writes corresponding unit and integration tests (TypeScript is highly preferred for target application code).
- Validates the implementation using the verification harness.

### 5. Reviewer Role
- Runs target test suites and checks overall code structure.
- Matches work against [CHECKPOINTS.md](file:///home/evrpg/Documents/projects/blinder/templates/docs/CHECKPOINTS.md) constraints.
- Marks status as `done` if checks pass, or rejects back to `implementer` if improvements are needed.

---

## 📝 Requirement Guidelines: EARS Notation

The **Spec Author** is instructed to enforce the **Easy Approach to Requirements Syntax (EARS)** format when writing functional requirements.

| Pattern Type | Syntax template | Example |
| :--- | :--- | :--- |
| **Ubiquitous** | The `<system>` shall `<behavior>` | The system shall maintain session states in memory. |
| **Event-driven** | **WHEN** `<event>` the `<system>` shall `<behavior>` | **WHEN** the user logs out, the system shall clear all session cookies. |
| **State-driven** | **WHILE** `<state>` the `<system>` shall `<behavior>` | **WHILE** the server is starting, the system shall show a loading indicator. |
| **Unwanted Behavior** | **IF** `<trigger>` **THEN** the `<system>` shall `<behavior>` | **IF** credentials are invalid, **THEN** the system shall display an error message. |
| **Optional Feature** | **WHERE** `<feature>` the `<system>` shall `<behavior>` | **WHERE** biometric login is supported, the system shall prompt for fingerprint scan. |

All requirements must also follow the format `FR-XXXX` where `XXXX` is a 4-digit zero-padded integer matching the feature's sequential index.

---

## 🔍 Validation Hook: `init.sh`

Every time the AI agent finishes executing a tool or command, native hooks in `.claude/settings.json` and `.gemini/settings.json` run the [init.sh](file:///home/evrpg/Documents/projects/blinder/templates/init.sh) validator script. This script:
1. Performs structural integrity checks to verify all expected Blinder files exist.
2. Validates `feature_list.json` syntax and ensures at most one feature is `in_progress` at any time.
3. Detects the project language stack (Node.js/TypeScript, Python, Rust, Go) and executes the appropriate test suite command. If tests fail, the harness prevents marking features as complete.
