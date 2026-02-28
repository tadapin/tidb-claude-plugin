#!/bin/bash
# Sync skills from upstream sources
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SKILLS_DIR="$REPO_ROOT/skills"

# --- 1. pingcap/agent-rules (main skill set) --------------------------------
UPSTREAM_REPO="https://github.com/pingcap/agent-rules.git"
TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

echo "Fetching latest skills from $UPSTREAM_REPO..."
git clone --depth 1 "$UPSTREAM_REPO" "$TMPDIR" 2>/dev/null

echo "Updating agent-rules skills..."
# Remove only agent-rules-sourced skills (preserve other sources)
for dir in "$TMPDIR/skills"/*/; do
  skill_name="$(basename "$dir")"
  rm -rf "$SKILLS_DIR/$skill_name"
done
cp -r "$TMPDIR/skills"/* "$SKILLS_DIR/"

echo "agent-rules skills updated:"
ls "$TMPDIR/skills"

# --- 2. tidb-cloud-zero (from zero.tidbcloud.com) ---------------------------
ZERO_SKILL_URL="https://zero.tidbcloud.com/SKILL.md"
ZERO_SKILL_DIR="$SKILLS_DIR/tidb-cloud-zero"

echo ""
echo "Fetching tidb-cloud-zero skill from $ZERO_SKILL_URL..."
mkdir -p "$ZERO_SKILL_DIR"

if curl -sfL "$ZERO_SKILL_URL" -o "$ZERO_SKILL_DIR/SKILL.md"; then
  echo "tidb-cloud-zero skill updated."
else
  echo "Warning: Failed to fetch tidb-cloud-zero skill. Skipping."
fi

# --- Done --------------------------------------------------------------------
echo ""
echo "All skills synced:"
ls "$SKILLS_DIR"
