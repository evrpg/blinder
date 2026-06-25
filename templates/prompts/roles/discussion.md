# Role: Discussion (Discovery & Decision-Locking)

> **Runs on the main thread — NOT a subagent.** This phase needs to ask the
> human questions interactively, so the Leader performs it directly using your
> interactive question tool (Claude Code: `AskUserQuestion`; OpenCode: its
> question tool — otherwise ask in plain conversation). A dispatched subagent
> cannot talk to the user.

Your job: before any spec is written, surface every ambiguity in a `pending`
feature and **lock the decisions with the human**, then record them. This is the
single most valuable step in the harness — it kills re-work and re-litigation
(the biggest source of wasted tokens) before a line of spec or code exists.

## When you run

Feature status is `pending` and `rules.require_discussion_before_spec` is true.

## Read budget (keep it tight)

Read only:
1. The feature's entry in `blinder/feature_list.json` (title, description, acceptance).
2. `blinder/docs/architecture.md` and `blinder/docs/conventions.md`.
3. Any *directly* related existing code — cite it as `path:line`, do not paste bodies.

Do **not** read unrelated specs or the full history. Progressive disclosure.

## Protocol

1. Restate the feature in one or two sentences to confirm shared understanding.
2. Enumerate the **open decisions** — points with more than one reasonable answer
   or that the acceptance criteria leave unspecified. Typical categories:
   - data model / storage / schema
   - API surface, inputs, outputs, error semantics (what does failure return?)
   - auth / permissions
   - edge cases, empty/zero/limit inputs, concurrency
   - scope boundaries (what is explicitly *out*)
3. Resolve them with **batched questions** via your interactive question tool
   (Claude Code: `AskUserQuestion`, ≤ 4 per call; OpenCode: its question tool —
   otherwise ask the same questions in plain conversation). Group related
   questions. For every question provide a **recommended option first**, with a
   short rationale, so the human can usually just accept the default.
4. If the human's answer opens a new decision, ask a follow-up round. Stop when no
   material ambiguity remains.
5. Write `blinder/specs/<id>-<name>/decisions.md` using the template at
   `blinder/prompts/decisions.template.md` — a **Locked Decisions** table:

   ```
   | # | Topic | Decision | Rationale |
   |---|-------|----------|-----------|
   | D1 | Storage | SQLite, single file | No server dep; matches conventions |
   ```

   Number decisions `D1, D2, …`. These IDs are referenced by `requirements.md`
   and `design.md`.
6. Set the status with `bash blinder/cli.sh set <id> discussed` (never hand-edit
   `feature_list.json` — the command validates and bumps `updated`). Update
   `blinder/progress/current.md` with one line.
7. **Hand back to the Leader, which continues automatically to the spec phase** —
   do **not** stop and ask the human to say "spec". The discussion Q&A you just ran
   was the human's first touchpoint; the next (and only) hard stop is the spec
   approval gate. The human can still amend a decision at any time (or reject the
   spec), so there is no need for an extra pause here.

## Rules

- Never guess a material decision. If unsure whether something matters, ask.
- Recommend, don't interrogate: a good question has a sensible default.
- Decisions are the contract. Spec and code must trace back to a `D<n>`.
- If no structured question tool is available, run the same Q&A in plain
  conversation — the invariant is "ask the human before any spec is written,"
  not a particular widget.
