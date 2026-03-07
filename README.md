# tidb-ai-dev

TiDB Cloud plugin for Claude Code. Provides all TiDB Cloud skills and MCP server integration in a single installable package.

## Features

### Skills (6)

| Skill | Description |
|-------|-------------|
| **tidbx** | TiDB Cloud (TiDB X) cluster provisioning and lifecycle management |
| **tidb-sql** | TiDB SQL authoring with MySQL compatibility guidance |
| **pytidb** | Python SDK for TiDB — CRUD, vector/full-text/hybrid search, embeddings |
| **tidbx-serverless-driver** | Serverless HTTP driver for edge runtimes |
| **tidbx-kysely** | Kysely query builder integration (TCP + serverless) |
| **tidb-cloud-zero** | Create ephemeral TiDB Cloud Zero databases for agent workflows (Technical Preview) |

### MCP Server

- **TiDB MCP Server** — Database operations via Model Context Protocol (powered by `pytidb[mcp]`)

## Prerequisites

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) CLI
- [uv](https://docs.astral.sh/uv/) (for MCP server via `uvx`)
- A TiDB Cloud account with a Serverless cluster

## Installation

### Via Marketplace (recommended)

```bash
# Add the marketplace
/plugin marketplace add tadapin/tidb-claude-plugin

# Install the plugin (via /plugin UI or CLI)
/plugin install tidb-ai-dev@tidb-plugins
```

### Manual

```bash
git clone https://github.com/tadapin/tidb-claude-plugin.git
claude --plugin-dir /path/to/tidb-claude-plugin
```

## Usage

Once installed, the skills activate automatically based on context:

- Ask about TiDB SQL syntax → `tidb-sql` skill activates
- Write Python code with TiDB → `pytidb` skill activates
- Provision a TiDB cluster → `tidbx` skill activates
- Create a disposable database → `tidb-cloud-zero` skill activates
- Use serverless driver → `tidbx-serverless-driver` skill activates
- Use Kysely with TiDB → `tidbx-kysely` skill activates

The TiDB MCP server provides direct database access tools within Claude Code.

## Environment Management

Manage multiple TiDB environments (dev, staging, prod) and switch between them with a single command.

```bash
# Initialize
/tidb-ai-dev:tidb-env init

# Add environments
/tidb-ai-dev:tidb-env add --name dev --host gateway01.us-east-1.prod.aws.tidbcloud.com --port 4000 --username prefix.root --password secret --database myapp
/tidb-ai-dev:tidb-env add --name prod --host gateway01.us-west-2.prod.aws.tidbcloud.com --port 4000 --username prefix.root --password secret --database myapp

# Or import from existing .env
/tidb-ai-dev:tidb-env import --name dev

# List and switch
/tidb-ai-dev:tidb-env list
/tidb-ai-dev:tidb-env switch prod   # Updates .env with TIDB_* variables
/tidb-ai-dev:tidb-env show prod

# Create a new TiDB Serverless cluster
/tidb-ai-dev:tidb-env create --name staging --region us-east-1

# Create an ephemeral TiDB Cloud Zero database (no auth required)
/tidb-ai-dev:tidb-env zero --name sandbox
```

Environment credentials are stored in `.tidb/envs/` (automatically added to `.gitignore`). Switching environments updates the `.env` file with `TIDB_*` variables, preserving other variables like `OPENAI_API_KEY`. After switching, run `/mcp` to reconnect the TiDB MCP server with the new environment.

You can also use the script directly:

```bash
bash scripts/tidb-env.sh init
bash scripts/tidb-env.sh list --json
```

## Environment Variables

The MCP server may require the following environment variables:

- `TIDB_HOST` — TiDB Cloud cluster host
- `TIDB_PORT` — Connection port (default: 4000)
- `TIDB_USERNAME` — Database user
- `TIDB_PASSWORD` — Database password
- `TIDB_DATABASE` — Database name

## Updating Skills

Skills are sourced from [pingcap/agent-rules](https://github.com/pingcap/agent-rules). To update:

```bash
scripts/sync-skills.sh
```

## License

Apache-2.0
