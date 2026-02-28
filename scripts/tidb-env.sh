#!/bin/bash
# tidb-env.sh — TiDB multi-environment management
set -euo pipefail

# --- JSON helper -----------------------------------------------------------
json_get() {
  local file="$1" key="$2"
  if command -v jq &>/dev/null; then
    jq -r ".$key // empty" "$file"
  else
    python3 -c "import json,sys; d=json.load(open('$file')); v=d.get('$key',''); print(v if v is not None else '')"
  fi
}


json_create() {
  # Create a JSON file from key=value pairs
  local file="$1"; shift
  if command -v jq &>/dev/null; then
    local expr="."
    while [[ $# -gt 0 ]]; do
      local key="$1" value="$2"; shift 2
      # Detect integers and booleans
      case "$value" in
        true|false)   expr="$expr | .$key = $value" ;;
        [0-9]*)       expr="$expr | .$key = ($value)" ;;
        *)            expr="$expr | .$key = \"$value\"" ;;
      esac
    done
    echo '{}' | jq "$expr" > "$file"
  else
    python3 << PYEOF
import json, sys
data = {}
pairs = [$(printf '"%s",' "$@")]
i = 0
while i < len(pairs):
    k, v = pairs[i], pairs[i+1]
    if v in ("true", "false"):
        data[k] = v == "true"
    else:
        try:
            data[k] = int(v)
        except ValueError:
            data[k] = v
    i += 2
with open("$file", "w") as f:
    json.dump(data, f, indent=2)
PYEOF
  fi
  chmod 0600 "$file"
}

json_dump() {
  local file="$1"
  if command -v jq &>/dev/null; then
    jq '.' "$file"
  else
    python3 -c "import json; print(json.dumps(json.load(open('$file')), indent=2))"
  fi
}

