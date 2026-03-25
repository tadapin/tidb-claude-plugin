# CLAUDE.md

## Project Overview

This is **tidb-ai-dev**, a Claude Code plugin that provides TiDB Cloud skills, MCP server integration, and multi-environment management.

## Repository Structure

```
.claude-plugin/plugin.json   # Plugin manifest
.mcp.json                    # MCP server config (TiDB via pytidb[mcp])
skills/                      # Skill definitions (SKILL.md + references/guides)
commands/                    # Plugin commands (slash commands)
  tidb-env.md                # /tidb-ai-dev:tidb-env command
scripts/
  tidb-env.sh                # Multi-environment management (bash)
  sync-skills.sh             # Upstream skill sync script
```

## Skills

Skills live in `skills/<name>/SKILL.md` with optional `references/` and `guides/` subdirectories.

**Upstream sources:**
- Most skills sync from [pingcap/agent-rules](https://github.com/pingcap/agent-rules) via `scripts/sync-skills.sh`
- `tidb-cloud-zero` syncs from `https://zero.tidbcloud.com/SKILL.md`

Running `scripts/sync-skills.sh` overwrites all synced skills. Do not edit synced skill files directly — changes will be lost on next sync.

## Environment Management (`scripts/tidb-env.sh`)

Manages `.tidb/envs/*.json` files in the user's project directory. Subcommands: `init`, `add`, `create`, `zero`, `remove`, `list`, `switch`, `show`, `import`.

Design decisions:
- JSON operations use `jq` with `python3 -c` fallback (no other dependencies)
- Env JSON files have `0600` permissions (credential protection)
- `switch` writes `TIDB_*` variables to `.env`, preserving non-TIDB variables
- `--json` flag on all subcommands for machine-readable output
- `zero` calls the TiDB Cloud Zero API (unauthenticated) and auto-switches
- `create` uses `ticloud` CLI to provision a Serverless cluster

## MCP Server

Configured in `.mcp.json`. The server sources `.env` at startup via `set -a && source .env`. After switching environments, users must restart the MCP server (`/mcp`) for changes to take effect.

## Development

```bash
# Test the plugin locally
claude --plugin-dir .

# Run environment management tests
bash scripts/tidb-env.sh init
bash scripts/tidb-env.sh add --name test --host localhost --port 4000 --username root --password "" --database test
bash scripts/tidb-env.sh list
bash scripts/tidb-env.sh switch test
bash scripts/tidb-env.sh remove test

# Sync skills from upstream
bash scripts/sync-skills.sh
```

## Conventions

- Shell scripts use `set -euo pipefail`
- Command files are markdown with YAML frontmatter (`name`, `description`, `allowed-tools`, `arguments`)
- Skill files use YAML frontmatter (`name`, `description`, optional `metadata`)
- The `.env` variable for username is `TIDB_USERNAME` (not `TIDB_USER`)
