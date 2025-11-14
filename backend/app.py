import logging
import google.generativeai as genai
from flask import Flask
from flask_cors import CORS
from config import config_by_name
from models import db

def create_app(config_name):
    app = Flask(__name__)
    app.config.from_object(config_by_name[config_name])
    db.init_app(app)
    
    # CORS setup
    CORS(app, resources={
        r"/*": {
            "origins": app.config["ALLOWED_ORIGINS"],
            "methods": ["GET", "POST", "PUT", "DELETE", "OPTIONS"],
            "allow_headers": ["Content-Type", "Authorization"],
        }
    })

    # Logging setup
    logging.basicConfig(level=logging.INFO)
    logger = logging.getLogger("story_engine")

    # Gemini setup
    api_key = app.config["GEMINI_API_KEY"]
    if not api_key:
        logger.warning("GEMINI_API_KEY not set. Generation endpoints will use fallbacks.")
    else:
        genai.configure(api_key=api_key)

    GEMINI_MODEL = app.config["GEMINI_MODEL"]
    try:
        model = genai.GenerativeModel(GEMINI_MODEL) if api_key else None
    except Exception as e:
        logger.exception("Failed to initialize Gemini model: %s", e)
        model = None

    with app.app_context():
        db.create_all()

    return app