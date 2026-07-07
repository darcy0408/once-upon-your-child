"""Gift-subscription redemption endpoint.

`POST /api/gift/redeem` is the recipient-facing half of the gift-subscriptions
flow: a purchaser buys a code via a Stripe Payment Link
(`routes/webhook_handler.py` mints it on `checkout.session.completed` and
emails it), and the recipient redeems it here. See models/gift_code.py for
the storage/expiry design.
"""

import logging
from datetime import datetime, timedelta, timezone

from flask import Blueprint, jsonify, request
from sqlalchemy.exc import SQLAlchemyError

try:  # Package vs. flat-module import (mirrors the rest of backend/).
    from ..database import db
    from ..middleware.auth import require_auth
    from ..models.gift_code import (
        STATUS_CREATED,
        STATUS_REDEEMED,
        GiftCode,
        hash_code,
        normalize_code,
    )
    from ..services.entitlement_service import apply_entitlement
except ImportError:  # pragma: no cover - flat-module layout
    from database import db
    from middleware.auth import require_auth
    from models.gift_code import (
        STATUS_CREATED,
        STATUS_REDEEMED,
        GiftCode,
        hash_code,
        normalize_code,
    )
    from services.entitlement_service import apply_entitlement

logger = logging.getLogger("gift_routes")


def _not_found_response():
    return (
        jsonify({"error": "That gift code isn't valid", "code": "gift_code_not_found"}),
        404,
    )


def _already_redeemed_response():
    return (
        jsonify(
            {
                "error": "That gift code has already been redeemed",
                "code": "gift_code_redeemed",
            }
        ),
        409,
    )


def create_gift_blueprint(limiter=None):
    """Factory function to create the gift blueprint with rate limiting."""
    gift_routes = Blueprint("gift_routes", __name__)

    @gift_routes.route("/api/gift/redeem", methods=["POST"])
    @require_auth
    @limiter.limit("10 per hour")  # Brute-force protection, mirrors consent-code verify
    def redeem_gift_code():
        """Redeem a gift code for the authenticated user.

        Body: {"code": "XXXX-XXXX-XXXX"} (dashes/case/whitespace tolerant).

        On success: atomically claims the code, then applies the entitlement
        through the shared apply_entitlement() single-writer path (same one
        IAP uses) with period_end = now + duration_days.

        Errors are deliberately generic and do not distinguish "no such code"
        from "revoked code" — both return 404 — so a brute-force attempt can't
        learn which codes are real. Only a genuinely already-redeemed code
        gets its own 409, per the task contract.
        """
        user = request.current_user
        data = request.get_json(silent=True) or {}
        raw_code = data.get("code")

        normalized = normalize_code(raw_code)
        if normalized is None:
            logger.info("Gift redeem: malformed code submitted by user %s", user.id)
            return _not_found_response()

        code_hash = hash_code(normalized)
        gift = db.session.query(GiftCode).filter_by(code_hash=code_hash).first()

        if gift is None:
            logger.info("Gift redeem: unknown code submitted by user %s", user.id)
            return _not_found_response()

        if gift.status == STATUS_REDEEMED:
            logger.info(
                "Gift redeem: already-redeemed code submitted by user %s", user.id
            )
            return _already_redeemed_response()

        if gift.status != STATUS_CREATED:
            # Revoked (or any other non-redeemable state) — don't reveal that
            # the code exists in a special state; behave like "not found".
            logger.info(
                "Gift redeem: non-redeemable code (status=%s) submitted by user %s",
                gift.status,
                user.id,
            )
            return _not_found_response()

        # Atomic claim: a conditional UPDATE guarded on status=='created' is
        # the race guard — if two requests redeem the same code concurrently,
        # exactly one UPDATE matches a row (rowcount==1); the loser sees
        # rowcount==0 and reports "already redeemed" rather than double-
        # granting entitlement.
        now = datetime.now(timezone.utc)
        claimed = (
            db.session.query(GiftCode)
            .filter(GiftCode.id == gift.id, GiftCode.status == STATUS_CREATED)
            .update(
                {
                    "status": STATUS_REDEEMED,
                    "redeemed_by_user_id": user.id,
                    "redeemed_at": now,
                },
                synchronize_session=False,
            )
        )
        if claimed == 0:
            db.session.rollback()
            logger.info("Gift redeem: lost redemption race for user %s", user.id)
            return _already_redeemed_response()

        period_end = now + timedelta(days=gift.duration_days)
        try:
            apply_entitlement(
                user,
                tier=gift.tier,
                status="active",
                period_end=period_end,
                cancel_at_period_end=False,
                source="gift",
                commit=False,
            )
            db.session.commit()
        except SQLAlchemyError:
            db.session.rollback()
            logger.exception(
                "Gift redeem: failed to apply entitlement for user %s", user.id
            )
            return (
                jsonify(
                    {"error": "Could not redeem this code right now. Please try again."}
                ),
                500,
            )

        logger.info(
            "Gift redeem: code redeemed by user %s (tier=%s, duration_days=%s)",
            user.id,
            gift.tier,
            gift.duration_days,
        )

        return (
            jsonify(
                {
                    "success": True,
                    "tier": user.subscription_tier,
                    "subscription_status": user.subscription_status,
                    "current_period_end": (
                        user.current_period_end.isoformat()
                        if user.current_period_end
                        else None
                    ),
                }
            ),
            200,
        )

    return gift_routes
