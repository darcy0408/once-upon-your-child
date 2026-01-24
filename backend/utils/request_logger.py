# backend/utils/request_logger.py
"""Request logging middleware for tracking payload size, mode flags, and latency."""

import time
from datetime import datetime, timezone
from flask import g, request


def init_request_logging(app, logger):
    """Initialize request logging hooks on the Flask app."""

    @app.before_request
    def _start_timer():
        g.request_start = time.time()

    @app.after_request
    def _log_request_details(response):
        try:
            latency_ms = (time.time() - getattr(g, "request_start", time.time())) * 1000.0
            size = request.content_length or 0
            path = request.path
            method = request.method

            # Best-effort parse mode flags from JSON body
            mode_flags = {}
            if request.is_json:
                body = request.get_json(silent=True) or {}
                # Extract known mode flags
                mode_flags = {
                    k: v
                    for k, v in body.items()
                    if k
                    in (
                        "rhyme_time_mode",
                        "learning_to_read_mode",
                        "include_illustrations",
                        "pick_a_path",
                    )
                    and isinstance(v, bool)
                }

            logger.info(
                "req %s %s status=%s latency_ms=%.1f bytes=%s modes=%s ts=%s",
                method,
                path,
                response.status_code,
                latency_ms,
                size,
                mode_flags or "{}",
                datetime.now(timezone.utc).isoformat(),
            )
        except Exception:
            # Don't let logging failures break requests
            pass
        return response
