#!/bin/bash
#
# Full system backup with local staging → tar.gz on NAS → cleanup
# Run as root.

set -uo pipefail   # handle errors manually

#### CONFIG ####
MOUNT_ROOT="/mnt/LOCAL-NAS-MOUNT"

# Local disk for staging (must have enough space!)
STAGING_DIR="/var/backups/LOCAL-STAGING-DIR"

# Remote/NAS for final archives
ARCHIVE_DIR="${MOUNT_ROOT}/LOCAL-NAS-DIR"

BACKUP_PREFIX="full-system"
RETENTION_DAYS=14
################

# Sanity checks
if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root." >&2
  exit 1
fi

# Make sure the NAS is mounted
if ! mountpoint -q "$MOUNT_ROOT"; then
  echo "ERROR: $MOUNT_ROOT is not a mountpoint. Mount your storage first." >&2
  exit 1
fi

# Ensure dirs exist
mkdir -p "$STAGING_DIR"
mkdir -p "$ARCHIVE_DIR"

HOSTNAME_SHORT=$(hostname -s || echo "unknownhost")
DATE_STR=$(date +"%Y%m%d-%H%M%S")
BACKUP_FILENAME="${BACKUP_PREFIX}-${HOSTNAME_SHORT}-${DATE_STR}.tar.gz"
BACKUP_FILE="${ARCHIVE_DIR}/${BACKUP_FILENAME}"

echo "===== $(date) ====="
echo "Starting full system backup"
echo "Staging directory : $STAGING_DIR"
echo "Archive directory : $ARCHIVE_DIR"
echo "Archive file      : $BACKUP_FILE"
echo

###################################
# 1. Rsync system into local staging
###################################
echo "[*] Staging filesystem into $STAGING_DIR ..."

rsync -aAXH --delete \
  --links \
  --no-inc-recursive \
  --ignore-errors \
  --exclude="$STAGING_DIR" \
  --exclude="$ARCHIVE_DIR" \
  --exclude="$MOUNT_ROOT" \
  --exclude=/proc \
  --exclude=/sys \
  --exclude=/dev \
  --exclude=/run \
  --exclude=/tmp \
  --exclude=/var/tmp \
  --exclude=/var/cache \
  --exclude=/lost+found \
  --exclude=/mnt \
  --exclude=/media \
  / "$STAGING_DIR"

RSYNC_EXIT=$?

if [[ $RSYNC_EXIT -ne 0 ]]; then
  case $RSYNC_EXIT in
    23|24)
      echo "[!] rsync completed with some files skipped (exit code $RSYNC_EXIT)."
      echo "    Usually harmless (vanishing files, special files). Continuing."
      ;;
    *)
      echo "[!] rsync failed with exit code $RSYNC_EXIT – aborting backup."
      exit "$RSYNC_EXIT"
      ;;
  esac
fi

echo "[+] Staging complete."
echo

###################################
# 2. Create tar.gz from staging on NAS
###################################
echo "[*] Creating archive $BACKUP_FILE ..."

tar -czf "$BACKUP_FILE" -C "$STAGING_DIR" .

TAR_EXIT=$?
if [[ $TAR_EXIT -ne 0 ]]; then
  echo "[!] tar failed with exit code $TAR_EXIT – aborting."
  exit "$TAR_EXIT"
fi

echo "[+] Archive created."
echo

###################################
# 3. Clean up staging directory
###################################
echo "[*] Cleaning staging directory $STAGING_DIR ..."

# Remove everything inside STAGING_DIR, but not the dir itself
find "$STAGING_DIR" -mindepth 1 -maxdepth 1 -exec rm -rf {} +

echo "[+] Staging directory emptied."
echo

###################################
# 4. Prune old archives on NAS
###################################
echo "[*] Pruning archives older than $RETENTION_DAYS days in $ARCHIVE_DIR ..."

find "$ARCHIVE_DIR" \
  -maxdepth 1 \
  -type f \
  -name "${BACKUP_PREFIX}-${HOSTNAME_SHORT}-*.tar.gz" \
  -mtime +"$RETENTION_DAYS" \
  -print -delete

echo "[+] Pruning complete."
echo "===== Backup run finished at $(date) ====="

