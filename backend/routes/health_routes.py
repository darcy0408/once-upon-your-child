import os
from datetime import datetime, timezone

from flask import Blueprint, jsonify

from ..database import db


def create_health_blueprint(logger, api_key: str, app_version: str, gemini_model: str):
    health_bp = Blueprint("health", __name__)

    @health_bp.route("/health", methods=["GET"])
    def health_check():
        health_status = {
            "status": "ok",
            "timestamp": datetime.now().isoformat(),
            "version": app_version,
        }

        # Database check
        try:
            from sqlalchemy import text

            db.session.execute(text("SELECT 1"))
            health_status["database"] = "ok"
        except Exception as e:
            health_status["database"] = "error"
            health_status["database_error"] = str(e)
            health_status["status"] = "degraded"

        # Gemini API check
        health_status["has_api_key"] = bool(api_key)
        health_status["model"] = os.getenv("GEMINI_MODEL", "not-set")

        # Stripe check
        health_status["stripe_configured"] = bool(os.getenv("STRIPE_API_KEY"))
        health_status["stripe_premium_price"] = bool(os.getenv("STRIPE_PRICE_ID_PREMIUM"))
        health_status["stripe_family_price"] = bool(os.getenv("STRIPE_PRICE_ID_FAMILY"))

        # Environment
        health_status["environment"] = os.getenv("RAILWAY_ENVIRONMENT", "unknown")

        if health_status["status"] != "ok":
            logger.warning(f"Health degraded: {health_status}")

        return jsonify(health_status), 200

    @health_bp.route("/version", methods=["GET"])
    def version():
        return jsonify({"version": app_version, "gemini_model": gemini_model}), 200

    @health_bp.route("/health/detailed", methods=["GET"])
    def detailed_health():
        health_status = {"status": "healthy", "timestamp": datetime.now(timezone.utc).isoformat(), "checks": {}}

        # Database check
        try:
            from sqlalchemy import text

            db.session.execute(text("SELECT 1"))
            health_status["checks"]["database"] = {"status": "healthy"}
        except Exception as e:
            health_status["status"] = "unhealthy"
            health_status["checks"]["database"] = {"status": "unhealthy", "error": str(e)}

        # Gemini API check
        try:
            health_status["checks"]["gemini_api"] = {"status": "healthy" if api_key else "unhealthy", "configured": bool(api_key)}
        except Exception as e:
            health_status["status"] = "degraded"
            health_status["checks"]["gemini_api"] = {"status": "unhealthy", "error": str(e)}

        # Memory check
        try:
            import psutil

            memory = psutil.virtual_memory()
            health_status["checks"]["memory"] = {
                "status": "healthy" if memory.percent < 90 else "warning",
                "percent_used": memory.percent,
            }
        except ImportError:
            health_status["checks"]["memory"] = {"status": "unknown", "note": "psutil not installed"}

        status_code = 200 if health_status["status"] == "healthy" else 503
        return jsonify(health_status), status_code

    @health_bp.route("/health/database", methods=["GET"])
    def database_health():
        """Detailed database health check"""
        try:
            pool = db.engine.pool
            from sqlalchemy.pool import StaticPool

            if isinstance(pool, StaticPool):
                return jsonify({"status": "ok", "pool_type": "StaticPool", "note": "StaticPool has no size metrics"})

            return jsonify(
                {
                    "status": "ok",
                    "pool_size": pool.size(),
                    "checked_in": pool.checkedin(),
                    "checked_out": pool.checkedout(),
                    "overflow": pool.overflow(),
                }
            )
        except Exception as e:
            return jsonify({"status": "error", "error": str(e)}), 500

    return health_bp
