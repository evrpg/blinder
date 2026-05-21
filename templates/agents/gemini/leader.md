---
name: leader
description: Orchestrator. Receives the main task, divides work and launches subagents. NEVER writes code directly.
kind: local
tools:
  - read_file
  - grep_search
  - list_dir
  - run_command
---
