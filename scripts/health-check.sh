#!/usr/bin/env bash
#
# health-check.sh - quick cpu/mem/disk/load summary. Exits non-zero when
# anything is over its warning threshold, so cron can catch it.
# Tested on Ubuntu 22.04.
#
set -euo pipefail

cpu_warn=80
mem_warn=85
disk_warn=85
mount="/"

usage() {
    cat <<EOF
Usage: $(basename "$0") [--cpu-warn N] [--mem-warn N] [--disk-warn N] [--mount PATH]

Prints a one-line summary of cpu/mem/disk/load and exits 1 if any
metric is over its warning threshold.
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --cpu-warn)  cpu_warn="$2"; shift 2 ;;
        --mem-warn)  mem_warn="$2"; shift 2 ;;
        --disk-warn) disk_warn="$2"; shift 2 ;;
        --mount)     mount="$2"; shift 2 ;;
        -h|--help)   usage; exit 0 ;;
        *) echo "error: unknown flag '$1'" >&2; usage >&2; exit 2 ;;
    esac
done

# cpu: 100 - idle from a 1s sample. Good enough for a warning check.
cpu_idle=$(vmstat 1 2 | tail -1 | awk '{print $15}')
cpu_used=$(( 100 - cpu_idle ))

mem_total=$(awk '/MemTotal/ {print $2}' /proc/meminfo)
mem_avail=$(awk '/MemAvailable/ {print $2}' /proc/meminfo)
mem_used=$(( (mem_total - mem_avail) * 100 / mem_total ))

disk_used=$(df -P "$mount" | awk 'NR==2 {gsub(/%/,"",$5); print $5}')

load1=$(cut -d' ' -f1 /proc/loadavg)

echo "cpu=${cpu_used}% mem=${mem_used}% disk(${mount})=${disk_used}% load1=${load1}"

failed=0
(( cpu_used  >= cpu_warn  )) && { echo "WARN: cpu ${cpu_used}% >= ${cpu_warn}%";  failed=1; }
(( mem_used  >= mem_warn  )) && { echo "WARN: mem ${mem_used}% >= ${mem_warn}%";  failed=1; }
(( disk_used >= disk_warn )) && { echo "WARN: disk ${disk_used}% >= ${disk_warn}%"; failed=1; }

exit "$failed"
