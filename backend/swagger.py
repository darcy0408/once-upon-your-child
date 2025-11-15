from apispec import APISpec
from apispec.ext.marshmallow import MarshmallowPlugin
from apispec_webframeworks.flask import FlaskPlugin

# Assuming your Flask app is created in app.py
from backend.app import create_app
from backend.routes.auth_routes import auth_bp
from backend.routes.character_routes import character_bp
from backend.routes.progression_routes import progression_bp
from backend.routes.story_routes import story_bp

app = create_app('development')
app.register_blueprint(auth_bp, url_prefix='/auth')
app.register_blueprint(character_bp, url_prefix='/character')
app.register_blueprint(progression_bp, url_prefix='/progression')
app.register_blueprint(story_bp, url_prefix='/story')


spec = APISpec(
    title="Story Weaver App API",
    version="1.0.0",
    openapi_version="3.0.2",
    plugins=[FlaskPlugin(), MarshmallowPlugin()],
)

# You can define schemas here if you use Marshmallow for serialization
# For now, we will manually document the endpoints.

with app.test_request_context():
    spec.path(view=app.view_functions['auth.register'])
    spec.path(view=app.view_functions['auth.login'])
    spec.path(view=app.view_functions['auth.setup_test_account'])
    spec.path(view=app.view_functions['character.create_character'])
    spec.path(view=app.view_functions['character.update_character'])
    spec.path(view=app.view_functions['character.delete_character'])
    spec.path(view=app.view_functions['character.get_characters'])
    spec.path(view=app.view_functions['character.get_character'])
    spec.path(view=app.view_functions['progression.sync_progression'])
    spec.path(view=app.view_functions['progression.get_progression'])
    spec.path(view=app.view_functions['story.get_story_themes'])
    spec.path(view=app.view_functions['story.generate_story_endpoint'])
    spec.path(view=app.view_functions['story.generate_multi_character_story'])
    spec.path(view=app.view_functions['story.generate_interactive_story'])
    spec.path(view=app.view_functions['story.continue_interactive_story'])

import json
with open('docs/swagger.json', 'w') as f:
    json.dump(spec.to_dict(), f, indent=2)