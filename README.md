# Mati AI Rules

Interactive installer of extension rules for **Claude Code** (`CLAUDE.md`) and **OpenCode** (`AGENTS.md`). These are complementary rules that extend the base configuration installed by [gentle-ai](https://github.com/MatiasNLopez/gentle-ai). It does not install persona, philosophy, or behavior — only optional technical rules.

## Quick Install

```bash
git clone https://github.com/MatiasNLopez/mati-ai-rules.git
cd mati-ai-rules
./install.sh
```

One-liner:

```bash
git clone https://github.com/MatiasNLopez/mati-ai-rules.git && cd mati-ai-rules && ./install.sh
```

## Usage

Run `./install.sh` and follow the interactive prompts:

1. Choose the tool (Claude Code, OpenCode, or both)
2. Choose the scope (global or current project)
3. Select which rule groups to install
4. Customize expertise if needed

The installer is idempotent — if a rule already exists, it will ask before overwriting. When extending, it uses smart merge to only add what's missing (no duplicates).

## Available Rules

### General

| Rule | Description |
|------|-------------|
| **RTK — Token-Optimized CLI** | Full command mapping table for `rtk`, a CLI proxy that compresses output and saves 60-90% tokens. Includes mappings for git, npm, pnpm, cargo, go, docker, kubectl, and more. |
| **.gitignore Respect** | Instructs the agent to always respect `.gitignore` in all file operations, with an exception for `.env` files when needed for configuration. |
| **Expertise** *(customizable)* | Expertise areas section. Ships with a default template but you can write your own list of technologies and skills. |
| **PostgreSQL** | Dynamic credential resolution section — teaches the agent to find database credentials from `.env`, `gradle.properties`, or `Openbravo.properties` files. |
| **PostgreSQL MCP** | Installs the `postgres-mcp` server config into the tool's JSON config file (`opencode.json` or `claude_desktop_config.json`). Merges into the existing MCP servers without replacing them. Requires `jq`. |

### Etendo / Openbravo

| Rule | Description |
|------|-------------|
| **Exclusion Rule** | Adds exclusion of `WebContent/`, `attachments/`, and `build/` directories from all file operations in Etendo/Openbravo projects. |
| **ERP Skills Table** | Auto-detection table with 17 Etendo-specific skills mapped to contexts (e.g., `etendo-alter-db`, `etendo-java`, `etendo-smartbuild`). |
| **Backend Expertise** *(customizable)* | Backend-specific expertise: Java, Python, Hibernate, PostgreSQL, Kafka. Can be customized during install. |

## Smart Extend

When a rule already exists and you choose **extend**, the installer uses a 3-level comparison:

1. **Prefix match** — If the existing line is a shorter version of the new one (e.g., `Backend, PostgreSQL.` vs `Backend, PostgreSQL, Kafka.`), it replaces in-place with the more complete version.
2. **Substring match** — If the new content is already embedded within an existing line (e.g., a combined Frontend + Backend line), it upgrades the substring in-place.
3. **No match** — Appends the new content at the end of the section.

Running the installer multiple times on the same file produces no duplicates.

## Project Structure

```
mati-ai-rules/
├── install.sh                # Interactive installer (bash)
├── rules/
│   ├── rtk.md                # RTK command mapping table
│   ├── gitignore.md          # .gitignore respect rule
│   ├── expertise.md          # Default expertise template
│   ├── etendo-rules.md       # Etendo exclusion rule
│   ├── etendo-skills.md      # Etendo ERP skills table (17 skills)
│   ├── etendo-expertise.md   # Backend expertise template
│   ├── postgres.md           # PostgreSQL dynamic credentials
│   └── postgres-mcp.json     # MCP server config for postgres
├── README.md
└── .gitignore
```

## Requirements

- Bash 4.3+ (any modern Linux or macOS)
- `jq` — only required for PostgreSQL MCP config installation
- No other external dependencies

## Color Scheme

The installer uses the [Rose Pine](https://rosepinetheme.com/) color palette, matching the [gentle-ai](https://github.com/MatiasNLopez/gentle-ai) TUI.

## Related

- [gentle-ai](https://github.com/MatiasNLopez/gentle-ai) — Base AI agent configuration tool (persona, philosophy, behavior, skills)
