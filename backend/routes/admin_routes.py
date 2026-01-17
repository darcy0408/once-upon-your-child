from flask import Blueprint, jsonify

from sqlalchemy import text

from ..database import db
from ..middleware.auth import require_auth, require_admin


def create_admin_blueprint(logger):
    admin_bp = Blueprint("admin", __name__)

    @admin_bp.route("/admin/run-db-optimization", methods=["POST"])
    @require_auth
    @require_admin
    def run_db_optimization():
        """Run database optimization indexes (one-time setup)"""
        try:
            sql_statements = [
                "CREATE INDEX IF NOT EXISTS idx_stories_created_at ON stories(created_at DESC)",
                "CREATE INDEX IF NOT EXISTS idx_stories_user_id ON stories(user_id)",
                "CREATE INDEX IF NOT EXISTS idx_stories_theme ON stories(theme)",
                "CREATE INDEX IF NOT EXISTS idx_stories_user_created ON stories(user_id, created_at DESC)",
                "CREATE INDEX IF NOT EXISTS idx_stories_user_theme ON stories(user_id, theme)",
                "CREATE INDEX IF NOT EXISTS idx_users_created_at ON users(created_at)",
                "CREATE INDEX IF NOT EXISTS idx_users_subscription_tier ON users(subscription_tier)",
                "CREATE INDEX IF NOT EXISTS idx_users_tier_created ON users(subscription_tier, created_at)",
                "CREATE INDEX IF NOT EXISTS idx_stories_user_theme ON stories(user_id, theme)",
            ]

            created_indexes = []
            with db.engine.connect() as conn:
                for sql in sql_statements:
                    try:
                        conn.execute(text(sql))
                        conn.commit()
                        index_name = sql.split("idx_")[1].split(" ")[0] if "idx_" in sql else "unknown"
                        created_indexes.append(f"idx_{index_name}")
                        logger.info(f"✓ Created index: idx_{index_name}")
                    except Exception as e:
                        # Index might already exist - that's ok
                        logger.warning(f"Index creation warning: {str(e)}")

            return (
                jsonify(
                    {
                        "status": "success",
                        "message": "Database optimization complete",
                        "indexes_processed": len(sql_statements),
                        "indexes": created_indexes,
                    }
                ),
                200,
            )

        except Exception as e:
            logger.exception("Failed to run database optimization")
            return jsonify({"error": "Database optimization failed. Check server logs."}), 500

    @admin_bp.route("/admin/add-missing-columns", methods=["POST"])
    @require_auth
    @require_admin
    def add_missing_columns():
        """Add missing columns to database (migration fix)"""
        try:
            engine_name = db.engine.name
            if engine_name == "postgresql":
                sql_statements = [
                    """
                    DO $$
                    BEGIN
                        IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                       WHERE table_name='user' AND column_name='stories_created_count') THEN
                            ALTER TABLE "user" ADD COLUMN stories_created_count INTEGER DEFAULT 0 NOT NULL;
                        END IF;
                    END $$;
                    """,
                    """
                    DO $$
                    BEGIN
                        IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                       WHERE table_name='user' AND column_name='gemini_api_key_encrypted') THEN
                            ALTER TABLE "user" ADD COLUMN gemini_api_key_encrypted TEXT;
                        END IF;
                    END $$;
                    """,
                    """
                    DO $$
                    BEGIN
                        IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                       WHERE table_name='user' AND column_name='has_byok') THEN
                            ALTER TABLE "user" ADD COLUMN has_byok BOOLEAN DEFAULT FALSE NOT NULL;
                        END IF;
                    END $$;
                    """,
                    """
                    DO $$
                    BEGIN
                        IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                       WHERE table_name='user' AND column_name='stories_generated_this_month') THEN
                            ALTER TABLE "user" ADD COLUMN stories_generated_this_month INTEGER DEFAULT 0 NOT NULL;
                        END IF;
                    END $$;
                    """,
                    """
                    DO $$
                    BEGIN
                        IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                       WHERE table_name='user' AND column_name='illustrations_generated_this_month') THEN
                            ALTER TABLE "user" ADD COLUMN illustrations_generated_this_month INTEGER DEFAULT 0 NOT NULL;
                        END IF;
                    END $$;
                    """,
                    """
                    DO $$
                    BEGIN
                        IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                                       WHERE table_name='user' AND column_name='usage_reset_date') THEN
                            ALTER TABLE "user" ADD COLUMN usage_reset_date TIMESTAMP;
                        END IF;
                    END $$;
                    """,
                ]
            else:
                sql_statements = [
                    "ALTER TABLE user ADD COLUMN stories_created_count INTEGER DEFAULT 0 NOT NULL",
                    "ALTER TABLE user ADD COLUMN gemini_api_key_encrypted TEXT",
                    "ALTER TABLE user ADD COLUMN has_byok BOOLEAN DEFAULT 0 NOT NULL",
                    "ALTER TABLE user ADD COLUMN stories_generated_this_month INTEGER DEFAULT 0 NOT NULL",
                    "ALTER TABLE user ADD COLUMN illustrations_generated_this_month INTEGER DEFAULT 0 NOT NULL",
                    "ALTER TABLE user ADD COLUMN usage_reset_date TIMESTAMP",
                ]

            applied_migrations = []
            with db.engine.connect() as conn:
                for sql in sql_statements:
                    try:
                        conn.execute(text(sql))
                        conn.commit()
                        applied_migrations.append(sql.split("ADD COLUMN")[1].strip().split(" ")[0])
                        logger.info("Applied migration: %s", sql)
                    except Exception as e:
                        logger.warning(f"Migration warning: {str(e)}")

            return (
                jsonify(
                    {
                        "status": "success",
                        "message": "Database migrations complete",
                        "migrations_applied": applied_migrations,
                    }
                ),
                200,
            )

        except Exception as e:
            logger.exception("Failed to run database migrations")
            return jsonify({"error": "Database migration failed. Check server logs."}), 500

    return admin_bp
