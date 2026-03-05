#!/usr/bin/env python3
"""
Automated Database Backup Script for Story Weaver
Supports PostgreSQL backups with point-in-time recovery
"""

import os
import subprocess
import datetime
import gzip
import shutil
from pathlib import Path

# Configuration
BACKUP_DIR = Path("/backups")  # Mount this volume in Railway
DATABASE_URL = os.getenv("DATABASE_URL")
RETENTION_DAYS = 30

def create_backup():
    """Create a database backup"""
    timestamp = datetime.datetime.utcnow().strftime("%Y%m%d_%H%M%S")
    backup_filename = f"story_weaver_backup_{timestamp}.sql.gz"
    backup_path = BACKUP_DIR / backup_filename

    print(f"Starting backup: {backup_filename}")

    try:
        # Extract connection details from DATABASE_URL
        # Format: postgresql://user:password@host:port/database
        if not DATABASE_URL or not DATABASE_URL.startswith("postgresql://"):
            raise ValueError("Invalid DATABASE_URL")

        # Use pg_dump to create backup
        cmd = [
            "pg_dump",
            DATABASE_URL,
            "--no-owner",
            "--no-privileges",
            "--clean",
            "--if-exists",
            "--compress=9"
        ]

        with gzip.open(backup_path, 'wb') as f:
            result = subprocess.run(cmd, stdout=f, stderr=subprocess.PIPE, text=True)

        if result.returncode != 0:
            raise Exception(f"pg_dump failed: {result.stderr}")

        print(f"Backup created successfully: {backup_path}")
        print(f"Backup size: {backup_path.stat().st_size} bytes")

        return backup_path

    except Exception as e:
        print(f"Backup failed: {e}")
        raise

def cleanup_old_backups():
    """Remove backups older than retention period"""
    cutoff_date = datetime.datetime.utcnow() - datetime.timedelta(days=RETENTION_DAYS)

    removed_count = 0
    for backup_file in BACKUP_DIR.glob("story_weaver_backup_*.sql.gz"):
        try:
            # Extract timestamp from filename
            timestamp_str = backup_file.stem.replace("story_weaver_backup_", "")
            file_date = datetime.datetime.strptime(timestamp_str, "%Y%m%d_%H%M%S")

            if file_date < cutoff_date:
                backup_file.unlink()
                removed_count += 1
                print(f"Removed old backup: {backup_file}")
        except (ValueError, OSError) as e:
            print(f"Error processing {backup_file}: {e}")

    print(f"Cleaned up {removed_count} old backups")

def verify_backup(backup_path):
    """Verify backup integrity"""
    try:
        # Try to read the gzip file
        with gzip.open(backup_path, 'rb') as f:
            # Read first few bytes to verify it's a valid SQL dump
            header = f.read(100)
            if b"-- PostgreSQL database dump" not in header:
                raise ValueError("Invalid backup file format")

        print(f"Backup verification successful: {backup_path}")
        return True

    except Exception as e:
        print(f"Backup verification failed: {e}")
        return False

def restore_backup(backup_path, target_db_url=None):
    """Restore from backup (for disaster recovery)"""
    if target_db_url is None:
        target_db_url = DATABASE_URL

    print(f"Restoring from backup: {backup_path}")

    try:
        with gzip.open(backup_path, 'rb') as f:
            result = subprocess.run(
                ["psql", target_db_url],
                stdin=f,
                stderr=subprocess.PIPE,
                text=True
            )

        if result.returncode != 0:
            raise Exception(f"Restore failed: {result.stderr}")

        print("Database restore completed successfully")

    except Exception as e:
        print(f"Restore failed: {e}")
        raise

def point_in_time_recovery(target_timestamp):
    """Perform point-in-time recovery using WAL logs"""
    # This would require WAL archiving setup in PostgreSQL
    # For Railway, this might need to be handled through their backup system
    print(f"Point-in-time recovery to {target_timestamp} not implemented for Railway")
    print("Use Railway dashboard for point-in-time recovery")

def main():
    """Main backup execution"""
    try:
        # Ensure backup directory exists
        BACKUP_DIR.mkdir(exist_ok=True)

        # Create backup
        backup_path = create_backup()

        # Verify backup
        if verify_backup(backup_path):
            print("✅ Backup completed and verified successfully")
        else:
            print("❌ Backup verification failed")
            return 1

        # Cleanup old backups
        cleanup_old_backups()

        # List current backups
        backups = list(BACKUP_DIR.glob("story_weaver_backup_*.sql.gz"))
        print(f"Current backups: {len(backups)}")
        for backup in sorted(backups, reverse=True)[:5]:  # Show latest 5
            size_mb = backup.stat().st_size / (1024 * 1024)
            print(".2f")

        return 0

    except Exception as e:
        print(f"❌ Backup process failed: {e}")
        return 1

if __name__ == "__main__":
    exit(main())