#!/usr/bin/env bash
#
# disk-alert.sh - ping a webhook when disk usage crosses a threshold.
# Run from cron. Webhook URL comes from the environment so it's never
# hardcoded in here.
#
#   export ALERT_WEBHOOK="https://hooks.slack.com/services/xxx"
#   */15 * * * * /opt/scripts/disk-alert.sh 85 /var
#
set -euo pipefail

usage() {
    cat <<EOF
Usage: $(basename "$0") [THRESHOLD] [MOUNT]

Checks disk usage on MOUNT and POSTs to \$ALERT_WEBHOOK when usage
is at or above THRESHOLD percent.

  THRESHOLD   integer 0-100, default 85
  MOUNT       mount point to check, default /

Env:
  ALERT_WEBHOOK   webhook URL (Slack/Discord compatible). Required.
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
    exit 0
fi

threshold="${1:-85}"
mount="${2:-/}"

if ! [[ "$threshold" =~ ^[0-9]+$ ]] || (( threshold > 100 )); then
    echo "error: threshold must be 0-100, got '$threshold'" >&2
    exit 2
fi

if [[ -z "${ALERT_WEBHOOK:-}" ]]; then
    echo "error: ALERT_WEBHOOK is not set" >&2
    exit 2
fi

# df -P keeps output on one line per filesystem.
usage_pct=$(df -P "$mount" | awk 'NR==2 {gsub(/%/,"",$5); print $5}')
hostname_short=$(hostname -s)

if (( usage_pct >= threshold )); then
    msg="Disk alert on $hostname_short: $mount is at ${usage_pct}% (threshold ${threshold}%)"
    if ! curl -fsS -X POST -H 'Content-Type: application/json' \
        -d "{\"text\": \"$msg\"}" \
        "$ALERT_WEBHOOK" >/dev/null; then
        echo "error: failed to post alert to webhook" >&2
        echo "$msg" >&2
        exit 1
    fi
    echo "$msg"
    exit 1
fi

echo "$mount at ${usage_pct}% - ok"
