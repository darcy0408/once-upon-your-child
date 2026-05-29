import os
from datetime import datetime, timezone

from flask import Blueprint, jsonify

from ..database import db
from ..middleware.auth import require_auth, require_admin


def create_health_blueprint(
    logger, api_key: str, app_version: str, gemini_model: str, limiter=None
):
    health_bp = Blueprint("health", __name__)

    @health_bp.route("/health", methods=["GET"])
    def health_check():
        """Public liveness probe — also Railway's deploy healthcheck.

        Intentionally minimal in its response: returns only status + version.
        Detailed diagnostics (DB/Gemini/Stripe config, environment, raw
        errors) are not exposed to unauthenticated callers — see
        /health/detailed.

        Includes a lightweight DB connectivity probe (SELECT 1) so a deploy
        with a broken database connection fails the healthcheck and never
        goes live. Raw exception detail is logged server-side only.
        """
        try:
            from sqlalchemy import text

            db.session.execute(text("SELECT 1"))
            return jsonify({"status": "ok", "version": app_version}), 200
        except Exception:
            logger.exception("Health check: database probe failed")
            return jsonify({"status": "degraded", "version": app_version}), 503

    @health_bp.route("/version", methods=["GET"])
    def version():
        return jsonify({"version": app_version, "gemini_model": gemini_model}), 200

    @health_bp.route("/health/detailed", methods=["GET"])
    @require_auth
    @require_admin
    def detailed_health():
        """Authenticated, admin-only detailed health check.

        Returns integration/diagnostic detail. Raw exception strings are
        logged server-side but never returned to the client.
        """
        health_status = {
            "status": "healthy",
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "checks": {},
        }

        # Database check
        try:
            from sqlalchemy import text

            db.session.execute(text("SELECT 1"))
            health_status["checks"]["database"] = {"status": "healthy"}
        except Exception:
            logger.exception("Health check: database probe failed")
            health_status["status"] = "unhealthy"
            health_status["checks"]["database"] = {"status": "unhealthy"}

        # Gemini API check — live probe
        try:
            from google import genai as _genai

            _client = _genai.Client(api_key=api_key)
            _client.models.get(model=gemini_model)
            health_status["checks"]["gemini_api"] = {
                "status": "healthy",
                "configured": True,
                "live": True,
            }
        except Exception:
            logger.exception("Health check: Gemini probe failed")
            health_status["status"] = "degraded"
            health_status["checks"]["gemini_api"] = {
                "status": "unhealthy",
                "configured": bool(api_key),
                "live": False,
            }

        # Memory check
        try:
            import psutil

            memory = psutil.virtual_memory()
            health_status["checks"]["memory"] = {
                "status": "healthy" if memory.percent < 90 else "warning",
                "percent_used": memory.percent,
            }
        except ImportError:
            health_status["checks"]["memory"] = {
                "status": "unknown",
                "note": "psutil not installed",
            }

        status_code = 200 if health_status["status"] == "healthy" else 503
        return jsonify(health_status), status_code

    @health_bp.route("/health/database", methods=["GET"])
    @require_auth
    @require_admin
    def database_health():
        """Authenticated, admin-only database connection-pool health check."""
        try:
            pool = db.engine.pool
            from sqlalchemy.pool import StaticPool

            if isinstance(pool, StaticPool):
                return jsonify(
                    {
                        "status": "ok",
                        "pool_type": "StaticPool",
                        "note": "StaticPool has no size metrics",
                    }
                )

            return jsonify(
                {
                    "status": "ok",
                    "pool_size": pool.size(),
                    "checked_in": pool.checkedin(),
                    "checked_out": pool.checkedout(),
                    "overflow": pool.overflow(),
                }
            )
        except Exception:
            logger.exception("Health check: database pool probe failed")
            return (
                jsonify({"status": "error", "error": "Database health check failed"}),
                500,
            )

    if limiter is not None:
        limiter.exempt(health_check)
        limiter.exempt(version)
        limiter.exempt(detailed_health)
        limiter.exempt(database_health)

    return health_bp
