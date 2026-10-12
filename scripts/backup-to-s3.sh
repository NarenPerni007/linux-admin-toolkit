#!/usr/bin/env bash
#
# backup-to-s3.sh - tar up dirs, stamp with the date, push to S3,
# keep only the last N locally. S3-side expiry is handled by a
# lifecycle rule on the bucket (set that up once in the console).
#
set -euo pipefail

usage() {
    cat <<EOF
Usage: $(basename "$0") S3_BUCKET KEEP_N DIR [DIR...]

Tars each DIR into /var/backups/<name>-YYYYMMDD-HHMM.tar.gz,
uploads to S3_BUCKET, and deletes local archives older than
the newest KEEP_N.

Example:
  $(basename "$0") s3://my-backups/daily 7 /etc/nginx /opt/app/data
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
    exit 0
fi

if [[ $# -lt 3 ]]; then
    usage >&2
    exit 2
fi

s3_bucket="$1"
keep="$2"
shift 2

if ! command -v aws >/dev/null 2>&1; then
    echo "error: aws cli not found" >&2
    exit 2
fi

backup_dir="/var/backups"
mkdir -p "$backup_dir"
stamp=$(date +%Y%m%d-%H%M)

for dir in "$@"; do
    if [[ ! -d "$dir" ]]; then
        echo "warn: skipping, not a directory: $dir" >&2
        continue
    fi
    name=$(basename "$dir")
    archive="$backup_dir/${name}-${stamp}.tar.gz"
    tar -czf "$archive" -C "$(dirname "$dir")" "$name"
    aws s3 cp "$archive" "$s3_bucket/"
    echo "backed up: $archive"
done

# Prune local archives, keep newest $keep. S3 lifecycle handles the rest.
# shellcheck disable=SC2012
ls -t "$backup_dir"/*.tar.gz 2>/dev/null | tail -n +"$((keep + 1))" | xargs -r rm -f

echo "done, kept last $keep local archive(s)"
