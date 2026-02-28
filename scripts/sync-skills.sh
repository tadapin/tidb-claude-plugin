#!/bin/bash
# Sync skills from upstream pingcap/agent-rules repository
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
UPSTREAM_REPO="https://github.com/pingcap/agent-rules.git"
TMPDIR="$(mktemp -d)"

trap 'rm -rf "$TMPDIR"' EXIT

echo "Fetching latest skills from $UPSTREAM_REPO..."
git clone --depth 1 "$UPSTREAM_REPO" "$TMPDIR" 2>/dev/null

echo "Updating skills directory..."
rm -rf "$REPO_ROOT/skills"
cp -r "$TMPDIR/skills" "$REPO_ROOT/skills"

echo "Done. Updated skills:"
ls "$REPO_ROOT/skills"
