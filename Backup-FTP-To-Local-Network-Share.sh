#!/bin/bash

#####################################################################
# Pure SFTP Download Backup Script
# - Downloads remote directory via SFTP (password auth)
# - Stages content in a local directory
# - Archives into a date-named .tar.gz
# - Deletes staged folder afterward
# - Retains archives for RETENTION_DAYS
#####################################################################

########## CONFIGURATION ##########

# SFTP server credentials
SFTP_HOST="example.com"
SFTP_USER="youruser"
SFTP_PASS="yourpassword"
SFTP_PORT="22"

# Remote directory to back up
REMOTE_DIR="/remote/data"

# Local staging directory (where raw downloaded files go)
LOCAL_STAGING_DIR="/mnt/backup/staging"

# Local archive directory (final .tar.gz files)
LOCAL_ARCHIVE_DIR="/mnt/backup/archives"

# Number of days to keep archive files
RETENTION_DAYS=14

###################################

# Generate date-based folder and archive names
DATESTAMP=$(date +%Y-%m-%d)
STAGING_TARGET="$LOCAL_STAGING_DIR/backup-$DATESTAMP"
ARCHIVE_NAME="backup-$DATESTAMP.tar.gz"
ARCHIVE_PATH="$LOCAL_ARCHIVE_DIR/$ARCHIVE_NAME"

# Ensure directories exist
mkdir -p "$STAGING_TARGET"
mkdir -p "$LOCAL_ARCHIVE_DIR"

echo "===== Backup Started: $(date) ====="
echo "Staging to: $STAGING_TARGET"
echo "Archive will be: $ARCHIVE_PATH"

########## DOWNLOAD VIA PURE SFTP ##########

sshpass -p "$SFTP_PASS" sftp -oPort="$SFTP_PORT" -oBatchMode=no "$SFTP_USER@$SFTP_HOST" <<EOF
lcd "$STAGING_TARGET"
cd "$REMOTE_DIR"
get -r .
bye
EOF

if [ $? -ne 0 ]; then
    echo "ERROR: SFTP download failed."
    exit 1
fi

echo "Download completed."

########## CREATE ARCHIVE ##########

echo "Creating compressed archive: $ARCHIVE_PATH"
tar -czf "$ARCHIVE_PATH" -C "$STAGING_TARGET" .

if [ $? -ne 0 ]; then
    echo "ERROR: Failed to create archive."
    exit 1
fi

echo "Archive created."

########## REMOVE STAGING DIRECTORY ##########

echo "Cleaning up staging directory..."
rm -rf "$STAGING_TARGET"

########## RETENTION CLEANUP ##########

echo "Removing archive backups older than $RETENTION_DAYS days..."

find "$LOCAL_ARCHIVE_DIR" -name "backup-*.tar.gz" -mtime +"$RETENTION_DAYS" -print -delete

echo "Retention cleanup complete."

echo "===== Backup Finished: $(date) ====="

