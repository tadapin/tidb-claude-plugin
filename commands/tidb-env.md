---
name: tidb-env
description: Manage TiDB multi-environment configurations — init, add, list, switch, show, remove, import, create, zero
allowed-tools: Bash
arguments: subcommand and flags, e.g. "list", "add --name dev --host ...", "switch prod"
---

# TiDB Environment Manager

You are managing TiDB environments via `tidb-env.sh`.

## Parse the user's request

The user invoked `/tidb-ai-dev:tidb-env $ARGUMENTS`.

Determine the subcommand from `$ARGUMENTS`:
- **No arguments or "help"** → show available subcommands and usage examples
- **"init"** → initialize environment directory
- **"add ..."** → add a new environment
- **"create ..."** → create a TiDB Serverless cluster
- **"zero ..."** → create an ephemeral TiDB Cloud Zero database
- **"remove <name>"** → remove an environment
- **"list"** → list all environments
- **"switch <name>"** → switch active environment
- **"show <name>"** → show environment details
- **"import ..."** → import from .env file

## Execute

Run the command using:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/tidb-env.sh" --json <subcommand> [flags]
```

Use `--json` for machine-readable output so you can parse the results.

## Post-execution notes

- After **switch**: The `.env` file and `.mcp.json` have been updated with the new `TIDB_*` variables. Inform the user to run `/mcp` to reconnect the TiDB MCP server with the new environment.
- After **init**: Let the user know they can now add environments with `add` or import from an existing `.env` with `import`.
- After **create**: Remind the user to set the root password via `ticloud serverless update` and then update the environment JSON.
- After **zero**: Note that the Zero instance is ephemeral with an expiration time. The user can claim it in the TiDB Cloud Console to make it permanent.
- After **list** with no environments: Suggest using `add` or `import` to get started.
- After **remove** of the active environment: Note that no environment is currently active.

## Usage examples to show for "help"

```
/tidb-ai-dev:tidb-env init
/tidb-ai-dev:tidb-env add --name dev --host gateway01.us-east-1.prod.aws.tidbcloud.com --port 4000 --username prefix.root --password secret --database myapp
/tidb-ai-dev:tidb-env list
/tidb-ai-dev:tidb-env switch dev
/tidb-ai-dev:tidb-env show dev
/tidb-ai-dev:tidb-env remove dev
/tidb-ai-dev:tidb-env import --name dev
/tidb-ai-dev:tidb-env create --name my-cluster --region us-east-1
/tidb-ai-dev:tidb-env zero --name sandbox
```
