from apispec import APISpec
from apispec.ext.marshmallow import MarshmallowPlugin
from apispec_webframeworks.flask import FlaskPlugin

# Create the Flask app
from backend.app import create_app

app = create_app("development")


spec = APISpec(
    title="Story Weaver App API",
    version="1.0.0",
    openapi_version="3.0.2",
    plugins=[FlaskPlugin(), MarshmallowPlugin()],
)

# You can define schemas here if you use Marshmallow for serialization
# For now, we will manually document the endpoints.

with app.test_request_context():
    # Health and utility endpoints
    spec.path(view=app.view_functions["health"])
    spec.path(view=app.view_functions["get_story_themes"])
    spec.path(view=app.view_functions["setup_test_account"])
    spec.path(view=app.view_functions["login"])

    # Story generation endpoints
    spec.path(view=app.view_functions["generate_story_endpoint"])

    # Character management endpoints
    spec.path(view=app.view_functions["create_character_endpoint"])
    spec.path(view=app.view_functions["update_character_endpoint"])
    spec.path(view=app.view_functions["delete_character_endpoint"])
    spec.path(view=app.view_functions["get_characters_endpoint"])
    spec.path(view=app.view_functions["get_character_endpoint"])

import json

with open("docs/swagger.json", "w") as f:
    json.dump(spec.to_dict(), f, indent=2)
