# tidb-ai-dev

TiDB Cloud plugin for Claude Code. Provides all TiDB Cloud skills and MCP server integration in a single installable package.

## Features

### Skills (5)

| Skill | Description |
|-------|-------------|
| **tidbx** | TiDB Cloud (TiDB X) cluster provisioning and lifecycle management |
| **tidb-sql** | TiDB SQL authoring with MySQL compatibility guidance |
| **pytidb** | Python SDK for TiDB — CRUD, vector/full-text/hybrid search, embeddings |
| **tidbx-serverless-driver** | Serverless HTTP driver for edge runtimes |
| **tidbx-kysely** | Kysely query builder integration (TCP + serverless) |

### MCP Server

- **TiDB MCP Server** — Database operations via Model Context Protocol (powered by `pytidb[mcp]`)

## Prerequisites

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) CLI
- [uv](https://docs.astral.sh/uv/) (for MCP server via `uvx`)
- A TiDB Cloud account with a Serverless cluster

## Installation

```bash
git clone https://github.com/tadapin/tidb-claude-plugin.git
claude --plugin-dir /path/to/tidb-claude-plugin
```

## Usage

Once installed, the skills activate automatically based on context:

- Ask about TiDB SQL syntax → `tidb-sql` skill activates
- Write Python code with TiDB → `pytidb` skill activates
- Provision a TiDB cluster → `tidbx` skill activates
- Use serverless driver → `tidbx-serverless-driver` skill activates
- Use Kysely with TiDB → `tidbx-kysely` skill activates

The TiDB MCP server provides direct database access tools within Claude Code.

## Environment Variables

The MCP server may require the following environment variables:

- `TIDB_HOST` — TiDB Cloud cluster host
- `TIDB_PORT` — Connection port (default: 4000)
- `TIDB_USER` — Database user
- `TIDB_PASSWORD` — Database password
- `TIDB_DATABASE` — Database name

## Updating Skills

Skills are sourced from [pingcap/agent-rules](https://github.com/pingcap/agent-rules). To update:

```bash
scripts/sync-skills.sh
```

## License

Apache-2.0
