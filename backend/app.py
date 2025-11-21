        return {
            "status": "ok",
            "model": GEMINI_MODEL,
            "has_api_key": bool(api_key),
            "database": db_status,
            "environment": app.config.get("ENV", "unknown"),
            "version": "2"
        }, 200

    @app.route("/debug/config", methods=["GET"])
    def debug_config():
        import os
        return {
            'model_from_config': GEMINI_MODEL,
            'model_from_env': os.getenv('GEMINI_MODEL'),
            'all_env_keys': sorted(list(os.environ.keys()))
        }
