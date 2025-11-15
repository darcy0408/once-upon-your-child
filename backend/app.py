from flask import Flask
from flask_cors import CORS
from .database import db
from .config import config_by_name
import os
from datetime import datetime, timezone
from flask import jsonify, send_from_directory
from flask_swagger_ui import get_swaggerui_blueprint

def create_app(config_name):
    """
    Creates and configures a Flask application.
    """
    print(f"Creating app with config: {config_name}")
    app = Flask(__name__, instance_relative_config=True, static_folder='static')
    app.config.from_object(config_by_name[config_name])

    db.init_app(app)

    # CORS configuration
    CORS(app, resources={
        r"/*": {
            "origins": app.config.get("ALLOWED_ORIGINS", "*"),
            "methods": ["GET", "POST", "PUT", "DELETE", "OPTIONS"],
            "allow_headers": ["Content-Type", "Authorization"],
        }
    })

    @app.after_request
    def add_cors_headers(response):
        response.headers['Access-Control-Allow-Methods'] = 'GET, POST, PUT, DELETE, OPTIONS'
        response.headers['Access-Control-Allow-Headers'] = 'Content-Type, Authorization'
        return response

    # Logging setup
    if not app.debug:
        if not os.path.exists('logs'):
            os.mkdir('logs')
        # ... (logging configuration)

    # Swagger UI configuration
    SWAGGER_URL = '/api/docs'  # URL for exposing Swagger UI (without trailing '/')
    API_URL = '/static/swagger.json'  # Our API url

    # Call factory function to create our blueprint
    swaggerui_blueprint = get_swaggerui_blueprint(
        SWAGGER_URL,
        API_URL,
        config={
            'app_name': "Story Weaver App API"
        }
    )

    app.register_blueprint(swaggerui_blueprint)

    # Serve swagger.json
    @app.route('/static/<path:path>')
    def send_static(path):
        return send_from_directory('static', path)

    # Health check endpoint
    @app.route('/health', methods=['GET'])
    def health():
        health_status = {
            'status': 'ok',
            'timestamp': datetime.now(timezone.utc).isoformat(),
            'version': '1.0.0',
        }

        # Check database
        try:
            from backend.models.user import User
            User.query.first() # Simple query to check database connection
            health_status['database'] = 'ok'
        except Exception as e:
            health_status['database'] = 'error'
            health_status['database_error'] = str(e)
            health_status['status'] = 'degraded'

        # Check Gemini API
        health_status['has_api_key'] = bool(os.getenv('GEMINI_API_KEY'))

        return jsonify(health_status), 200 if health_status['status'] == 'ok' else 503

    from .routes.auth_routes import auth_bp
    from .routes.character_routes import character_bp
    from .routes.progression_routes import progression_bp
    from .routes.story_routes import story_bp

    app.register_blueprint(auth_bp, url_prefix='/auth')
    app.register_blueprint(character_bp, url_prefix='/character')
    app.register_blueprint(progression_bp, url_prefix='/progression')
    app.register_blueprint(story_bp, url_prefix='/story')

    return app
