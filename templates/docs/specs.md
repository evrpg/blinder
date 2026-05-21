# Spec Driven Development (SDD)

> This project follows a Kiro-style flow: requirements → design → tasks → code.
> Code is NOT written until the spec is approved by a human.

## Structure

Each new feature (`"sdd": true` in `feature_list.json`) has a dedicated folder:

```
specs/<feature-name>/
├── requirements.md   # WHAT is needed (testable acceptance criteria)
├── design.md         # HOW it will be built (technical decisions)
└── tasks.md          # STEPS to implement (ordered checklist)
```

## Feature states

| State         | Meaning                                                     |
|---------------|-------------------------------------------------------------|
| `pending`     | No spec yet. `spec_author` acts first.                      |
| `spec_ready`  | Spec drafted. Awaiting human approval. NO code is touched.  |
| `in_progress` | Spec approved. `implementer` is working.                    |
| `done`        | Code green, `reviewer` approved, session closed.            |
| `blocked`     | Stuck. Reason documented in `progress/current.md`.          |

## Human approval gate

The automated flow stops **once**: when `spec_author` finishes the three
files, marks the feature as `spec_ready`, and stops. The human reads
`specs/<feature>/` and says "approved" (or requests changes).

Only then does the `leader` transition `spec_ready → in_progress` and
launch the `implementer`.

```
pending → [spec_author] → spec_ready → ⏸ HUMAN → in_progress → [implementer → reviewer] → done
```
