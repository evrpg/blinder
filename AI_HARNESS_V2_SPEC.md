# 🧠 AI Harness V2 Specification

## Overview

This document defines **V2 of the AI Harness**, evolving it into a **semi-autonomous, self-healing, multi-agent execution system**.

V2 transforms the harness from a manual orchestration workflow into a **deterministic execution engine** driven by state, not chat.

---

## Objectives

- Fully automated execution loop
- Deterministic state machine
- Self-healing (retry + fix)
- Provider-agnostic execution (Claude + Gemini)
- Strict disk-based operation
- Scalable multi-feature processing

---

## Core Architecture

### 1. Execution Loop (NEW)

The system is controlled by a **leader-driven loop**:

```
while true:
  leader reads STATE
  determines next action
  invokes correct agent
  agent writes output
  STATE updated
```

### Requirements
- Stateless agents
- Persistent state tracking
- Idempotent execution

---

### 2. State Machine (Enhanced)

Each work item progresses through:

```
queued
→ planned
→ specified
→ tests_written
→ implemented
→ reviewed
→ verified
→ done
```

Additional states:
- blocked
- retrying

---

### 3. Retry & Self-Healing Engine (NEW)

When failure occurs:

1. Detect failure source
2. Classify:
   - spec issue
   - implementation bug
   - test issue
3. Re-route to correct agent
4. Retry execution

---

### 4. Failure Classification

| Signal | Type |
|------|------|
| Test fails | implementation or spec |
| Compile error | implementation |
| Missing case | spec |
| Refactor issues | review |

---

### 5. Agent Routing Engine

The leader decides next agent based on:

- current state
- failure type
- completion signals

---

## Directory Extensions (V2)

```
harness/
  runtime/
    sessions/
    checkpoints/
  metrics/
    execution.log
    stats.json
```

---

## Execution Engine

### Bash Loop

File: scripts/loop.sh

Responsibilities:
- run loop continuously
- call agents
- update STATE
- handle retry logic

---

## Observability (NEW)

Track:
- execution count
- retry count
- success rate
- average completion time

Store in:

```
harness/metrics/stats.json
```

---

## Parallel Execution (Optional)

Allow multiple items:

- each item isolated in its directory
- shared STATE tracks all items

---

## Feature Dependencies (NEW)

QUEUE item extension:

```json
{
  "depends_on": ["FR-0001"]
}
```

Agent must not execute until dependencies complete.

---

## Provider Abstraction Layer (NEW)

Define unified interface:

```
execute(agent, input) -> output files
```

Adapters:
- Claude adapter
- Gemini adapter

---

## Agent Enhancements

New agents:
- test_writer
- refactor_agent
- failure_analyzer

---

## Persistence Model

Each step creates checkpoint:

```
harness/runtime/checkpoints/<timestamp>.json
```

Includes:
- state snapshot
- active agent
- outputs generated

---

## Security / Safety

- sandbox execution
- restrict file access to project
- validate generated commands

---

## Roadmap

### Phase 1
- loop engine
- retry system

### Phase 2
- observability
- provider abstraction

### Phase 3
- parallel execution
- advanced agents

---

## Success Criteria

System is successful when:

- no manual orchestration needed
- work resumes after interruption
- failures auto-recovered
- features complete end-to-end

---

## Final Vision

This evolves the harness into:

> A fully autonomous, deterministic AI development system

Where:
- state drives execution
- agents are interchangeable workers
- failures are self-healed

---

## Key Principle

"The system is the state machine, not the agents."
