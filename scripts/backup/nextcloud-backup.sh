#!/bin/bash
# Dump the Nextcloud database using Nextcloud's own DB credentials.
# Run before every Nextcloud upgrade. Assumes containers named "nextcloud" and "mariadb".
set -euo pipefail
BACKUP_DIR=${BACKUP_DIR:-/mnt/user/backups}
mkdir -p "$BACKUP_DIR"
DB=$(docker exec nextcloud occ config:system:get dbname)
DBU=$(docker exec nextcloud occ config:system:get dbuser)
DBP=$(docker exec nextcloud occ config:system:get dbpassword)
OUT="$BACKUP_DIR/nextcloud-db-$(date +%F-%H%M).sql"
docker exec -e MYSQL_PWD="$DBP" mariadb mariadb-dump -h127.0.0.1 -u"$DBU" --single-transaction "$DB" > "$OUT"
# Fail loudly on an empty or tiny dump (the failure mode in INC-1)
SIZE=$(stat -c %s "$OUT")
if [ "$SIZE" -lt 10240 ]; then
  echo "ERROR: backup is only $SIZE bytes, check credentials" >&2
  exit 1
fi
ls -lh "$OUT"
