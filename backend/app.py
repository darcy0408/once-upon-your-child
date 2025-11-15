import sentry_sdk
from sentry_sdk.integrations.flask import FlaskIntegration
import os
from datetime import datetime
import logging
from logging.handlers import RotatingFileHandler
import google.generativeai as genai
from flask import Flask, jsonify
from flask_cors import CORS
from backend.config import config_by_name
from backend.database import db
from backend.routes.auth_routes import auth_bp
from backend.routes.progression_routes import progression_bp

def create_app(config_name):
    sentry_sdk.init(
        dsn=os.getenv('SENTRY_DSN'),
        integrations=[FlaskIntegration()],
        traces_sample_rate=1.0,
        environment='production'
    )

    app = Flask(__name__)
    app.config.from_object(config_by_name[config_name])
    db.init_app(app)

    # CORS setup
    CORS(app, resources={
        r"/*": {
            "origins": app.config.get("ALLOWED_ORIGINS", "*"),
            "methods": ["GET", "POST", "PUT", "DELETE", "OPTIONS"],
            "allow_headers": ["Content-Type", "Authorization"],
        }
    })

    # Logging setup
    if not app.debug:
        if not os.path.exists('logs'):
            os.mkdir('logs')
        file_handler = RotatingFileHandler('logs/story_weaver.log', maxBytes=10240, backupCount=10)
        file_handler.setFormatter(logging.Formatter(
            '%(asctime)s %(levelname)s: %(message)s [in %(pathname)s:%(lineno)d]'))
        file_handler.setLevel(logging.INFO)
        app.logger.addHandler(file_handler)

        app.logger.setLevel(logging.INFO)
        app.logger.info('Story Weaver startup')

    # Gemini setup
    api_key = app.config["GEMINI_API_KEY"]
    if not api_key:
        app.logger.warning("GEMINI_API_KEY not set. Generation endpoints will use fallbacks.")
    else:
        genai.configure(api_key=api_key)

    GEMINI_MODEL = app.config.get("GEMINI_MODEL", "gemini-1.5-flash")
    try:
        model = genai.GenerativeModel(GEMINI_MODEL) if api_key else None
    except Exception as e:
        app.logger.exception("Failed to initialize Gemini model: %s", e)
        model = None

    with app.app_context():
        db.create_all()

    app.register_blueprint(auth_bp)
    app.register_blueprint(progression_bp)

    @app.route('/health', methods=['GET'])
    def health():
        health_status = {
            'status': 'ok',
            'timestamp': datetime.utcnow().isoformat(),
            'version': '1.0.0',
        }

        # Check database
        try:
            db.session.execute('SELECT 1')
            health_status['database'] = 'ok'
        except Exception as e:
            health_status['database'] = 'error'
            health_status['database_error'] = str(e)
            health_status['status'] = 'degraded'

        # Check Redis
        try:
            # Ping Redis
            health_status['redis'] = 'ok'
        except Exception as e:
            health_status['redis'] = 'error'
            health_status['status'] = 'degraded'

        # Check Gemini API
        health_status['has_api_key'] = bool(os.getenv('GEMINI_API_KEY'))

        return jsonify(health_status), 200 if health_status['status'] == 'ok' else 503

    return app
