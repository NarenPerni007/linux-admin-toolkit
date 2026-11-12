#!/usr/bin/env bash
#
# disk-usage-report.sh - work out why a filesystem is full.
#
# The case this is for: df says 100% but du on the obvious directories
# does not add up to anywhere near that. That mismatch usually has one
# of three causes, and this script checks all of them in one pass:
#
#   1. Deleted files that a running process still holds open. The space
#      only comes back when the process exits or restarts, and du
#      cannot see these files at all because they have no name left.
#   2. Inodes running out while bytes are still free, which happens
#      with lots of small files (cache dirs, session files, mail queues).
#   3. Something genuinely large hiding a couple of levels down, often
#      journals, container logs, or old core dumps.
#
# Read only. It never deletes, truncates, or restarts anything, it just
# prints what it finds so you can decide what to do next.
#
set -euo pipefail

top_n=10
target="/"

usage() {
    cat <<EOF
Usage: $(basename "$0") [--top N] [PATH]

Prints a disk usage report for the filesystem holding PATH
(default /): usage and inode usage, the largest directories,
the largest files, files deleted but still held open, and how
much space the systemd journal is using.

  --top N   how many entries to show in each list (default 10)
  PATH      file or directory on the filesystem to check (default /)

Read only: nothing is deleted or changed.
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --top)     top_n="$2"; shift 2 ;;
        -h|--help) usage; exit 0 ;;
        -*)        echo "error: unknown flag '$1'" >&2; usage >&2; exit 2 ;;
        *)         target="$1"; shift ;;
    esac
done

if ! [[ "$top_n" =~ ^[0-9]+$ ]] || (( top_n < 1 )); then
    echo "error: --top must be a positive number, got '$top_n'" >&2
    exit 2
fi

if [[ ! -e "$target" ]]; then
    echo "error: no such path: $target" >&2
    exit 2
fi

# Work on the mount point itself so -xdev in the finds below stays on
# the one filesystem that is actually full.
mount_point=$(df -P "$target" | awk 'NR==2 {print $6}')

echo "Disk report for $target (mount $mount_point) on $(hostname -s)"
echo

echo "== Filesystem usage =="
df -h "$mount_point"
echo

echo "== Inode usage =="
echo "If this is at 100% while the filesystem above is not, look for"
echo "directories holding very large numbers of small files."
df -i "$mount_point"
echo

echo "== Largest directories under $mount_point (top $top_n) =="
du -x --max-depth=1 "$mount_point" 2>/dev/null \
    | sort -rn \
    | head -n "$top_n" \
    | while read -r size path; do printf '%8s  %s\n' "$(numfmt --to=iec "$((size * 1024))" 2>/dev/null || echo "$size")" "$path"; done
echo

echo "== Largest files on this filesystem (top $top_n) =="
find "$mount_point" -xdev -type f -printf '%s %p\n' 2>/dev/null \
    | sort -rn \
    | head -n "$top_n" \
    | while read -r size path; do printf '%8s  %s\n' "$(numfmt --to=iec "$size" 2>/dev/null || echo "$size")" "$path"; done
echo

echo "== Deleted but still open (space not freed until the process lets go) =="
if command -v lsof >/dev/null 2>&1; then
    # +L1 lists unlinked files with a link count below 1. The SIZE/OFF
    # column is the one that matters here: a multi GB entry in this
    # list is space df counts and du cannot see.
    lsof +L1 -nP 2>/dev/null | head -n $((top_n + 1)) || echo "none found"
    echo "Fix is to restart the process named above, not to delete anything."
else
    echo "lsof is not installed, skipping this check."
    echo "Install it with: sudo apt install lsof"
    echo "Without it, compare the df total against the du total. A large"
    echo "gap between them is the usual sign of deleted but open files."
fi
echo

echo "== systemd journal =="
if command -v journalctl >/dev/null 2>&1; then
    journalctl --disk-usage 2>/dev/null || echo "journalctl could not report usage"
else
    echo "journalctl not found, skipping."
fi
echo

echo "Done. Nothing was deleted or changed by this script."
