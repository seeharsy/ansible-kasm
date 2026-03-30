#!/bin/bash
# Usage: backup.sh <output_dir> <retention_days>

set -euo pipefail

if [[ -z "${1:-}" ]]; then
    echo "FATAL: Missing output dir argument" >&2
    exit 1
fi
OUTPUT_DIR="$1"

if [[ ! -d "$OUTPUT_DIR" ]]; then
    echo "FATAL: Cannot find dir $OUTPUT_DIR" >&2
    exit 1
fi

if [[ -z "${2:-}" ]]; then
    echo "FATAL: Missing retention period argument" >&2
    exit 1
fi
RETENTION_DAYS="$2"

mkdir -p "${OUTPUT_DIR}/${HOSTNAME}"

docker exec kasm_db /bin/bash -c \
    "pg_dump -U kasmapp -w -Ft --exclude-table-data=logs kasm | gzip > /tmp/db_backup.tar.gz"

DATE=$(date "+%Y%m%d_%H.%M.%S")
OUTPUT_FILE="${OUTPUT_DIR}/${HOSTNAME}/kasm_db_backup_${HOSTNAME}_${DATE}.tar.gz"

docker cp kasm_db:/tmp/db_backup.tar.gz "$OUTPUT_FILE"

find "${OUTPUT_DIR}/${HOSTNAME}" -name "*.tar.gz" -mtime +"${RETENTION_DAYS}" -type f -delete

echo "Database backed up to:"
echo "$OUTPUT_FILE"
