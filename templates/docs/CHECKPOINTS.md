# CHECKPOINTS — Final-state evaluation

> In a multi-agent flow you evaluate the destination, not the journey. These are
> objective checks a human or the reviewer uses to decide a feature is healthy.

## C1 — Harness is intact

- [ ] Base files exist: `AGENTS.md`, `CLAUDE.md`, `blinder/init.sh`,
      `blinder/feature_list.json`, `blinder/progress/current.md`
- [ ] Project docs exist: `docs/architecture.md`, `docs/conventions.md`, `docs/specs.md`
- [ ] `bash blinder/init.sh --full` exits 0

## C2 — State is coherent

- [ ] At most one feature is `in_progress`
- [ ] The feature under review has all four spec files + `decisions.md`
- [ ] `blinder/progress/current.md` describes the active session (or is idle)
- [ ] Any `blocked`/`deferred` feature has a recorded reason

## C3 — Decisions were honored

- [ ] Every locked `D<n>` in `decisions.md` is reflected by a requirement or design choice
- [ ] No silent scope added beyond the spec

## C4 — Code respects architecture & conventions

- [ ] Changed files match `docs/architecture.md` (layers/structure)
- [ ] Changed files match `docs/conventions.md` (style/naming/errors)
- [ ] No stray debug prints or contextless TODOs

## C5 — Verification is real (TDD)

- [ ] Every `R<n>` has at least one traceable test (see `review.md`)
- [ ] Reviewer added edge/negative/boundary tests
- [ ] All tests pass under `blinder/init.sh --full`
