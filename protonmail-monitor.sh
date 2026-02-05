#!/bin/bash
# Protonmail Bridge Container Monitor
# Checks container status and restarts on errors
#
# This script runs as a systemd service and monitors the protonmail-bridge
# container. It will automatically restart the container if:
# - The container is not found (starts it)
# - The container has stopped/exited (restarts it)
# - Critical errors are detected in the logs (restarts it)

COMPOSE_DIR="/home/cicd_user/protonmail-bridge-docker"
CONTAINER_NAME="protonmail-bridge"
CHECK_INTERVAL=60
LOG_LINES=50

# Track last restart time to prevent restart loops
LAST_RESTART=0
MIN_RESTART_INTERVAL=300  # Minimum 5 minutes between restarts

log_message() {
    logger -t protonmail-monitor "$1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
}

check_and_restart() {
    local current_time=$(date +%s)

    # Check if container exists and is running
    local status=$(docker inspect -f '{{.State.Status}}' "$CONTAINER_NAME" 2>/dev/null)

    if [ -z "$status" ]; then
        log_message "Container $CONTAINER_NAME not found, starting..."
        cd "$COMPOSE_DIR" && docker compose up -d
        LAST_RESTART=$current_time
        return
    fi

    if [ "$status" != "running" ]; then
        log_message "Container $CONTAINER_NAME is $status, restarting..."
        cd "$COMPOSE_DIR" && docker compose up -d
        LAST_RESTART=$current_time
        return
    fi

    # Check logs for critical errors (only if enough time has passed since last restart)
    local time_since_restart=$((current_time - LAST_RESTART))
    if [ $time_since_restart -lt $MIN_RESTART_INTERVAL ]; then
        return
    fi

    local errors=$(docker logs --tail "$LOG_LINES" "$CONTAINER_NAME" 2>&1 | grep -iE "(fatal|panic|error.*failed|connection refused|segmentation fault)" || true)
    if [ -n "$errors" ]; then
        log_message "Errors detected in container logs, restarting..."
        log_message "Error sample: $(echo "$errors" | head -1)"
        cd "$COMPOSE_DIR" && docker compose restart "$CONTAINER_NAME"
        LAST_RESTART=$current_time
    fi
}

# Main entry point
main() {
    log_message "Starting Protonmail Bridge monitor (checking every ${CHECK_INTERVAL}s)"

    while true; do
        check_and_restart
        sleep "$CHECK_INTERVAL"
    done
}

main