json_list_files() {
  # List .json files in a directory, return basenames without extension
  local dir="$1"
  for f in "$dir"/*.json; do
    [[ -f "$f" ]] || continue
    basename "$f" .json
  done
}

mask_password() {
  local pw="$1"
  if [[ -z "$pw" ]]; then
    echo "(empty)"
  else
    echo "${pw:0:2}***"
  fi
}

# --- Paths ------------------------------------------------------------------
TIDB_DIR=".tidb"
ENVS_DIR="$TIDB_DIR/envs"
ACTIVE_FILE="$TIDB_DIR/active"
DOT_ENV=".env"

# --- JSON output flag -------------------------------------------------------
JSON_OUTPUT=false

info()  { [[ "$JSON_OUTPUT" == true ]] && return; echo "$@"; }
error() { echo "Error: $*" >&2; }

# --- Subcommands ------------------------------------------------------------

cmd_init() {
  mkdir -p "$ENVS_DIR"
  info "Initialized $TIDB_DIR/"

  # Add .tidb/ to .gitignore if not present
  if [[ -f .gitignore ]]; then
    if ! grep -q '^\.tidb/' .gitignore 2>/dev/null; then
      echo "" >> .gitignore
      echo "# TiDB environment credentials" >> .gitignore
      echo ".tidb/" >> .gitignore
      info "Added .tidb/ to .gitignore"
    fi
  else
    echo "# TiDB environment credentials" > .gitignore
    echo ".tidb/" >> .gitignore
    info "Created .gitignore with .tidb/"
  fi

  if [[ "$JSON_OUTPUT" == true ]]; then
    echo '{"status":"ok","message":"initialized"}'
  fi
}

cmd_add() {
  local name="" host="" port="4000" username="" password="" database="" ssl="true" notes=""
  local cluster_id="" project_id="" region=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --name)       name="$2"; shift 2 ;;
      --host)       host="$2"; shift 2 ;;
      --port)       port="$2"; shift 2 ;;
      --username)   username="$2"; shift 2 ;;
      --password)   password="$2"; shift 2 ;;
      --database)   database="$2"; shift 2 ;;
      --ssl)        ssl="$2"; shift 2 ;;
      --cluster-id) cluster_id="$2"; shift 2 ;;
      --project-id) project_id="$2"; shift 2 ;;
      --region)     region="$2"; shift 2 ;;
      --notes)      notes="$2"; shift 2 ;;
      *) error "Unknown flag: $1"; exit 1 ;;
    esac
  done

  if [[ -z "$name" || -z "$host" || -z "$username" || -z "$database" ]]; then
    error "Required: --name, --host, --username, --database"
    exit 1
  fi

  mkdir -p "$ENVS_DIR"
  local env_file="$ENVS_DIR/${name}.json"

  if [[ -f "$env_file" ]]; then
    error "Environment '$name' already exists. Remove it first."
    exit 1
  fi

  local created_at
  created_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

  if command -v jq &>/dev/null; then
    jq -n \
      --arg name "$name" \
      --arg host "$host" \
      --argjson port "$port" \
      --arg username "$username" \
      --arg password "$password" \
      --arg database "$database" \
      --argjson ssl "$ssl" \
      --arg cluster_id "$cluster_id" \
      --arg project_id "$project_id" \
      --arg region "$region" \
      --arg created_at "$created_at" \
      --arg notes "$notes" \
      '{
        name: $name,
        host: $host,
        port: $port,
        username: $username,
        password: $password,
        database: $database,
        ssl: $ssl,
        cloud: { cluster_id: $cluster_id, project_id: $project_id, region: $region },
        created_at: $created_at,
        notes: $notes
      }' > "$env_file"
  else
    python3 - "$name" "$host" "$port" "$username" "$password" "$database" "$ssl" \
             "$cluster_id" "$project_id" "$region" "$created_at" "$notes" "$env_file" << 'PYEOF'
import json, sys
name, host, port, username, password, database, ssl, \
    cluster_id, project_id, region, created_at, notes, env_file = sys.argv[1:14]
data = {
    "name": name,
    "host": host,
    "port": int(port),
    "username": username,
    "password": password,
    "database": database,
    "ssl": ssl == "true",
    "cloud": {
        "cluster_id": cluster_id,
        "project_id": project_id,
        "region": region
    },
    "created_at": created_at,
    "notes": notes
}
with open(env_file, "w") as f:
    json.dump(data, f, indent=2)
PYEOF
  fi
  chmod 0600 "$env_file"

  info "Added environment: $name"

  if [[ "$JSON_OUTPUT" == true ]]; then
    echo "{\"status\":\"ok\",\"name\":\"$name\"}"
  fi
}

cmd_create() {
  # Create a TiDB Serverless cluster via ticloud CLI and register it
  local name="" region="us-east-1" project_id="" spending_limit_monthly="0"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --name)       name="$2"; shift 2 ;;
      --region)     region="$2"; shift 2 ;;
      --project-id) project_id="$2"; shift 2 ;;
      --spending-limit) spending_limit_monthly="$2"; shift 2 ;;
      *) error "Unknown flag: $1"; exit 1 ;;
    esac
  done

  if [[ -z "$name" ]]; then
    error "Required: --name"
    exit 1
  fi

  if ! command -v ticloud &>/dev/null; then
    error "ticloud CLI not found. Install it: https://docs.pingcap.com/tidbcloud/cli"
    exit 1
  fi

  # Auto-prepend "aws-" if region doesn't already have a provider prefix
  if [[ "$region" != aws-* && "$region" != gcp-* ]]; then
    region="aws-${region}"
  fi

  info "Creating TiDB Serverless cluster '$name'..."

  # Ensure initialized
  if [[ ! -d "$ENVS_DIR" ]]; then
    cmd_init
  fi

  local create_args=("serverless" "create" "--display-name" "$name" "--region" "$region")
  if [[ -n "$project_id" ]]; then
    create_args+=("--project-id" "$project_id")
  fi
  create_args+=("--spending-limit-monthly" "$spending_limit_monthly")

  local result
  result="$(ticloud "${create_args[@]}" 2>&1)" || {
    error "Failed to create cluster: $result"
    exit 1
  }

  # ticloud create outputs text like "Cluster 1234567890 is ready."
  # Extract cluster ID from the output
  local cluster_id
  cluster_id="$(echo "$result" | grep -oE '[0-9]{10,}' | head -1)"

  if [[ -z "$cluster_id" ]]; then
    error "Failed to parse cluster ID from output: $result"
    exit 1
  fi

  info "Cluster created: $cluster_id"
  info "Fetching connection info..."

  local conn_result
  conn_result="$(ticloud serverless describe --cluster-id "$cluster_id" 2>&1)" || {
    error "Failed to get cluster info: $conn_result"
    exit 1
  }

  local host port user_prefix username database
  if command -v jq &>/dev/null; then
    host="$(echo "$conn_result" | jq -r '.endpoints.public.host // empty')"
    port="$(echo "$conn_result" | jq -r '.endpoints.public.port // 4000')"
    user_prefix="$(echo "$conn_result" | jq -r '.userPrefix // empty')"
    database="test"
    project_id="$(echo "$conn_result" | jq -r '.labels["tidb.cloud/project"] // empty')"
  else
    host="$(echo "$conn_result" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('endpoints',{}).get('public',{}).get('host',''))")"
    port="$(echo "$conn_result" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('endpoints',{}).get('public',{}).get('port',4000))")"
    user_prefix="$(echo "$conn_result" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('userPrefix',''))")"
    database="test"
    project_id="$(echo "$conn_result" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('labels',{}).get('tidb.cloud/project',''))")"
  fi
  username="${user_prefix}.root"

  # Auto-generate password and set it via ticloud CLI
  local password
  password="$(LC_ALL=C tr -dc 'A-Za-z0-9!@#$%^&*' < /dev/urandom | head -c 24 || true)"
  info "Setting root password..."
  ticloud serverless sql-user update --cluster-id "$cluster_id" --user root --password "$password" &>/dev/null || {
    error "Failed to set root password. Set it manually: ticloud serverless sql-user update -c $cluster_id --user root --password <password>"
    password=""
  }

  info "Host: $host"

  cmd_add --name "$name" --host "$host" --port "$port" --username "$username" --password "$password" \
          --database "$database" --cluster-id "$cluster_id" --project-id "$project_id" --region "$region"
}

cmd_zero() {
  # Create an ephemeral TiDB Cloud Zero database and register it
  local name="" tag="" database="test" switch="true"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --name)     name="$2"; shift 2 ;;
      --tag)      tag="$2"; shift 2 ;;
      --database) database="$2"; shift 2 ;;
      --switch)   switch="$2"; shift 2 ;;
      *) error "Unknown flag: $1"; exit 1 ;;
    esac
  done

  if [[ -z "$name" ]]; then
    error "Required: --name"
    exit 1
  fi

  # Default tag to name
  [[ -z "$tag" ]] && tag="$name"

  # Ensure initialized
  if [[ ! -d "$ENVS_DIR" ]]; then
    cmd_init
  fi

  info "Creating TiDB Cloud Zero instance (tag: $tag)..."

  local response
  response="$(curl -s -X POST https://zero.tidbapi.com/v1alpha1/instances \
    -H 'Content-Type: application/json' \
    -d "{\"tag\":\"$tag\"}")" || {
    error "Failed to call TiDB Cloud Zero API"
    exit 1
  }

  # Parse response
  local host port username password expires_at
  if command -v jq &>/dev/null; then
    host="$(echo "$response" | jq -r '.instance.connection.host // empty')"
    port="$(echo "$response" | jq -r '.instance.connection.port // 4000')"
    username="$(echo "$response" | jq -r '.instance.connection.username // empty')"
    password="$(echo "$response" | jq -r '.instance.connection.password // empty')"
    expires_at="$(echo "$response" | jq -r '.instance.expiresAt // empty')"
  else
    host="$(echo "$response" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('instance',{}).get('connection',{}).get('host',''))")"
    port="$(echo "$response" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('instance',{}).get('connection',{}).get('port',4000))")"
    username="$(echo "$response" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('instance',{}).get('connection',{}).get('username',''))")"
    password="$(echo "$response" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('instance',{}).get('connection',{}).get('password',''))")"
    expires_at="$(echo "$response" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('instance',{}).get('expiresAt',''))")"
  fi

  if [[ -z "$host" ]]; then
    error "Failed to create Zero instance. API response: $response"
    exit 1
  fi

  local notes="Zero ephemeral — expires $expires_at"

  # Register the environment
  cmd_add --name "$name" --host "$host" --port "$port" --username "$username" \
          --password "$password" --database "$database" --ssl true --notes "$notes"

  # Switch if requested
  if [[ "$switch" == "true" ]]; then
    cmd_switch "$name"
  fi

  local connection_string="mysql://${username}:***@${host}:${port}/${database}?ssl=true"

  if [[ "$JSON_OUTPUT" == true ]]; then
    if command -v jq &>/dev/null; then
      jq -n \
        --arg status "ok" \
        --arg name "$name" \
        --arg expires_at "$expires_at" \
        --arg connection_string "$connection_string" \
        '{status: $status, name: $name, expires_at: $expires_at, connection_string: $connection_string}'
    else
      echo "{\"status\":\"ok\",\"name\":\"$name\",\"expires_at\":\"$expires_at\",\"connection_string\":\"$connection_string\"}"
    fi
  else
    info "Zero instance created successfully!"
    info "  Expires: $expires_at"
    info "  Connection: $connection_string"
    info "Tip: Claim in TiDB Cloud Console to make it permanent."
  fi
}

cmd_remove() {
  local name="$1"
  local env_file="$ENVS_DIR/${name}.json"

  if [[ ! -f "$env_file" ]]; then
    error "Environment '$name' not found"
    exit 1
  fi

  # Warn if active
  if [[ -f "$ACTIVE_FILE" ]] && [[ "$(cat "$ACTIVE_FILE")" == "$name" ]]; then
    info "Warning: '$name' is the active environment"
    rm -f "$ACTIVE_FILE"
    info "Cleared active environment"
  fi

  rm -f "$env_file"
  info "Removed environment: $name"

  if [[ "$JSON_OUTPUT" == true ]]; then
    echo "{\"status\":\"ok\",\"removed\":\"$name\"}"
  fi
}

cmd_list() {
  if [[ ! -d "$ENVS_DIR" ]]; then
    error "Not initialized. Run: tidb-env.sh init"
    exit 1
  fi

  local active=""
  [[ -f "$ACTIVE_FILE" ]] && active="$(cat "$ACTIVE_FILE")"

  local envs=()
  for f in "$ENVS_DIR"/*.json; do
    [[ -f "$f" ]] || continue
    envs+=("$f")
  done

  if [[ ${#envs[@]} -eq 0 ]]; then
    if [[ "$JSON_OUTPUT" == true ]]; then
      echo "[]"
    else
      info "No environments configured. Add one with: tidb-env.sh add"
    fi
    return
  fi

  if [[ "$JSON_OUTPUT" == true ]]; then
    if command -v jq &>/dev/null; then
      local items="[]"
      for f in "${envs[@]}"; do
        local n
        n="$(basename "$f" .json)"
        local is_active="false"
        [[ "$n" == "$active" ]] && is_active="true"
        local item
        item="$(jq --argjson active "$is_active" '.active = $active | .password = "***"' "$f")"
        items="$(echo "$items" | jq --argjson item "$item" '. + [$item]')"
      done
      echo "$items"
    else
      python3 << PYEOF
import json, glob, os
active = ""
if os.path.isfile("$ACTIVE_FILE"):
    with open("$ACTIVE_FILE") as f: active = f.read().strip()
result = []
for fp in sorted(glob.glob("$ENVS_DIR/*.json")):
    with open(fp) as f: d = json.load(f)
    d["active"] = d.get("name","") == active
    d["password"] = "***"
    result.append(d)
print(json.dumps(result, indent=2))
PYEOF
    fi
    return
  fi

  # Human-readable table
  printf "%-4s %-20s %-45s %-25s %-15s\n" "" "NAME" "HOST" "USER" "DATABASE"
  printf "%s\n" "$(printf '%.0s-' {1..115})"
  for f in "${envs[@]}"; do
    local n h u d
    n="$(basename "$f" .json)"
    h="$(json_get "$f" host)"
    u="$(json_get "$f" username)"
    d="$(json_get "$f" database)"
    local marker="  "
    [[ "$n" == "$active" ]] && marker="* "
    printf "%-4s %-20s %-45s %-25s %-15s\n" "$marker" "$n" "$h" "$u" "$d"
  done
}

cmd_show() {
  local name="$1"
  local env_file="$ENVS_DIR/${name}.json"

  if [[ ! -f "$env_file" ]]; then
    error "Environment '$name' not found"
    exit 1
  fi

  local active=""
  [[ -f "$ACTIVE_FILE" ]] && active="$(cat "$ACTIVE_FILE")"

  if [[ "$JSON_OUTPUT" == true ]]; then
    if command -v jq &>/dev/null; then
      local is_active="false"
      [[ "$name" == "$active" ]] && is_active="true"
      jq --argjson active "$is_active" '.active = $active | .password = "***"' "$env_file"
    else
      python3 -c "
import json
with open('$env_file') as f: d = json.load(f)
d['active'] = d.get('name','') == '$active'
d['password'] = '***'
print(json.dumps(d, indent=2))
"
    fi
    return
  fi

  local h p u pw d s ci pi r ca notes
  h="$(json_get "$env_file" host)"
  p="$(json_get "$env_file" port)"
  u="$(json_get "$env_file" username)"
  pw="$(json_get "$env_file" password)"
  d="$(json_get "$env_file" database)"
  s="$(json_get "$env_file" ssl)"
  ca="$(json_get "$env_file" created_at)"
  notes="$(json_get "$env_file" notes)"

  # Cloud fields
  if command -v jq &>/dev/null; then
    ci="$(jq -r '.cloud.cluster_id // empty' "$env_file")"
    pi="$(jq -r '.cloud.project_id // empty' "$env_file")"
    r="$(jq -r '.cloud.region // empty' "$env_file")"
  else
    ci="$(python3 -c "import json; d=json.load(open('$env_file')); print(d.get('cloud',{}).get('cluster_id',''))")"
    pi="$(python3 -c "import json; d=json.load(open('$env_file')); print(d.get('cloud',{}).get('project_id',''))")"
    r="$(python3 -c "import json; d=json.load(open('$env_file')); print(d.get('cloud',{}).get('region',''))")"
  fi

  local is_active=""
  [[ "$name" == "$active" ]] && is_active=" (active)"

  echo "Environment: ${name}${is_active}"
  echo "  Host:       $h"
  echo "  Port:       $p"
  echo "  Username:   $u"
  echo "  Password:   $(mask_password "$pw")"
  echo "  Database:   $d"
  echo "  SSL:        $s"
  if [[ -n "$ci" ]]; then
    echo "  Cluster ID: $ci"
  fi
  if [[ -n "$pi" ]]; then
    echo "  Project ID: $pi"
  fi
  if [[ -n "$r" ]]; then
    echo "  Region:     $r"
  fi
  if [[ -n "$ca" ]]; then
    echo "  Created:    $ca"
  fi
  if [[ -n "$notes" ]]; then
    echo "  Notes:      $notes"
  fi
}

cmd_switch() {
  local name="$1"
  local env_file="$ENVS_DIR/${name}.json"

  if [[ ! -f "$env_file" ]]; then
    error "Environment '$name' not found"
    exit 1
  fi

  # Write active file
  echo "$name" > "$ACTIVE_FILE"

  # Read env values
  local h p u pw d s
  h="$(json_get "$env_file" host)"
  p="$(json_get "$env_file" port)"
  u="$(json_get "$env_file" username)"
  pw="$(json_get "$env_file" password)"
  d="$(json_get "$env_file" database)"
  s="$(json_get "$env_file" ssl)"

  # Build TIDB_* block
  local tidb_block=""
  tidb_block+="TIDB_HOST=$h"$'\n'
  tidb_block+="TIDB_PORT=$p"$'\n'
  tidb_block+="TIDB_USERNAME=$u"$'\n'
  tidb_block+="TIDB_PASSWORD=$pw"$'\n'
  tidb_block+="TIDB_DATABASE=$d"$'\n'
  tidb_block+="TIDB_SSL=$s"

  if [[ -f "$DOT_ENV" ]]; then
    # Remove existing TIDB_* lines, preserve everything else
    local other_lines
    other_lines="$(grep -v '^TIDB_' "$DOT_ENV" | grep -v '^# TiDB environment' || true)"
    # Remove trailing blank lines (macOS + Linux compatible)
    while [[ "$other_lines" == *$'\n' ]]; do
      other_lines="${other_lines%$'\n'}"
    done
    if [[ -n "$other_lines" ]]; then
      printf '%s\n\n# TiDB environment: %s\n%s\n' "$other_lines" "$name" "$tidb_block" > "$DOT_ENV"
    else
      printf '# TiDB environment: %s\n%s\n' "$name" "$tidb_block" > "$DOT_ENV"
    fi
  else
    printf '# TiDB environment: %s\n%s\n' "$name" "$tidb_block" > "$DOT_ENV"
  fi

  info "Switched to environment: $name"
  info "Updated $DOT_ENV with TIDB_* variables"
  info "Run /mcp to reconnect the TiDB MCP server with the new environment."

  if [[ "$JSON_OUTPUT" == true ]]; then
    echo "{\"status\":\"ok\",\"active\":\"$name\"}"
  fi
}

cmd_import() {
  local name="" env_file="${DOT_ENV}"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --name) name="$2"; shift 2 ;;
      --file) env_file="$2"; shift 2 ;;
      *) error "Unknown flag: $1"; exit 1 ;;
    esac
  done

  if [[ -z "$name" ]]; then
    error "Required: --name"
    exit 1
  fi

  if [[ ! -f "$env_file" ]]; then
    error "File not found: $env_file"
    exit 1
  fi

  # Read TIDB_* from env file
  local host="" port="4000" username="" password="" database="" ssl="true"

  while IFS='=' read -r key value; do
    # Strip quotes and whitespace
    value="$(echo "$value" | sed -e 's/^["\x27]//' -e 's/["\x27]$//' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
    case "$key" in
      TIDB_HOST)     host="$value" ;;
      TIDB_PORT)     port="$value" ;;
      TIDB_USER|TIDB_USERNAME) username="$value" ;;
      TIDB_PASSWORD) password="$value" ;;
      TIDB_DATABASE) database="$value" ;;
      TIDB_SSL)      ssl="$value" ;;
    esac
  done < <(grep '^TIDB_' "$env_file" || true)

  if [[ -z "$host" ]]; then
    error "No TIDB_HOST found in $env_file"
    exit 1
  fi

  cmd_add --name "$name" --host "$host" --port "$port" --username "${username:-root}" \
          --password "${password:-}" --database "${database:-test}" --ssl "${ssl:-true}"

  info "Imported from $env_file as '$name'"
}

# --- Main -------------------------------------------------------------------

usage() {
  cat << 'EOF'
Usage: tidb-env.sh [--json] <command> [args]

Commands:
  init                          Initialize .tidb/ directory
  add     --name N --host H ... Add an environment manually
  create  --name N [--region R] Create a TiDB Serverless cluster and register it
  zero    --name N [--tag T]    Create ephemeral TiDB Cloud Zero database
  remove  <name>                Remove an environment
  list                          List all environments
  switch  <name>                Switch active environment (updates .env)
  show    <name>                Show environment details
  import  --name N [--file F]   Import environment from .env file

Global flags:
  --json                        Machine-readable JSON output
EOF
}

# Parse global flags
while [[ $# -gt 0 ]]; do
  case "$1" in
    --json) JSON_OUTPUT=true; shift ;;
    *)      break ;;
  esac
done

if [[ $# -eq 0 ]]; then
  usage
  exit 0
fi

COMMAND="$1"; shift

case "$COMMAND" in
  init)    cmd_init ;;
  add)     cmd_add "$@" ;;
  create)  cmd_create "$@" ;;
  zero)    cmd_zero "$@" ;;
  remove)
    [[ $# -lt 1 ]] && { error "Usage: tidb-env.sh remove <name>"; exit 1; }
    cmd_remove "$1"
    ;;
  list)    cmd_list ;;
  switch)
    [[ $# -lt 1 ]] && { error "Usage: tidb-env.sh switch <name>"; exit 1; }
    cmd_switch "$1"
    ;;
  show)
    [[ $# -lt 1 ]] && { error "Usage: tidb-env.sh show <name>"; exit 1; }
    cmd_show "$1"
    ;;
  import)  cmd_import "$@" ;;
  help|-h|--help) usage ;;
  *)
    error "Unknown command: $COMMAND"
    usage
    exit 1
    ;;
esac
