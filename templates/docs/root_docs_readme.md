# docs/ — your project's documentation space

> This folder is **yours**. The harness's own reference docs live in
> `blinder/docs/` (architecture, conventions, the SDD process, checkpoints).

The source of truth for this project is **code + tests + `blinder/specs/` +
`blinder/feature_list.json`** — never a doc here. So documents in this folder are
**not kept in sync** and fall into two kinds:

- **Seeds** — design material captured from a conversation (an upfront design chat,
  or a big idea that came up mid-project) and used to spin up features. Point-in-time
  input; once the features exist it has served its purpose.
- **Snapshots** — docs generated on demand from the *current* code/specs ("describe
  the payment flow", "an API integrator guide"). Don't maintain them — regenerate
  when you next need one.

To avoid mistaking an old doc for current truth, start each file with a provenance
line, e.g.:

```
> Seed (design input), <date> — point-in-time; not maintained. Truth: code + blinder/specs/.
> Snapshot generated <date> from <FR ids/state>. Regenerate rather than edit.
```
