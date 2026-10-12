#!/usr/bin/env bash
#
# patch-check.sh - list pending security updates on apt-based systems.
# Pass --apply to actually install them (use with care).
#
set -euo pipefail

apply=false

usage() {
    cat <<EOF
Usage: $(basename "$0") [--apply]

Without flags: prints the count and names of pending security updates.
With --apply: runs apt upgrade for security updates. If a reboot is
required, you'll see the standard /var/run/reboot-required notice -
unattended reboots are NOT done here on purpose.
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
    exit 0
fi
if [[ "${1:-}" == "--apply" ]]; then
    apply=true
fi

if ! command -v apt >/dev/null 2>&1; then
    echo "error: apt not found - this script is for Debian/Ubuntu" >&2
    exit 2
fi

# Refresh package lists quietly; ignore failures (offline mirrors happen).
sudo apt-get update -qq || true

# apt-get -s = simulate. Filter for -security pocket lines.
mapfile -t sec_updates < <(
    apt-get -s upgrade 2>/dev/null \
        | grep -oP '^Inst \K[^\s]+(?=.*-security)' \
        || true
)

count=${#sec_updates[@]}
echo "pending security updates: $count"
for pkg in "${sec_updates[@]}"; do
    echo "  $pkg"
done

# TODO: add an option to email this output instead of just cron.

if [[ "$apply" == true ]]; then
    if (( count == 0 )); then
        echo "nothing to install"
        exit 0
    fi
    echo "installing $count security update(s)..."
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y --only-upgrade "${sec_updates[@]}"
    if [[ -f /var/run/reboot-required ]]; then
        echo "NOTE: reboot required (see /var/run/reboot-required.pkgs)"
    fi
fi
