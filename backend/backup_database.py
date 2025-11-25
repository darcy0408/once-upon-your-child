import os
from datetime import datetime
import subprocess

DATABASE_URL = os.getenv('DATABASE_URL')
BACKUP_DIR = '/app/backups'

def create_backup():
    if not DATABASE_URL:
        print("DATABASE_URL not set")
        return None

    os.makedirs(BACKUP_DIR, exist_ok=True)
    timestamp = datetime.utcnow().strftime('%Y%m%d_%H%M%S')
    backup_file = f"{BACKUP_DIR}/backup_{timestamp}.sql"

    try:
        # Create backup using pg_dump
        result = subprocess.run([
            'pg_dump',
            DATABASE_URL,
            '-f', backup_file,
            '--no-owner',
            '--no-privileges'
        ], capture_output=True, text=True)

        if result.returncode == 0:
            print(f"Backup created: {backup_file}")
            return backup_file
        else:
            print(f"Backup failed: {result.stderr}")
            return None
    except Exception as e:
        print(f"Backup error: {e}")
        return None

def cleanup_old_backups(keep_days=7):
    """Remove backups older than keep_days"""
    import glob
    from datetime import timedelta

    if not os.path.exists(BACKUP_DIR):
        return

    cutoff = datetime.utcnow() - timedelta(days=keep_days)
    pattern = os.path.join(BACKUP_DIR, "backup_*.sql")

    for backup_file in glob.glob(pattern):
        try:
            # Extract timestamp from filename
            filename = os.path.basename(backup_file)
            timestamp_str = filename.replace('backup_', '').replace('.sql', '')
            file_date = datetime.strptime(timestamp_str, '%Y%m%d_%H%M%S')

            if file_date < cutoff:
                os.remove(backup_file)
                print(f"Removed old backup: {backup_file}")
        except Exception as e:
            print(f"Error processing {backup_file}: {e}")

if __name__ == '__main__':
    backup_file = create_backup()
    if backup_file:
        cleanup_old_backups()
    else:
        exit(1)</content>
<parameter name="filePath">/mnt/c/dev/story-weaver-app/backend/backup_database.py