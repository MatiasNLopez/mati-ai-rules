/**
 * Tool Definition Compressor — OpenCode plugin
 *
 * Reduces token consumption by stripping "grease" (filler text) from tool
 * definitions before they reach the LLM. Three layers of cleaning:
 *
 *   1. Generic regex replacements — removes common filler patterns
 *   2. Dedup with system prompt — strips content already injected by other plugins
 *   3. Parameter description cleanup — removes redundant param descriptions
 *
 * Flow:
 *   tool.definition hook → compress description → compress parameters → LLM
 */

import type { Plugin } from "@opencode-ai/plugin"

// ─── Layer 1: Generic Regex Replacements ─────────────────────────────────────
// Applied IN ORDER to every tool description. Each pattern targets a specific
// category of filler text that adds tokens without adding information.

const REGEX_REPLACEMENTS: [RegExp, string][] = [
  // Strip "Use this to/for:" multi-line blocks with bullet lists
  [/\n\nUse this (?:to|for):?\n(?:- [^\n]+\n?)+/gi, ""],

  // Strip "Use this to/when/for..." single sentences (but NOT "Use after X" which carries sequencing info)
  [/\s*Use this (?:to|when you need to|for) [^.]+\./g, ""],

  // Strip "persistent memory" → "memory"
  [/\bpersistent memory\b/gi, "memory"],

  // Strip "coding session(s)" → "session(s)"
  [/\bcoding sessions?\b/gi, (m: string) => m.replace(/coding /i, "")],

  // Strip "from previous (coding) sessions"
  [/\s*from previous (?:coding )?sessions/gi, ""],

  // Strip "so future sessions have context about..." filler
  [/\s*so future sessions have context about[^.]+\./gi, ""],

  // Strip "Call this at the beginning/when..." restatements
  [/\s*Call this (?:at the beginning of|when) [^.]+\./gi, ""],

  // Strip "This is the progressive disclosure pattern..." explanatory filler
  [/\s*This is the progressive disclosure pattern[^.]*\./gi, ""],

  // Strip "Duplicates are automatically detected and skipped..."
  [/\s*Duplicates are automatically[^.]+\./gi, ""],

  // Compress "your persistent memory" → "memory" (possessive variant)
  [/\byour (?:persistent )?memory\b/gi, "memory"],

  // Strip "or any context from previous..." catch-all filler
  [/,?\s*or any context from previous[^.]*\b/gi, ""],

  // Normalize multiple spaces/newlines left by removals
  [/\n{3,}/g, "\n\n"],
  [/ {2,}/g, " "],
]

function applyRegexCompressions(description: string): string {
  let result = description
  for (const [regex, replacement] of REGEX_REPLACEMENTS) {
    result = result.replace(regex, replacement as string)
  }
  return result.trim()
}

// ─── Layer 2: Dedup with System Prompt ───────────────────────────────────────
// These specific tools have descriptions that DUPLICATE content already injected
// into the system prompt by the engram.ts and background-agents.ts plugins.

const DEDUP_RULES: Record<string, RegExp[]> = {
  // mem_save: strip WHEN to save list, FORMAT template, and examples
  // (all duplicated in MEMORY_INSTRUCTIONS from engram.ts)
  mem_save: [
    /\n*WHEN to save[^]*?(?=\n\nFORMAT|\n\nTitle|\n\n[A-Z]|\s*$)/i,
    /\n*FORMAT for (?:content|mem_save)[^]*?(?=\n\nTITLE|\n\nExamples?:|\n\n[A-Z]|\s*$)/i,
    /\n*TITLE should be[^]*?(?=\n\nExamples?:|\n\n[A-Z]|\s*$)/i,
    /\n*Examples?:\s*\n[^]*$/i,
  ],

  // mem_session_summary: strip the full template (duplicated in MEMORY_INSTRUCTIONS)
  mem_session_summary: [
    /\n*FORMAT[^]*$/i,
    /\n*GUIDELINES[^]*$/i,
    /\n*## Goal[^]*$/i,
  ],

  // mem_save_prompt: strip the "so future sessions..." explanation
  mem_save_prompt: [
    /\s*Use this to record what the user asked[^.]+\./i,
  ],

  // delegate: strip the "Use this for:" list (duplicated in DELEGATION_RULES)
  delegate: [
    /\n\nUse this for:\n(?:- [^\n]+\n?)+/i,
  ],
}

/** Find dedup rules by partial match — MCP tools arrive prefixed (e.g. mcp_engram_mem_save) */
function findDedupRules(toolID: string): RegExp[] | undefined {
  const lower = toolID.toLowerCase()
  for (const [key, rules] of Object.entries(DEDUP_RULES)) {
    if (lower.includes(key) || lower.endsWith(key)) return rules
  }
  return undefined
}

// ─── Layer 3: Parameter Description Cleanup ──────────────────────────────────
// Strips redundant parameter descriptions where the name already implies meaning.

function compressParamDescriptions(parameters: any): void {
  if (!parameters?.properties) return

  for (const [paramName, paramDef] of Object.entries(parameters.properties)) {
    const def = paramDef as { description?: string }
    if (!def.description) continue

    const desc = def.description
    const lowerName = paramName.toLowerCase().replace(/_/g, " ")
    const lowerDesc = desc.toLowerCase()

    // If description starts with the parameter name, strip the prefix
    // "Search query — natural language or keywords" → "natural language or keywords"
    if (lowerDesc.startsWith(lowerName)) {
      const stripped = desc.slice(paramName.length).replace(/^[\s—–\-:]+/, "").trim()
      if (stripped.length > 0) {
        def.description = stripped
      }
    }

    // Strip "New X" pattern in update tools (the "new" is implied by "update")
    if (def.description.match(/^New \w+$/i)) {
      def.description = ""
    }

    // Strip pure restatements like "Project name" for param "project"
    if (lowerDesc.replace(/\s/g, "") === lowerName.replace(/\s/g, "")) {
      def.description = ""
    }
  }
}

// ─── Safety Checks ───────────────────────────────────────────────────────────

/** Returns true if the description contains code examples that should not be touched */
function hasCodeExamples(description: string): boolean {
  return description.includes("```")
}

// ─── Plugin Export ───────────────────────────────────────────────────────────

export const ToolCompressor: Plugin = async (_ctx) => {
  console.log("[tool-compressor] initialized: 3-layer grease removal active")

  return {
    // ─── Tool Definition Hook: Compress Descriptions ───────────────

    "tool.definition": async (input, output) => {
      const original = output.description

      // Safety: skip descriptions with code examples (design tools, etc.)
      if (hasCodeExamples(original)) return

      // Layer 1: Generic regex compressions
      output.description = applyRegexCompressions(output.description)

      // Layer 2: Dedup with system prompt (per toolID)
      const dedupRules = findDedupRules(input.toolID)
      if (dedupRules) {
        let desc = output.description
        for (const regex of dedupRules) {
          desc = desc.replace(regex, "")
        }
        output.description = desc.trim()
      }

      // Layer 3: Parameter description cleanup
      compressParamDescriptions(output.parameters)

      // Final cleanup: normalize whitespace
      output.description = output.description
        .replace(/\n{3,}/g, "\n\n")
        .replace(/ {2,}/g, " ")
        .trim()

      // Safety net: never produce an empty description
      if (output.description.length === 0) {
        output.description = original
      }
    },
  }
}

export default ToolCompressor
