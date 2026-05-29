"""
Avatar Gallery Routes - Serve pre-made character avatars
"""

import logging
import os

from flask import Blueprint, jsonify

from ..middleware.auth import require_auth

logger = logging.getLogger(__name__)

# Create blueprint
avatar_gallery_bp = Blueprint("avatar_gallery", __name__)

# Path to avatar images
AVATARS_DIR = os.path.join(
    os.path.dirname(os.path.dirname(__file__)), "static", "avatars"
)


@avatar_gallery_bp.route("/list-avatars", methods=["GET"])
@require_auth
def list_avatars():
    """
    Get list of all available pre-made avatars.

    Returns:
        {
            "status": "success",
            "avatars": [
                {"id": "1", "url": "/static/avatars/1.png"},
                {"id": "1.1", "url": "/static/avatars/1.1.png"},
                ...
            ],
            "count": 55
        }
    """
    try:
        if not os.path.exists(AVATARS_DIR):
            logger.error(f"Avatars directory not found: {AVATARS_DIR}")
            return (
                jsonify({"status": "error", "message": "Avatar gallery not available"}),
                500,
            )

        # List all PNG files in avatars directory
        avatar_files = []
        for filename in os.listdir(AVATARS_DIR):
            if filename.endswith(".png"):
                # Extract ID from filename (e.g., "1.png" -> "1", "1.1.png" -> "1.1")
                avatar_id = filename.replace(".png", "")
                avatar_files.append(
                    {
                        "id": avatar_id,
                        "url": f"/static/avatars/{filename}",
                        "filename": filename,
                    }
                )

        # Sort by ID (numeric sort where possible)
        def sort_key(avatar):
            try:
                # Try to convert to float for numeric sort
                parts = avatar["id"].split(".")
                return (int(parts[0]), int(parts[1]) if len(parts) > 1 else 0)
            except (ValueError, IndexError):
                return (999, avatar["id"])

        avatar_files.sort(key=sort_key)

        logger.info(f"Found {len(avatar_files)} avatars in gallery")

        return (
            jsonify(
                {
                    "status": "success",
                    "avatars": avatar_files,
                    "count": len(avatar_files),
                }
            ),
            200,
        )

    except Exception as e:
        logger.exception(f"Error listing avatars: {e}")
        return (
            jsonify({"status": "error", "message": "Failed to load avatar gallery"}),
            500,
        )


@avatar_gallery_bp.route("/select-avatar/<avatar_id>", methods=["POST"])
@require_auth
def select_avatar(avatar_id):
    """
    'Select' a pre-made avatar by ID.

    Returns the same format as AI generation for compatibility.

    Args:
        avatar_id: ID of avatar to select (e.g., "1", "1.1", "15")

    Returns:
        {
            "status": "success",
            "avatar": {
                "id": "avatar_1",
                "image_url": "/static/avatars/1.png",
                "source": "gallery",
                "gallery_id": "1"
            }
        }
    """
    try:
        # Construct filename
        filename = f"{avatar_id}.png"
        filepath = os.path.join(AVATARS_DIR, filename)

        if not os.path.exists(filepath):
            return (
                jsonify(
                    {"status": "error", "message": f"Avatar {avatar_id} not found"}
                ),
                404,
            )

        # Return avatar data in compatible format
        avatar_data = {
            "id": f"gallery_{avatar_id}",
            "image_url": f"/static/avatars/{filename}",
            "source": "gallery",
            "gallery_id": avatar_id,
            "style": "pixar",  # All our pre-made avatars are Pixar style
        }

        logger.info(f"Avatar {avatar_id} selected from gallery")

        return jsonify({"status": "success", "avatar": avatar_data}), 200

    except Exception as e:
        logger.exception(f"Error selecting avatar {avatar_id}: {e}")
        return jsonify({"status": "error", "message": "Failed to select avatar"}), 500
