# Spec-Driven Development (SDD) — the process

> Flow: **discussion → spec (requirements → design → tasks → tests) → approval →
> implement → review.** No application code is written until decisions are locked
> and the spec **and its tests** are approved by a human.
>
> Features may be registered one at a time (`blinder/cli.sh new`) or produced in a
> batch by the **Planner** from a larger initiative (see `prompts/roles/planner.md`
> + `roadmap.md`). Either way, each feature runs the per-feature flow below.

## Per-feature artifacts

Each feature with `"sdd": true` gets a folder `blinder/specs/<id>-<name>/`:

```
decisions.md      # Locked decisions table (D1..Dn) — produced in discussion
requirements.md   # WHAT — testable EARS requirements (R1..Rn)
design.md         # HOW  — files, public signatures, alternatives; cites D<n>
tasks.md          # STEPS — ordered checklist (<id>-T1..Tn); each maps to R<n> + its tests
review.md         # Reviewer verdict — code-vs-spec audit + traceability
```

Plus the **test files** themselves, written by `spec_author` in the project's test
location (per `conventions.md`) — they encode the requirements and start out red.

## Feature states

| State | Meaning | Who advances it |
|-------|---------|-----------------|
| `pending` | No decisions yet | discussion (Leader) |
| `discussed` | Decisions locked; no spec yet | spec_author |
| `spec_ready` | Spec **+ failing tests** drafted; awaiting approval. **No code touched.** | human → Leader |
| `in_progress` | Approved; implementer making the tests pass | implementer |
| `implemented` | Code green; awaiting review | reviewer |
| `done` | Reviewer approved; history appended | reviewer |
| `blocked` | Stuck; reason in `current.md`/`feature_list.json` | human |
| `deferred` | Intentionally postponed; reason recorded | human |

## The two human touchpoints

1. **Discussion** (start): the Leader asks questions via your interactive
   question tool (Claude Code: `AskUserQuestion`; OpenCode: its question tool —
   otherwise plain conversation) and records answers in `decisions.md`. This is
   where ambiguity dies.
2. **Approval gate** (after `spec_ready`): the human reads the spec **and the
   tests** and says **"approved"** (or requests changes). Only then does
   implementation begin.

```
pending → [discussion] → discussed → [spec_author: spec + tests] → spec_ready
       → ⏸ HUMAN APPROVES → in_progress → [implementer: make tests pass]
       → implemented → [reviewer: audit + harden] → done
```

## TDD contract

`rules.tdd = true`, but test authoring is **separated from implementation** so the
tests are an independent oracle:

- **`spec_author`** writes the failing test suite *with* the spec (before approval),
  so the human approves the tests too and they stay consistent with the requirements
  and `design.md` signatures.
- **`implementer`** only makes those tests pass — it **never edits them**; if a test
  looks wrong, it escalates to the Leader.
- **`reviewer`** audits the code against each `R<n>` directly (green tests are an
  input, not the verdict) and **adds** edge/negative/boundary tests.

A feature cannot reach `done` with a red suite (`rules.require_tests_to_close`).

**Fixes** (`--type fix`) follow a lighter version of the same idea: they skip
discussion, and `spec_author` writes `fix.md` (symptom + expected behavior) plus a
**failing regression test** instead of the full spec; the implementer makes that
test pass; the reviewer audits the change. Genuinely small, non-behavioral changes
skip the cycle entirely and are recorded with `blinder/cli.sh log` (the chore lane).
See `CLAUDE.md` "Classify the request first".

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
