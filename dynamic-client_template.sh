#!/bin/sh

set -u

DNS_NAME="${RELAY_DYNAMIC_CLIENT:-}"
INTERVAL="${RELAY_DYNAMIC_CLIENT_INTERVAL:-60}"
MAP_FILE="${RELAY_DYNAMIC_CLIENT_MAP:-/data/dynamic-client.cidr}"
LOCK_DIR="/tmp/dynamic-client.lock"

log()
{
    printf '%s [dynamic-client] %s\n' \
        "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" \
        "$*"
}

validate_interval()
{
    case "$INTERVAL" in
        ''|*[!0-9]*)
            log "ERROR: Invalid update interval: $INTERVAL"
            return 1
            ;;
    esac

    if [ "$INTERVAL" -lt 30 ] || [ "$INTERVAL" -gt 86400 ]; then
        log "ERROR: Interval must be between 30 and 86400 seconds."
        return 1
    fi
}

validate_ipv4()
{
    printf '%s\n' "$1" |
        awk -F. '
            NF != 4 {
                exit 1
            }

            {
                for (i = 1; i <= 4; i++) {
                    if ($i !~ /^[0-9]+$/)
                        exit 1

                    if ($i < 0 || $i > 255)
                        exit 1
                }
            }
        '
}

resolve_ipv4()
{
    getent ahostsv4 "$DNS_NAME" 2>/dev/null |
        awk '$1 ~ /^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$/ {
            print $1
            exit
        }'
}

acquire_lock()
{
    if mkdir "$LOCK_DIR" 2>/dev/null; then
        return 0
    fi

    log "WARNING: Another update operation is already running."
    return 1
}

release_lock()
{
    rmdir "$LOCK_DIR" 2>/dev/null || true
}

update_map()
{
    IP="$(resolve_ipv4)"

    if [ -z "$IP" ]; then
        log "WARNING: DNS lookup failed for $DNS_NAME; keeping previous configuration."
        return 1
    fi

    if ! validate_ipv4 "$IP"; then
        log "ERROR: DNS returned invalid IPv4 address: $IP"
        return 1
    fi

    MAP_DIR="$(dirname "$MAP_FILE")"
    TMP_FILE="${MAP_FILE}.tmp.$$"

    mkdir -p "$MAP_DIR"

    {
        printf '# Automatically generated. Do not edit.\n'
        printf '# Source: %s\n' "$DNS_NAME"
        printf '# Updated: %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
        printf '%s/32 OK\n' "$IP"
        printf '0.0.0.0/0 REJECT Client IP is not authorized\n'
    } > "$TMP_FILE"

    if [ -f "$MAP_FILE" ]; then
        OLD_IP="$(
            awk '
                $1 ~ /^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+\/32$/ {
                    sub("/32$", "", $1)
                    print $1
                    exit
                }
            ' "$MAP_FILE"
        )"

        if [ "$OLD_IP" = "$IP" ]; then
            rm -f "$TMP_FILE"
            return 0
        fi
    fi

    chmod 0644 "$TMP_FILE"
    mv -f "$TMP_FILE" "$MAP_FILE"

    log "Client IP updated: $DNS_NAME -> $IP"

    if ! postfix check; then
        log "ERROR: postfix check failed after updating $MAP_FILE."
        return 1
    fi

    if postfix status >/dev/null 2>&1; then
        postfix reload
        log "Postfix reloaded."
    else
        log "Postfix is not running yet; reload skipped."
    fi

    return 0
}

run_once()
{
    if ! acquire_lock; then
        return 1
    fi

    # Always release the lock when the current operation is interrupted.
    trap 'release_lock; exit 1' INT TERM HUP

    update_map
    RESULT=$?

    # IMPORTANT:
    # Release the lock after every single update operation.
    # Do not wait for the complete --loop process to exit.
    release_lock

    # Remove signal handlers for the completed operation.
    trap - INT TERM HUP

    return "$RESULT"
}

run_loop()
{
    # Remove a possible stale lock left behind by a crashed or
    # previously terminated updater process.
    rm -rf "$LOCK_DIR"

    log "Updater started."
    log "DNS name: $DNS_NAME"
    log "Interval: ${INTERVAL}s"
    log "CIDR map: $MAP_FILE"

    while true; do
        run_once || true
        sleep "$INTERVAL"
    done
}

if [ -z "$DNS_NAME" ]; then
    log "ERROR: RELAY_DYNAMIC_CLIENT is empty."
    exit 1
fi

validate_interval || exit 1

case "${1:-}" in
    --init|--once)
        run_once
        ;;

    --loop|'')
        run_loop
        ;;

    *)
        echo "Usage: $0 [--init|--once|--loop]" >&2
        exit 2
        ;;
esac
