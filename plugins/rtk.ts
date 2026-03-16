/**
 * RTK (Rust Token Killer) — OpenCode plugin adapter
 *
 * Intercepts bash/shell tool calls and rewrites commands through RTK's
 * filtering proxy to reduce LLM token consumption on system output.
 *
 * Flow:
 *   tool.execute.before → rtk rewrite "<cmd>" → mutate args.command
 *
 * RTK is a Rust CLI that knows which commands produce verbose output
 * (find, ls, git log, etc.) and wraps them to filter/summarize results.
 * All rewrite logic lives in the RTK binary — this plugin just delegates.
 */

import type { Plugin } from "@opencode-ai/plugin"

// ─── Configuration ───────────────────────────────────────────────────────────

const RTK_BIN = process.env.RTK_BIN ?? "rtk"

// ─── RTK Meta-Commands Reference ─────────────────────────────────────────────
// Injected into the system prompt so the agent knows about RTK diagnostics.

const RTK_INSTRUCTIONS = `## RTK (Rust Token Killer) — Meta-Commands

RTK is active and automatically rewrites verbose shell commands to save tokens.
These meta-commands are available for diagnostics:

- \`rtk gain\` — show token savings for current session
- \`rtk gain --history\` — show historical token savings across sessions
- \`rtk discover\` — find commands that could benefit from RTK filtering
- \`rtk proxy <cmd>\` — run a command through RTK without filtering (debugging)
`

// ─── Helpers ─────────────────────────────────────────────────────────────────

/** Check if a tool name corresponds to a bash/shell tool */
function isBashTool(toolName: string): boolean {
  const lower = toolName.toLowerCase()
  return lower.includes("bash") || lower.includes("shell")
}

/** Attempt to rewrite a command via RTK. Returns the rewritten command or null. */
function rtkRewrite(command: string): string | null {
  try {
    const result = Bun.spawnSync([RTK_BIN, "rewrite", command])
    if (result.exitCode !== 0) return null
    const rewritten = result.stdout?.toString().trim()
    if (!rewritten || rewritten === command) return null
    return rewritten
  } catch {
    return null
  }
}

// ─── Plugin Export ───────────────────────────────────────────────────────────

export const RTK: Plugin = async (_ctx) => {
  // Verify RTK binary is available at load time
  let rtkAvailable = false
  let rtkVersion = "unknown"

  try {
    const result = Bun.spawnSync([RTK_BIN, "--version"])
    if (result.exitCode === 0) {
      rtkAvailable = true
      rtkVersion = result.stdout?.toString().trim() ?? "unknown"
      console.log(`[rtk] initialized: ${rtkVersion}`)
    }
  } catch {
    // Binary not found
  }

  if (!rtkAvailable) {
    console.warn("[rtk] WARNING: rtk binary not found. Plugin disabled.")
    return {}
  }

  return {
    // ─── Tool Execution Hook: Rewrite Commands ─────────────────────

    "tool.execute.before": async (input, output) => {
      if (!isBashTool(input.tool)) return

      const command = output.args?.command
      if (!command || typeof command !== "string") return

      // Skip empty commands and commands already using rtk
      const trimmed = command.trim()
      if (!trimmed || trimmed.startsWith("rtk ")) return

      const rewritten = rtkRewrite(trimmed)
      if (rewritten) {
        output.args.command = rewritten
      }
    },

    // ─── System Prompt: RTK meta-commands reference ────────────────
    // Appends to the last system message to avoid multi-system-message
    // issues with some models (same pattern as engram.ts).

    "experimental.chat.system.transform": async (_input, output) => {
      if (output.system.length > 0) {
        output.system[output.system.length - 1] += "\n\n" + RTK_INSTRUCTIONS
      } else {
        output.system.push(RTK_INSTRUCTIONS)
      }
    },
  }
}

export default RTK
