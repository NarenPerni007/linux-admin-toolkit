#!/usr/bin/env bash
#
# archive-logs.sh - gzip logs older than N days, optionally push to S3,
# then delete the local originals once the upload succeeded.
#
set -euo pipefail

usage() {
    cat <<EOF
Usage: $(basename "$0") LOG_DIR DAYS [S3_BUCKET]

Compresses *.log files in LOG_DIR older than DAYS days. If S3_BUCKET
is given (s3://bucket/prefix), uploads the .gz files and removes the
local copies only after a successful upload.

Example:
  $(basename "$0") /var/log/myapp 30 s3://my-backups/log-archive
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
    exit 0
fi

if [[ $# -lt 2 ]]; then
    usage >&2
    exit 2
fi

log_dir="$1"
days="$2"
s3_bucket="${3:-}"

if [[ ! -d "$log_dir" ]]; then
    echo "error: not a directory: $log_dir" >&2
    exit 2
fi

if [[ -n "$s3_bucket" ]] && ! command -v aws >/dev/null 2>&1; then
    echo "error: aws cli not found but S3_BUCKET was given" >&2
    exit 2
fi

count=0
while IFS= read -r -d '' logfile; do
    gzip -9 "$logfile"
    gz="${logfile}.gz"
    if [[ -n "$s3_bucket" ]]; then
        aws s3 cp "$gz" "$s3_bucket/"
        rm -f "$gz"
        echo "archived+uploaded: $gz"
    else
        echo "archived: $gz"
    fi
    count=$((count + 1))
done < <(find "$log_dir" -maxdepth 1 -type f -name '*.log' -mtime +"$days" -print0)

echo "done, $count file(s) processed"
