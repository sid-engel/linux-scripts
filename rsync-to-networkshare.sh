#!/bin/bash
# Script to create full image backups of Arch Linux to a network share, delete backups older than 7 days,
# and log to image-backup.log in the script's directory

# I know this is on git and I'm exposing my mnt name here, but that's fine.

# Configuration
DATE=$(date '+%Y-%m-%d %H:%M:%S')
SCRIPT_DIR="$(dirname "$0")"
LOGFILE="$SCRIPT_DIR/image-backup.log"
CURRENT_BACKUP="/mnt/DeafDog/Archives/LittleDragon-Arch-Backups/current"
DATED_BACKUP="/mnt/DeafDog/Archives/LittleDragon-Arch-Backups/backup-$(date '+%Y%m%d-%H%M%S')"
BACKUP_ROOT="/mnt/DeafDog/Archives/LittleDragon-Arch-Backups"

# Step 1: Check if network share is mounted
if ! mountpoint -q /mnt/DeafDog; then
    echo "[$DATE] ERROR: Network share /mnt/DeafDog not mounted!" | tee -a "$LOGFILE"
    exit 1
fi

# Step 2: Create backup root directory
sudo mkdir -p "$BACKUP_ROOT"
if [ $? -ne 0 ]; then
    echo "[$DATE] ERROR: Failed to create $BACKUP_ROOT!" | tee -a "$LOGFILE"
    exit 1
fi

# Step 3: Delete backups older than 7 days
echo "[$DATE] Deleting backups older than 7 days in $BACKUP_ROOT" | tee -a "$LOGFILE"
sudo find "$BACKUP_ROOT" -maxdepth 1 -type d -name 'backup-*' -mtime +7 -exec rm -rf {} \;
if [ $? -ne 0 ]; then
    echo "[$DATE] WARNING: Failed to delete some old backups!" | tee -a "$LOGFILE"
fi

# Step 4: Rotate current backup contents
if [ -d "$CURRENT_BACKUP" ]; then
    echo "[$DATE] Rotating contents of $CURRENT_BACKUP to $DATED_BACKUP" | tee -a "$LOGFILE"
    sudo mkdir -p "$DATED_BACKUP"
    sudo find "$CURRENT_BACKUP" -maxdepth 1 -not -path "$CURRENT_BACKUP" -not -path "$DATED_BACKUP" -exec mv {} "$DATED_BACKUP/" \;
    if [ $? -ne 0 ]; then
        echo "[$DATE] ERROR: Rotation failed!" | tee -a "$LOGFILE"
        exit 1
    fi
fi

# Step 5: Fresh rsync mirror to current dir
echo "[$DATE] Syncing fresh backup to $CURRENT_BACKUP" | tee -a "$LOGFILE"
sudo mkdir -p "$CURRENT_BACKUP"
sudo rsync -aAX --progress --delete \
    --exclude='/dev/*' \
    --exclude='/proc/*' \
    --exclude='/sys/*' \
    --exclude='/tmp/*' \
    --exclude='/run/*' \
    --exclude='/mnt/*' \
    --exclude='/media/*' \
    --exclude='/lost+found' \
    --exclude='/home/sid/.cache/*' \
    / "$CURRENT_BACKUP" 2>&1 | tee -a "$LOGFILE"
if [ $? -ne 0 ]; then
    echo "[$DATE] ERROR: rsync failed!" | tee -a "$LOGFILE"
    exit 1
fi
