"""Transactional email sending via Resend.

Currently used only for the COPPA parental-consent verification round trip.

Design notes:
  - Sends by POSTing to the Resend REST API with the `requests` library
    (already a project dependency) — no extra pip package needed.
  - RESEND_API_KEY and CONSENT_EMAIL_FROM are OPTIONAL config. If RESEND_API_KEY
    is not set the service degrades gracefully: it logs an error and the caller
    receives a falsy result so the endpoint can return a 503-style error rather
    than crashing. Consent must FAIL CLOSED — never mark verified if no email
    could be sent.
  - SECURITY: never log the verification code value or the recipient email at
    INFO level. The API key is never logged.
"""

import logging
import os

import requests

logger = logging.getLogger(__name__)

RESEND_API_URL = "https://api.resend.com/emails"
_REQUEST_TIMEOUT_SECONDS = 15


def _get_resend_api_key():
    """Return the Resend API key, or None if not configured (optional config)."""
    return os.environ.get("RESEND_API_KEY") or None


def _get_consent_email_from():
    """Return the From address for consent emails.

    Defaults to a no-reply address; override with CONSENT_EMAIL_FROM. The
    sending domain must be verified in the Resend dashboard for delivery.
    """
    return (
        os.environ.get("CONSENT_EMAIL_FROM")
        or "Once Upon YOUR Child <no-reply@storyweaver.app>"
    )


def is_email_configured():
    """True when transactional email can be sent (RESEND_API_KEY present)."""
    return _get_resend_api_key() is not None


def _send_email(to_address, subject, html_body, text_body):
    """Low-level send. Returns True on success, False on any failure.

    Never raises — callers depend on a boolean so consent can fail closed.
    """
    api_key = _get_resend_api_key()
    if not api_key:
        logger.error(
            "email_service: RESEND_API_KEY is not configured — cannot send "
            "transactional email. Set RESEND_API_KEY in the environment."
        )
        return False

    payload = {
        "from": _get_consent_email_from(),
        "to": [to_address],
        "subject": subject,
        "html": html_body,
        "text": text_body,
    }

    try:
        resp = requests.post(
            RESEND_API_URL,
            json=payload,
            headers={
                "Authorization": f"Bearer {api_key}",
                "Content-Type": "application/json",
            },
            timeout=_REQUEST_TIMEOUT_SECONDS,
        )
    except requests.RequestException as exc:
        # Do not log the recipient address.
        logger.error("email_service: request to Resend failed: %s", exc)
        return False

    if resp.status_code in (200, 201):
        logger.info("email_service: transactional email accepted by Resend")
        return True

    # Resend returns JSON error details; log status + body but never the
    # recipient. Body may contain a generic error message, not secrets.
    body_snippet = (resp.text or "")[:300]
    logger.error(
        "email_service: Resend rejected send (HTTP %s): %s",
        resp.status_code,
        body_snippet,
    )
    return False


def send_consent_verification_email(parent_email, code, expiry_minutes):
    """Send the COPPA parental-consent verification email.

    Args:
        parent_email: recipient parent/guardian email address.
        code: the plaintext verification code (used only in-memory for the
            email body; never logged, never persisted in plaintext).
        expiry_minutes: how long the code remains valid, for the email copy.

    Returns:
        True if Resend accepted the message, False otherwise (caller must then
        leave consent pending and surface a 503-style error).
    """
    subject = "Verify your consent for your child’s Once Upon YOUR Child account"

    text_body = (
        "Hello,\n\n"
        "Someone created an account on Once Upon YOUR Child (powered by Story "
        "Weaver), a children's storytelling app, and listed this email address "
        "as the parent or guardian.\n\n"
        "Because the child is under 13, U.S. children's privacy law (COPPA) "
        "requires a parent or guardian to give verifiable consent before the "
        "child can use the app.\n\n"
        f"Your verification code is: {code}\n\n"
        f"Enter this code in the app to approve the account. The code expires "
        f"in {expiry_minutes} minutes.\n\n"
        "If you did not expect this email, you can ignore it — no account will "
        "be activated without this code.\n\n"
        "This is a one-time transactional message. We do not send marketing "
        "email to this address.\n"
    )

    html_body = f"""\
<!DOCTYPE html>
<html>
  <body style="font-family: -apple-system, Segoe UI, Roboto, Arial, sans-serif;
               color: #222; line-height: 1.5; max-width: 520px; margin: 0 auto;
               padding: 24px;">
    <h2 style="margin-bottom: 4px;">Verify your child&rsquo;s account</h2>
    <p>Hello,</p>
    <p>
      Someone created an account on <strong>Once Upon YOUR Child</strong>
      (powered by Story Weaver), a children&rsquo;s storytelling app, and listed
      this email address as the parent or guardian.
    </p>
    <p>
      Because the child is under 13, U.S. children&rsquo;s privacy law
      (<strong>COPPA</strong>) requires a parent or guardian to give verifiable
      consent before the child can use the app.
    </p>
    <p style="margin-bottom: 8px;">Your verification code is:</p>
    <p style="font-size: 28px; font-weight: 700; letter-spacing: 4px;
              background: #f2f2f7; padding: 14px 20px; border-radius: 10px;
              text-align: center; margin: 0 0 16px;">{code}</p>
    <p>
      Enter this code in the app to approve the account. The code expires in
      <strong>{expiry_minutes} minutes</strong>.
    </p>
    <p>
      If you did not expect this email, you can ignore it &mdash; no account
      will be activated without this code.
    </p>
    <hr style="border: none; border-top: 1px solid #e0e0e0; margin: 20px 0;">
    <p style="font-size: 12px; color: #888;">
      This is a one-time transactional message. We do not send marketing email
      to this address.
    </p>
  </body>
</html>
"""

    return _send_email(parent_email, subject, html_body, text_body)


