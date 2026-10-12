#!/usr/bin/env bash
#
# add-user.sh - create a user, install their ssh key, add to sudo.
# Run as root.
#
set -euo pipefail

usage() {
    cat <<EOF
Usage: sudo $(basename "$0") USERNAME PUBKEY_FILE

Creates USERNAME, sets up ~/.ssh/authorized_keys from PUBKEY_FILE,
and adds the user to the sudo group.
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
    exit 0
fi

if [[ $# -ne 2 ]]; then
    usage >&2
    exit 2
fi

username="$1"
pubkey="$2"

if [[ $EUID -ne 0 ]]; then
    echo "error: run as root" >&2
    exit 2
fi

if id "$username" &>/dev/null; then
    echo "error: user '$username' already exists" >&2
    exit 1
fi

if [[ ! -f "$pubkey" ]]; then
    echo "error: pubkey file not found: $pubkey" >&2
    exit 2
fi

useradd -m -s /bin/bash "$username"
usermod -aG sudo "$username"

ssh_dir="/home/$username/.ssh"
mkdir -p "$ssh_dir"
cp "$pubkey" "$ssh_dir/authorized_keys"
chmod 700 "$ssh_dir"
chmod 600 "$ssh_dir/authorized_keys"
chown -R "$username:$username" "$ssh_dir"

echo "user '$username' created with sudo access"
