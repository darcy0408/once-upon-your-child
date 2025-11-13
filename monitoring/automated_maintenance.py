#!/usr/bin/env python3
"""
Story Weaver Automated Maintenance Script
Handles database cleanup, log rotation, cache management, and performance optimization
"""

import os
import sys
import time
import logging
from datetime import datetime, timedelta
from pathlib import Path

# Add backend to path for imports
sys.path.append(str(Path(__file__).parent.parent / "backend"))

try:
    import psycopg2
    from sqlalchemy import create_engine, text
    import redis
except ImportError as e:
    print(f"Missing dependencies: {e}")
    print("Install with: pip install psycopg2-binary sqlalchemy redis")
    sys.exit(1)

# Configuration
DATABASE_URL = os.getenv("DATABASE_URL")
REDIS_URL = os.getenv("REDIS_URL", "redis://localhost:6379")
LOG_RETENTION_DAYS = 30
CACHE_CLEANUP_INTERVAL = 3600  # 1 hour
DB_MAINTENANCE_INTERVAL = 86400  # 24 hours

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('/var/log/story-weaver/maintenance.log'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

class MaintenanceManager:
    def __init__(self):
        self.db_engine = None
        self.redis_client = None
        self.last_cache_cleanup = 0
        self.last_db_maintenance = 0

    def connect_database(self):
        """Establish database connection"""
        try:
            if DATABASE_URL:
                self.db_engine = create_engine(DATABASE_URL)
                logger.info("Database connection established")
            else:
                logger.warning("No DATABASE_URL provided, skipping database operations")
        except Exception as e:
            logger.error(f"Database connection failed: {e}")

    def connect_redis(self):
        """Establish Redis connection"""
        try:
            self.redis_client = redis.from_url(REDIS_URL)
            self.redis_client.ping()
            logger.info("Redis connection established")
        except Exception as e:
            logger.error(f"Redis connection failed: {e}")
            self.redis_client = None

    def cleanup_expired_sessions(self):
        """Remove expired user sessions from database"""
        if not self.db_engine:
            return

        try:
            with self.db_engine.connect() as conn:
                # Delete sessions older than 30 days
                cutoff_date = datetime.utcnow() - timedelta(days=30)
                result = conn.execute(text("""
                    DELETE FROM user_sessions
                    WHERE created_at < :cutoff_date
                """), {"cutoff_date": cutoff_date})

                deleted_count = result.rowcount
                conn.commit()

                logger.info(f"Cleaned up {deleted_count} expired user sessions")

        except Exception as e:
            logger.error(f"Session cleanup failed: {e}")

    def cleanup_old_stories(self):
        """Archive or delete very old stories (keep last 1000 per user)"""
        if not self.db_engine:
            return

        try:
            with self.db_engine.connect() as conn:
                # Keep only the most recent 1000 stories per user
                result = conn.execute(text("""
                    DELETE FROM stories
                    WHERE id IN (
                        SELECT id FROM (
                            SELECT id,
                                   ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY created_at DESC) as rn
                            FROM stories
                        ) ranked
                        WHERE rn > 1000
                    )
                """))

                deleted_count = result.rowcount
                conn.commit()

                logger.info(f"Cleaned up {deleted_count} old stories (kept 1000 most recent per user)")

        except Exception as e:
            logger.error(f"Story cleanup failed: {e}")

    def optimize_database(self):
        """Run database optimization queries"""
        if not self.db_engine:
            return

        try:
            with self.db_engine.connect() as conn:
                # Analyze tables for query optimization
                conn.execute(text("ANALYZE"))
                logger.info("Database analyzed for optimization")

                # Vacuum tables (PostgreSQL specific)
                if "postgresql" in DATABASE_URL:
                    conn.execute(text("VACUUM ANALYZE"))
                    logger.info("Database vacuum completed")

        except Exception as e:
            logger.error(f"Database optimization failed: {e}")

    def cleanup_cache(self):
        """Clean up expired cache entries"""
        if not self.redis_client:
            return

        try:
            current_time = time.time()

            # Clean up expired session caches
            session_keys = self.redis_client.keys("session:*")
            expired_sessions = 0

            for key in session_keys:
                ttl = self.redis_client.ttl(key)
                if ttl <= 0:  # Expired
                    self.redis_client.delete(key)
                    expired_sessions += 1

            # Clean up old API response caches (older than 24 hours)
            api_keys = self.redis_client.keys("api:*")
            expired_api_cache = 0

            for key in api_keys:
                # Check if key is older than 24 hours by examining access time
                # This is a simplified approach - in production you'd use Redis streams or timestamps
                if self.redis_client.object("idletime", key) > 86400:  # 24 hours in seconds
                    self.redis_client.delete(key)
                    expired_api_cache += 1

            logger.info(f"Cache cleanup: {expired_sessions} expired sessions, {expired_api_cache} old API caches")

        except Exception as e:
            logger.error(f"Cache cleanup failed: {e}")

    def rotate_logs(self):
        """Rotate and compress old log files"""
        try:
            log_dir = Path("/var/log/story-weaver")
            log_dir.mkdir(parents=True, exist_ok=True)

            # Rotate main application logs
            self._rotate_file(log_dir / "story-weaver.log")
            self._rotate_file(log_dir / "maintenance.log")

            # Clean up old rotated logs (keep last 30 days)
            cutoff_date = datetime.utcnow() - timedelta(days=LOG_RETENTION_DAYS)

            for log_file in log_dir.glob("*.log.*"):
                try:
                    # Extract date from filename (assuming format: filename.log.YYYYMMDD.gz)
                    date_str = log_file.stem.split('.')[-1]
                    if len(date_str) == 8:  # YYYYMMDD format
                        file_date = datetime.strptime(date_str, "%Y%m%d")
                        if file_date < cutoff_date:
                            log_file.unlink()
                            logger.info(f"Removed old log file: {log_file}")
                except (ValueError, OSError):
                    continue

        except Exception as e:
            logger.error(f"Log rotation failed: {e}")

    def _rotate_file(self, log_file: Path):
        """Rotate a single log file"""
        if not log_file.exists():
            return

        # Create rotated filename with timestamp
        timestamp = datetime.utcnow().strftime("%Y%m%d")
        rotated_file = log_file.with_suffix(f".log.{timestamp}.gz")

        try:
            import gzip
            import shutil

            # Compress the current log file
            with log_file.open('rb') as f_in:
                with gzip.open(rotated_file, 'wb') as f_out:
                    shutil.copyfileobj(f_in, f_out)

            # Truncate the original log file
            log_file.write_text("")

            logger.info(f"Rotated log file: {log_file} -> {rotated_file}")

        except Exception as e:
            logger.error(f"Failed to rotate {log_file}: {e}")

    def performance_optimization(self):
        """Run performance optimization tasks"""
        try:
            # Rebuild database indexes (if needed)
            if self.db_engine:
                with self.db_engine.connect() as conn:
                    # Reindex tables (PostgreSQL specific)
                    if "postgresql" in DATABASE_URL:
                        conn.execute(text("REINDEX DATABASE story_weaver"))
                        logger.info("Database reindexed")

            # Optimize Redis memory
            if self.redis_client:
                # Run Redis BGSAVE for persistence optimization
                try:
                    self.redis_client.bgsave()
                    logger.info("Redis background save initiated")
                except Exception as e:
                    logger.warning(f"Redis BGSAVE failed: {e}")

        except Exception as e:
            logger.error(f"Performance optimization failed: {e}")

    def run_maintenance(self):
        """Run all maintenance tasks"""
        logger.info("Starting automated maintenance")

        # Connect to services
        self.connect_database()
        self.connect_redis()

        current_time = time.time()

        # Run cache cleanup (every hour)
        if current_time - self.last_cache_cleanup > CACHE_CLEANUP_INTERVAL:
            logger.info("Running cache cleanup")
            self.cleanup_cache()
            self.last_cache_cleanup = current_time

        # Run database maintenance (daily)
        if current_time - self.last_db_maintenance > DB_MAINTENANCE_INTERVAL:
            logger.info("Running database maintenance")
            self.cleanup_expired_sessions()
            self.cleanup_old_stories()
            self.optimize_database()
            self.last_db_maintenance = current_time

        # Always run these tasks
        self.rotate_logs()
        self.performance_optimization()

        logger.info("Automated maintenance completed")

def main():
    """Main maintenance execution"""
    try:
        manager = MaintenanceManager()
        manager.run_maintenance()
        return 0
    except Exception as e:
        logger.error(f"Maintenance failed: {e}")
        return 1

if __name__ == "__main__":
    sys.exit(main())