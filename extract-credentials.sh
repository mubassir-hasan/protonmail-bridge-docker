#!/bin/bash
# Extract IMAP/SMTP credentials from a running ProtonMail Bridge container
# without stopping the bridge process.
#
# Usage:
#   ./extract-credentials.sh                              # defaults
#   ./extract-credentials.sh --output /path/to/creds.json
#   ./extract-credentials.sh --container my-bridge
#   ./extract-credentials.sh --wait 5
#
# Cron example (every 6 hours):
#   0 */6 * * * /path/to/extract-credentials.sh >> /var/log/protonmail-credentials.log 2>&1

set -euo pipefail

# Prevent Git Bash (MSYS) from converting Linux paths to Windows paths
export MSYS_NO_PATHCONV=1

# --- Configuration ---
CONTAINER_NAME="${CONTAINER_NAME:-protonmail-bridge}"
PIPE_PATH="/protonmail/faketty"
OUTPUT_FILE="${OUTPUT_FILE:-./credentials/bridge-credentials.json}"
WAIT_SECONDS="${WAIT_SECONDS:-3}"
MAX_RETRIES=2

# --- Parse CLI arguments ---
while [[ $# -gt 0 ]]; do
    case $1 in
        --output)    OUTPUT_FILE="$2"; shift 2 ;;
        --container) CONTAINER_NAME="$2"; shift 2 ;;
        --wait)      WAIT_SECONDS="$2"; shift 2 ;;
        -h|--help)
            echo "Usage: $0 [--output <path>] [--container <name>] [--wait <seconds>]"
            exit 0
            ;;
        *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
done

# --- Functions ---
log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"; }
err() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1" >&2; }

check_container() {
    local status
    status=$(docker inspect -f '{{.State.Status}}' "$CONTAINER_NAME" 2>/dev/null || true)
    if [ "$status" != "running" ]; then
        err "Container '$CONTAINER_NAME' is not running (status: ${status:-not found})"
        exit 1
    fi
}

check_pipe() {
    if ! docker exec "$CONTAINER_NAME" test -p "$PIPE_PATH" 2>/dev/null; then
        err "Named pipe '$PIPE_PATH' not found in container. Is the bridge running in CLI mode?"
        exit 1
    fi
}

# Start a keepalive writer that holds the pipe open so that closing
# our temporary writers doesn't send EOF to the bridge CLI.
ensure_keepalive() {
    log "Starting keepalive writer on pipe..."
    docker exec -d "$CONTAINER_NAME" bash -c "exec 0</dev/null; sleep infinity > $PIPE_PATH"
    sleep 2
}

send_command() {
    local cmd="$1"
    docker exec "$CONTAINER_NAME" bash -c "echo '$cmd' > $PIPE_PATH" &
    local pid=$!
    local waited=0
    while kill -0 "$pid" 2>/dev/null && [ "$waited" -lt 5 ]; do
        sleep 1
        waited=$((waited + 1))
    done
    if kill -0 "$pid" 2>/dev/null; then
        kill "$pid" 2>/dev/null || true
        err "Pipe write timed out for command: $cmd"
        return 1
    fi
    return 0
}

# Strip ANSI escape codes from input
strip_ansi() {
    sed "s/$(printf '\033')\[[0-9;]*[a-zA-Z]//g"
}

# Capture recent log lines and strip ANSI codes
capture_recent_output() {
    local wait_time="$1"
    local tail_lines="${2:-20}"
    sleep "$wait_time"
    docker logs --tail "$tail_lines" "$CONTAINER_NAME" 2>&1 | strip_ansi
}

# Extract the IMAP/SMTP info block from raw log output
extract_info_block() {
    local raw="$1"
    echo "$raw" | awk '
        /IMAP Settings/ { capture=1 }
        capture { print }
        /Security:/ && capture && seen_smtp { capture=0; exit }
        /SMTP Settings/ { seen_smtp=1 }
    '
}

