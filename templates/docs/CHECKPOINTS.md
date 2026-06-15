# CHECKPOINTS — Final-state evaluation

> In a multi-agent flow you evaluate the destination, not the journey. These are
> objective checks a human or the reviewer uses to decide a feature is healthy.

## C1 — Harness is intact

- [ ] Base files exist: `AGENTS.md`, `CLAUDE.md`, `blinder/init.sh`,
      `blinder/feature_list.json`, `blinder/progress/current.md`
- [ ] Project docs exist: `blinder/docs/architecture.md`, `blinder/docs/conventions.md`, `blinder/docs/specs.md`
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

- [ ] Changed files match `blinder/docs/architecture.md` (layers/structure)
- [ ] Changed files match `blinder/docs/conventions.md` (style/naming/errors)
- [ ] No stray debug prints or contextless TODOs

## C5 — Verification is real

- [ ] Every `R<n>` has at least one test that genuinely verifies it (authored by
      spec_author from the spec; see `review.md` traceability)
- [ ] The reviewer audited the code against each `R<n>` directly — green tests alone
      did not decide the verdict (see `review.md` implementation audit)
- [ ] Reviewer added edge/negative/boundary tests
- [ ] All tests pass under `blinder/init.sh --full`
