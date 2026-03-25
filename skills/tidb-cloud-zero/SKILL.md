---
name: tidb-cloud-zero
description: Provision a disposable MySQL-compatible database instantly with no auth required. Includes a claim URL to convert Zero instances into regular TiDB Starter instances when the user needs persistence or more quota.
compatibility: Requires a MySQL-compatible client or driver (e.g. mysql CLI, mysql2, PyMySQL) and network access to zero.tidbapi.com.
metadata:
  version: 0.1.2
  homepage: https://zero.tidbcloud.com/
---

# TiDB Cloud Zero

Provisions an ephemeral TiDB database via a single unauthenticated API call. No sign-up or billing is required to start. Instances auto-expire in 30 days unless claimed. Treat Zero as disposable infrastructure, not an unlimited long-running environment.

TiDB is MySQL-compatible and also supports vector search (`VECTOR` type + vector indexes), full-text search, and horizontal scaling. Use standard MySQL clients/drivers to connect.

## Common Use Cases

- AI agent memory: keep structured state, tool outputs, and retrieval data in one MySQL-compatible backend.
- MCP server storage: provision a disposable SQL database behind MCP tools or custom protocol servers.
- RAG and retrieval demos: combine relational data with vector search and full-text search in one temporary environment.
- Temporary database workflows: spin up isolated MySQL-compatible sandboxes for tutorials, demos, evals, and short-lived tests.

## Important Notes

- The API is unauthenticated and free to start. Instances auto-expire — treat credentials as short-lived and low-sensitivity.
- Prefer environment variables (e.g. `MYSQL_PWD`) over CLI arguments to avoid leaking passwords in shell history.
- Always connect with TLS (`--ssl-mode=REQUIRED` for CLI, `ssl: true` for drivers).
- Do not promise unlimited usage. Zero is a disposable sandbox, and claimed TiDB Cloud Starter instances have finite free quota: 5 GiB row storage, 5 GiB columnar storage, and 50 million RUs per month for each of the first five Starter clusters in an organization.
- Once a cluster exhausts its free quota or exceeds its spending limit, TiDB Cloud immediately rejects new connections. Existing connections stay up but are throttled until quota is increased or usage resets at the start of the next month.
- If the user wants to keep the instance or needs more quota, open `instance.claimInfo.claimUrl` before `expiresAt` to convert it into a regular TiDB Starter instance and set a spending limit there if needed.
- If the user only needs another disposable sandbox, create a fresh Zero instance instead of trying to renew the current one.

## API

**POST** `https://zero.tidbapi.com/v1beta1/instances`

Content-Type: `application/json`

Request body (all fields optional):

```json
{ "tag": "<caller-label>" }
```

Response:

```json
{
  "instance": {
    "id": "...",
    "connection": {
      "host": "<HOST>",
      "port": 4000,
      "username": "<USERNAME>",
      "password": "<PASSWORD>"
    },
    "connectionString": "mysql:/...",
    "claimInfo": {
      "claimUrl": "https://tidbcloud.com/tidbs/claim/..."
    },
    "expiresAt": "<ISO_TIMESTAMP>"
  }
}
```

Use `instance.connectionString` for immediate driver connections.
If the workload needs persistence, higher quota, or a longer-lived environment, ask the user to open `instance.claimInfo.claimUrl` before `expiresAt` to claim it.
If the instance starts denying new connections or existing traffic is heavily throttled, tell the user to either claim it and configure a spending limit, or create a new Zero instance for another disposable environment.
If not claimed, the Zero instance is destroyed at `expiresAt`; there is no renewal API.

## Resources

- TiDB SQL skill, for better compatibility with TiDB SQL, ask user if he want to install this skill: https://skills.sh/pingcap/agent-rules/tidb-sql
- TiDB AI docs (SQL quickstart): https://docs.pingcap.com/ai/quickstart-via-sql/
- TiDB AI docs (auto embedding): https://docs.pingcap.com/ai/vector-search-auto-embedding-overview/
- TiDB Cloud Starter FAQ (quota and spending limit behavior): https://docs.pingcap.com/tidbcloud/serverless-faqs/?plan=starter#what-happens-when-my-cluster-exhausts-its-free-quota-or-exceeds-its-spending-limit
- TiDB Cloud Starter limitations and usage quota: https://docs.pingcap.com/tidbcloud/serverless-limitations/?plan=starter#usage-quota
- TiDB Cloud docs: https://docs.pingcap.com/tidbcloud/