# Parse an info block into JSON
parse_info_to_json() {
    local block="$1"

    local imap_port smtp_port username password imap_security smtp_security

    imap_port=$(echo "$block" | awk '/IMAP port:/ {print $NF}')
    smtp_port=$(echo "$block" | awk '/SMTP port:/ {print $NF}')
    username=$(echo "$block" | awk '/Username:/ {print $NF; exit}')
    password=$(echo "$block" | awk '/Password:/ {print $NF; exit}')

    imap_security=$(echo "$block" | awk '/Security:/ {print $NF; exit}')
    smtp_security=$(echo "$block" | awk '/Security:/ {val=$NF} END {print val}')

    if [ -z "$username" ] || [ -z "$password" ]; then
        return 1
    fi

    cat <<EOF
    {
      "imap": {
        "port": ${imap_port:-null},
        "username": "${username}",
        "password": "${password}",
        "security": "${imap_security}"
      },
      "smtp": {
        "port": ${smtp_port:-null},
        "username": "${username}",
        "password": "${password}",
        "security": "${smtp_security}"
      }
    }
EOF
}

# Send info command and capture/parse output with retry
get_account_info() {
    local account_idx="$1"
    local attempt=0
    local wait_time="$WAIT_SECONDS"

    while [ "$attempt" -lt "$MAX_RETRIES" ]; do
        if ! send_command "info $account_idx"; then
            err "Failed to send 'info $account_idx' command"
            return 1
        fi

        local raw_output
        raw_output=$(capture_recent_output "$wait_time" 50)

        local info_block
        info_block=$(extract_info_block "$raw_output")

        if echo "$info_block" | grep -q "IMAP Settings"; then
            local parsed
            if parsed=$(parse_info_to_json "$info_block"); then
                echo "$parsed"
                return 0
            fi
        fi

        attempt=$((attempt + 1))
        wait_time=$((wait_time * 2))
        log "Retry $attempt/$MAX_RETRIES for account $account_idx (waiting ${wait_time}s)..."
    done

    err "Failed to get info for account $account_idx after $MAX_RETRIES attempts"
    return 1
}

# Discover accounts using the list command
discover_accounts() {
    if ! send_command "list"; then
        err "Failed to send 'list' command"
        return 1
    fi

    local raw_output
    raw_output=$(capture_recent_output "$WAIT_SECONDS" 50)

    # Extract account indices from lines like "0 : TytanTV  (connected, combined)"
    local indices
    indices=$(echo "$raw_output" | awk '/^[[:space:]]*[0-9]+[[:space:]]*:/ {for(i=1;i<=NF;i++) if($i ~ /^[0-9]+$/) {print $i; break}}' | tr -d '\r' | sort -n | uniq || true)

    if [ -z "$indices" ]; then
        err "No accounts found. Raw output:"
        err "$raw_output"
        return 1
    fi

    echo "$indices"
}

# --- Main ---
log "Starting credential extraction from container '$CONTAINER_NAME'..."

check_container
check_pipe
ensure_keepalive

log "Discovering accounts..."
ACCOUNT_INDICES=$(discover_accounts)
ACCOUNT_COUNT=$(echo "$ACCOUNT_INDICES" | wc -l | tr -d ' ')
log "Found $ACCOUNT_COUNT account(s): $(echo $ACCOUNT_INDICES | tr '\n' ' ')"

# Build JSON accounts object
JSON_ACCOUNTS=""
FIRST=true
SUCCESS_COUNT=0

for idx in $ACCOUNT_INDICES; do
    log "Extracting credentials for account $idx..."

    parsed=$(get_account_info "$idx" || true)

    if [ -z "$parsed" ]; then
        err "Skipping account $idx (failed to parse)"
        continue
    fi

    if [ "$FIRST" = true ]; then
        FIRST=false
    else
        JSON_ACCOUNTS+=","
    fi

    JSON_ACCOUNTS+="
    \"account_${idx}\": ${parsed}"
    SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
done

if [ "$SUCCESS_COUNT" -eq 0 ]; then
    err "Failed to extract credentials for any account"
    exit 1
fi

# Write JSON output
mkdir -p "$(dirname "$OUTPUT_FILE")"

cat > "$OUTPUT_FILE" <<EOF
{
  "generated_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "container": "$CONTAINER_NAME",
  "host_ports": {
    "smtp": 1028,
    "imap": 1154
  },
  "accounts": {${JSON_ACCOUNTS}
  }
}
EOF

chmod 600 "$OUTPUT_FILE"

log "Credentials for $SUCCESS_COUNT account(s) written to $OUTPUT_FILE"
