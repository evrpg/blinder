import type { Plugin } from "@opencode-ai/plugin"

/**
 * Blinder fast verification — the OpenCode counterpart of the Claude Code
 * `PostToolUse` hook (.claude/settings.json). After an edit/write tool runs, it
 * fires the FAST tier of blinder/init.sh (structural checks + feature_list.json
 * validity + at-most-one in_progress + compile/typecheck). The verification
 * *content* lives in blinder/init.sh, so both front-ends share one verifier; this
 * plugin only triggers it. The expensive suite stays gated behind `--full`.
 *
 * Requires the Bun runtime (OpenCode provides it; `$` is Bun's shell). The
 * `import type` is erased at runtime, so no package install is needed to run.
 */
export const BlinderVerify: Plugin = async ({ $ }) => {
  return {
    "tool.execute.after": async (input: { tool: string }) => {
      if (input.tool === "edit" || input.tool === "write") {
        // .nothrow(): a failing check must surface its output, not crash the plugin.
        await $`bash blinder/init.sh`.nothrow()
      }
    },
  }
}
