# Spec-Driven Development (SDD) — the process

> Flow: **discussion → spec (requirements → design → tasks) → approval → TDD →
> review.** No application code is written until decisions are locked and the
> spec is approved by a human.
>
> Features may be registered one at a time (`blinder.sh new`) or produced in a
> batch by the **Planner** from a larger initiative (see `prompts/roles/planner.md`
> + `roadmap.md`). Either way, each feature runs the per-feature flow below.

## Per-feature artifacts

Each feature with `"sdd": true` gets a folder `blinder/specs/<id>-<name>/`:

```
decisions.md      # Locked decisions table (D1..Dn) — produced in discussion
requirements.md   # WHAT — testable EARS requirements (R1..Rn)
design.md         # HOW  — files, signatures, alternatives; cites D<n>
tasks.md          # STEPS — ordered checklist (<id>-T1..Tn), each maps to R<n>
review.md         # Reviewer verdict + requirement→test traceability
```

## Feature states

| State | Meaning | Who advances it |
|-------|---------|-----------------|
| `pending` | No decisions yet | discussion (Leader) |
| `discussed` | Decisions locked; no spec yet | spec_author |
| `spec_ready` | Spec drafted; awaiting approval. **No code touched.** | human → Leader |
| `in_progress` | Approved; implementer working (TDD) | implementer |
| `implemented` | Code green; awaiting review | reviewer |
| `done` | Reviewer approved; history appended | reviewer |
| `blocked` | Stuck; reason in `current.md`/`feature_list.json` | human |
| `deferred` | Intentionally postponed; reason recorded | human |

## The two human touchpoints

1. **Discussion** (start): the Leader asks questions via `AskUserQuestion` and
   records answers in `decisions.md`. This is where ambiguity dies.
2. **Approval gate** (after `spec_ready`): the human reads the spec and says
   **"approved"** (or requests changes). Only then does implementation begin.

```
pending → [discussion] → discussed → [spec_author] → spec_ready
       → ⏸ HUMAN APPROVES → in_progress → [implementer] → implemented → [reviewer] → done
```

## TDD contract

`rules.tdd = true`. The implementer writes a **failing test first** for each task,
then the minimal code to pass it. The reviewer **adds** edge/negative/boundary
tests afterward. A feature cannot reach `done` with a red suite
(`rules.require_tests_to_close`).

## EARS quick reference (for `requirements.md`)

| Type | Template |
|------|----------|
| Ubiquitous | The `<system>` shall `<response>`. |
| Event-driven | When `<trigger>`, the `<system>` shall `<response>`. |
| State-driven | While `<state>`, the `<system>` shall `<response>`. |
| Unwanted | If `<condition>`, then the `<system>` shall `<response>`. |
| Optional | Where `<feature>`, the `<system>` shall `<response>`. |

Label requirements `R1, R2, …`; every `acceptance` item and every `D<n>` must map
to at least one `R<n>`, and every `R<n>` to at least one task.
