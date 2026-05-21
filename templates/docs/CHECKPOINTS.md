# CHECKPOINTS — Final state evaluation

> In multi-agent systems you don't evaluate the journey, you evaluate the
> destination. These are objective checkpoints a judge (human or AI) can use
> to decide if the project is healthy.

## C1 — The harness is complete

- [ ] All base files exist: `AGENTS.md`, `init.sh`, `feature_list.json`,
      `progress/current.md`
- [ ] All docs exist: `docs/architecture.md`, `docs/conventions.md`,
      `docs/specs.md`
- [ ] `./init.sh` exits with code 0

## C2 — State is coherent

- [ ] At most one feature is `in_progress` in `feature_list.json`
- [ ] Every `done` feature has associated tests that pass
- [ ] `progress/current.md` is empty or describes the active session

## C3 — Code respects architecture

- [ ] `src/` only contains modules described in `docs/architecture.md`
- [ ] No stray debug prints or contextless TODOs

## C4 — Verification is real

- [ ] `tests/` has at least one test per `done` feature
- [ ] All tests pass when running the project's test command
- [ ] Every `R<n>` from specs has a traceable test