def _duration_label(duration_days):
    """Human-friendly copy for a gift duration, e.g. 365 -> '1 year'."""
    if not duration_days or duration_days <= 0:
        return "a while"
    if duration_days >= 365 and duration_days % 365 == 0:
        years = duration_days // 365
        return f"{years} year" + ("s" if years != 1 else "")
    if duration_days >= 30 and duration_days % 30 == 0:
        months = duration_days // 30
        return f"{months} month" + ("s" if months != 1 else "")
    return f"{duration_days} day" + ("s" if duration_days != 1 else "")


def send_gift_code_email(purchaser_email, code, tier, duration_days):
    """Send a purchased gift-subscription redemption code to the purchaser.

    Args:
        purchaser_email: recipient email address — the Stripe Checkout
            customer email for the gift purchase.
        code: the plaintext, dash-formatted redemption code (e.g.
            'ABCD-1234-WXYZ'). Used only in-memory to build the email body;
            never logged, never persisted in plaintext (see
            models/gift_code.py — only a SHA-256 hash is stored).
        tier: the subscription tier the code grants (e.g. 'premium').
        duration_days: how many days of access the code grants, for the copy.

    Returns:
        True if Resend accepted the message, False otherwise. Callers MUST
        persist the GiftCode row BEFORE calling this and must NOT delete/lose
        it on a False return — the purchaser already paid, so the code stays
        valid and redeemable even if the confirmation email didn't go out;
        the failure is logged for a manual resend.
    """
    duration_label = _duration_label(duration_days)
    tier_label = (tier or "premium").strip().title() or "Premium"

    subject = f"Your gift is ready — {duration_label} of Once Upon YOUR Child"

    text_body = (
        "Hello,\n\n"
        f"Thank you for gifting {duration_label} of Once Upon YOUR Child "
        f"({tier_label}), powered by Story Weaver!\n\n"
        f"Your gift code is: {code}\n\n"
        "Share this code with the family you're gifting it to. They can "
        'redeem it in the app under Subscription -> "Have a gift code?" to '
        "unlock their access immediately.\n\n"
        "This code can only be redeemed once, so keep it somewhere safe "
        "until you're ready to share it.\n\n"
        "Thank you for supporting a family's storytelling time.\n\n"
        "This is a one-time transactional message. We do not send marketing "
        "email to this address.\n"
    )

    html_body = f"""\
<!DOCTYPE html>
<html>
  <body style="font-family: -apple-system, Segoe UI, Roboto, Arial, sans-serif;
               color: #222; line-height: 1.5; max-width: 520px; margin: 0 auto;
               padding: 24px;">
    <h2 style="margin-bottom: 4px;">Your gift is ready!</h2>
    <p>Hello,</p>
    <p>
      Thank you for gifting <strong>{duration_label}</strong> of
      <strong>Once Upon YOUR Child</strong> ({tier_label}), powered by Story
      Weaver!
    </p>
    <p style="margin-bottom: 8px;">Your gift code is:</p>
    <p style="font-size: 26px; font-weight: 700; letter-spacing: 3px;
              background: #f2f2f7; padding: 14px 20px; border-radius: 10px;
              text-align: center; margin: 0 0 16px;">{code}</p>
    <p>
      Share this code with the family you're gifting it to. They can redeem
      it in the app under <strong>Subscription &rarr; "Have a gift
      code?"</strong> to unlock their access immediately.
    </p>
    <p>
      This code can only be redeemed once, so keep it somewhere safe until
      you're ready to share it.
    </p>
    <p>Thank you for supporting a family's storytelling time.</p>
    <hr style="border: none; border-top: 1px solid #e0e0e0; margin: 20px 0;">
    <p style="font-size: 12px; color: #888;">
      This is a one-time transactional message. We do not send marketing email
      to this address.
    </p>
  </body>
</html>
"""

    return _send_email(purchaser_email, subject, html_body, text_body)
