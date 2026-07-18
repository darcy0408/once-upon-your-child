"""
TTS Routes — tiered narration fallback chain.

Default provider order on /tts/synthesize (cost-optimized — see F-01 in
audit-reports/10-finops):
  1. Gemini Flash TTS (~$0.054/1k chars) — the default paid voice
  2. Edge TTS (free) — final online fallback before on-device TTS

ElevenLabs (~$0.18/1k chars, ~3.3x Gemini) is an OPT-IN premium voice: used
only when the request sets "premium_voice": true, or requests dialogue-
differentiated narration via "character_voice_id" (a multi-voice feature only
ElevenLabs supports). When opted in it serves first, then falls through to
Gemini then Edge if unavailable or over its monthly character budget.
The 'provider' field in the response indicates which tier served the request.

Azure AI Speech is the licensed primary provider (MT-248): when configured it
serves all narration and the providers above are bypassed. ElevenLabs is
additionally HARD-GATED off for users flagged is_under_13 (their terms forbid
processing audio for under-13s) — guaranteeing under-13s never reach it even in
the Azure-unavailable fallback path.

POST /tts/synthesize
  Body: { "text": str, "voice_id": str (optional) }
  Returns: { "audio_base64": str, "format": "mp3", "voice_id": str, "provider": str }
  Returns 503 only if all three providers fail — clients then fall back to
  on-device flutter_tts.

Server-side audio cache: identical (text, voice, speed, provider-chain)
requests are served from the ``tts_audio_cache`` table without touching any
provider — and without consuming the daily TTS quota, so re-reads are free
and start instantly (see backend/services/tts_audio_cache_service.py). The
auth + parental-consent + rate-limit decorators still run on every request,
cache hit or miss.

GET /tts/voices
  Returns: { "voices": [...] }  — curated voice list for the picker UI.
"""

import base64
import logging

from flask import Blueprint, jsonify, request

logger = logging.getLogger(__name__)

# Lazy-initialise so the app still starts without an API key configured
_tts_service = None


def _get_tts_service():
    global _tts_service
    if _tts_service is not None:
        return _tts_service

    try:
        from backend.elevenlabs_tts_service import ElevenLabsTTSService
    except ImportError:
        try:
            from elevenlabs_tts_service import ElevenLabsTTSService
        except ImportError:
            logger.warning("elevenlabs_tts_service module not found")
            return None

    try:
        _tts_service = ElevenLabsTTSService()
        logger.info("ElevenLabs TTS initialised successfully")
        return _tts_service
    except (ImportError, ValueError) as e:
        logger.warning("ElevenLabs TTS unavailable: %s", e)
        return None
    except Exception as e:
        logger.warning("ElevenLabs TTS init error: %s", e)
        return None


def _get_voice_list():
    """Return curated voices even when the service is not initialised."""
    try:
        from backend.elevenlabs_tts_service import CURATED_VOICES, DEFAULT_VOICE_ID
    except ImportError:
        try:
            from elevenlabs_tts_service import CURATED_VOICES, DEFAULT_VOICE_ID
        except ImportError:
            return [], "21m00Tcm4TlvDq8ikWAM"
    return CURATED_VOICES, DEFAULT_VOICE_ID


# Gemini Flash TTS — overflow tier between ElevenLabs and Edge. Costs ~$0.054/1k
# chars vs ElevenLabs' $0.18/1k, used when ElevenLabs is unavailable or over
# budget so paying users keep a high-quality voice instead of dropping to Edge.
_gemini_service = None


def _get_gemini_service():
    """Lazy-init the Gemini Flash TTS service."""
    global _gemini_service
    if _gemini_service is not None:
        return _gemini_service

    try:
        from backend.gemini_tts_service import GeminiTTSService
    except ImportError:
        try:
            from gemini_tts_service import GeminiTTSService
        except ImportError:
            logger.warning("gemini_tts_service module not found")
            return None

    try:
        _gemini_service = GeminiTTSService()
        logger.info("Gemini Flash TTS initialised successfully")
        return _gemini_service
    except (ImportError, ValueError) as e:
        logger.warning("Gemini Flash TTS unavailable: %s", e)
        return None
    except Exception as e:
        logger.warning("Gemini Flash TTS init error: %s", e)
        return None


def _gemini_synthesize(text, voice_id, speed):
    """
    Synthesize narration via Gemini Flash TTS.
    Returns (audio_bytes, word_timestamps) or None if unavailable.
    Word timestamps are always [] — Gemini TTS does not provide alignment.
    """
    service = _get_gemini_service()
    if service is None:
        return None
    try:
        return service.generate_speech_with_timestamps(
            text=text, voice_id=voice_id, speed=speed
        )
    except Exception as e:
        logger.error("Gemini Flash TTS failed: %s", e)
        return None


# Free Edge TTS fallback — used when ElevenLabs is unconfigured or out of budget.
_edge_service = None


def _get_edge_service():
    """Lazy-init the free Microsoft Edge TTS fallback service."""
    global _edge_service
    if _edge_service is not None:
        return _edge_service

    try:
        from backend.edge_tts_service import EdgeTTSService
    except ImportError:
        try:
            from edge_tts_service import EdgeTTSService
        except ImportError:
            logger.warning("edge_tts_service module not found")
            return None

    if not EdgeTTSService.available():
        logger.warning("edge-tts package not installed — no free TTS fallback")
        return None
    _edge_service = EdgeTTSService()
    logger.info("Edge TTS fallback initialised")
    return _edge_service


def _edge_synthesize(text, voice_id, speed):
    """
    Synthesize narration via the free Edge TTS fallback.
    Returns (audio_bytes, word_timestamps) or None if unavailable.
    """
    service = _get_edge_service()
    if service is None:
        return None
    try:
        return service.generate_speech_with_timestamps(
            text=text, voice_id=voice_id, speed=speed
        )
    except Exception as e:
        logger.error("Edge TTS fallback failed: %s", e)
        return None


# Azure AI Speech — the licensed primary narration provider (MT-248). Dormant
# until AZURE_SPEECH_KEY + AZURE_SPEECH_REGION are set; once configured it serves
# first and the prohibited/unlicensed providers (ElevenLabs, Gemini, Edge) are
# bypassed. The SDK is lazy-imported so the app boots without it installed.
_azure_service = None


def _get_azure_service():
    """Lazy-init the Azure AI Speech service (only when SDK + key/region set)."""
    global _azure_service
    if _azure_service is not None:
        return _azure_service

    try:
        from backend.azure_tts_service import AzureTTSService
    except ImportError:
        try:
            from azure_tts_service import AzureTTSService
        except ImportError:
            logger.warning("azure_tts_service module not found")
            return None

    if not AzureTTSService.available():
        return None
    _azure_service = AzureTTSService()
    logger.info("Azure AI Speech initialised")
    return _azure_service


def _azure_synthesize(text, voice_id, speed):
    """
    Synthesize narration via Azure AI Speech.
    Returns (audio_bytes, word_timestamps) or None if unavailable.
    """
    service = _get_azure_service()
    if service is None:
        return None
    try:
        return service.generate_speech_with_timestamps(
            text=text, voice_id=voice_id, speed=speed
        )
    except Exception as e:
        logger.error("Azure AI Speech failed: %s", e)
        return None


def create_tts_blueprint(limiter, require_auth):
    tts_bp = Blueprint("tts", __name__)

    # COPPA: narration text can carry a child's name and is sent to an external
    # TTS vendor, so /tts/synthesize must sit behind the parental-consent gate
    # like the other child-data vendor calls. require_auth is injected; import
    # the consent decorator here with the same backend/bare fallback the rest of
    # the package uses.
    try:
        from backend.middleware.auth import require_parental_consent
    except ImportError:
        from middleware.auth import require_parental_consent

    @tts_bp.route("/tts/voices", methods=["GET"])
    def voices():
        """Return the curated ElevenLabs voice list for the Flutter voice picker."""
        voice_list, default_id = _get_voice_list()
        return jsonify({"voices": voice_list, "default_voice_id": default_id})

    @tts_bp.route("/tts/synthesize", methods=["POST"])
    @require_auth
    @require_parental_consent
    @limiter.limit(
        "500 per hour",
        key_func=lambda: (
            request.current_user.id
            if hasattr(request, "current_user") and request.current_user
            else request.remote_addr
        ),
    )
    def synthesize():
        """
        Generate MP3 narration for a story text.
        Default voice is Gemini Flash TTS; ElevenLabs is an opt-in premium
        voice (premium_voice=true, or character_voice_id for dialogue).
        Returns base64-encoded MP3 audio, or 503 if every provider is
        unavailable so the client falls back to on-device TTS.
        """
        import os

        if os.environ.get("TTS_DISABLED", "").lower() in ("1", "true", "yes"):
            return (
                jsonify(
                    {
                        "error": "TTS service unavailable",
                        "message": "TTS is temporarily disabled.",
                    }
                ),
                503,
            )

        # Parse the request BEFORE any quota work: the server-side audio
        # cache (below) must be servable even when the user's daily synthesis
        # quota is spent — replaying already-synthesized audio costs no
        # provider call, so a re-read is free (mirrors the illustration
        # cache's hit-skips-quota rule).
        data = request.get_json(force=True, silent=True) or {}
        text = (data.get("text") or "").strip()
        if not text:
            return jsonify({"error": "text is required"}), 400
        # The ElevenLabs monthly char budget is checked against the raw
        # (pre-clean) length, matching the pre-cache behavior of this route.
        raw_text_len = len(text)

        # Per-user daily TTS quota helpers (applies to all providers)
        try:
            from backend.utils.ai_quota import (
                check_tts_chars_quota,
                check_tts_quota,
                increment_tts_chars,
                increment_tts_quota,
            )
            from backend.utils.audit import audit_log
        except ImportError:
            from utils.ai_quota import (
                check_tts_chars_quota,
                check_tts_quota,
                increment_tts_chars,
                increment_tts_quota,
            )
            from utils.audit import audit_log

        user_id = (
            request.current_user.id
            if hasattr(request, "current_user") and request.current_user
            else None
        )
        user_tier = getattr(request.current_user, "subscription_tier", "free") or "free"
        # ElevenLabs' terms forbid processing audio for users under 13, and this
        # app serves under-13 children. ElevenLabs is therefore hard-gated off
        # for them server-side (can't be opted back in by the client). When Azure
        # AI Speech is configured it already serves everyone and ElevenLabs is
        # never used; this gate guarantees under-13s never reach ElevenLabs even
        # in the Azure-unavailable fallback (they get Gemini Flash TTS -> Edge).
        # is_under_13 is set during COPPA onboarding.
        is_under_13 = bool(getattr(request.current_user, "is_under_13", False))
        # MT-327: Gemini Flash TTS (the legacy pre-Azure fallback below) is
        # barred for ALL minors, not just under-13s. is_under_13 alone misses
        # 13-17 accounts (attested via the 13-17 gate, which POSTs a resolved
        # declared_age without setting is_under_13). An unknown declared_age
        # is NOT treated as a minor here — mirrors this codebase's existing
        # fail-open-on-unknown-age posture (ENFORCE_RESOLVED_AGE defaults off
        # for the same reason: most accounts predate server-side age-sync).
        _declared_age = getattr(request.current_user, "declared_age", None)
        try:
            is_under_18 = is_under_13 or (
                _declared_age is not None and int(_declared_age) < 18
            )
        except (TypeError, ValueError):
            is_under_18 = is_under_13
        premium_voice = bool(data.get("premium_voice"))
        wants_dialogue = bool((data.get("character_voice_id") or "").strip())

        # Strip markdown/formatting before sending so we don't waste
        # the per-chunk budget on asterisks and pound signs.
        try:
            from backend.elevenlabs_tts_service import clean_text_for_tts
        except ImportError:
            try:
                from elevenlabs_tts_service import clean_text_for_tts
            except ImportError:
                clean_text_for_tts = lambda t: t  # noqa: E731
        text = clean_text_for_tts(text)

        _, default_voice_id = _get_voice_list()
        voice_id = (data.get("voice_id") or "").strip() or default_voice_id
        character_voice_id = (data.get("character_voice_id") or "").strip() or None
        try:
            speed = float(data.get("speed") or 1.0)
            speed = max(0.7, min(1.2, speed))  # clamp to safe range
        except (ValueError, TypeError):
            speed = 1.0

        # ── Server-side audio cache: cache-first ─────────────────────────
        # Identical (text, voice, speed, provider-chain) requests replay the
        # stored MP3 instead of re-synthesizing — the second read of any
        # story page starts instantly, costs no provider spend, and does NOT
        # consume the daily TTS quota (mirrors the illustration cache).
        #
        # Azure availability is resolved here (rather than at synthesis time
        # below) because the provider chain is part of the cache key: audio
        # cached under one chain must never be replayed to an audience the
        # other chain's licensing gates exclude (e.g. legacy Gemini audio is
        # adult-only; under-13s on the legacy chain 503 to on-device).
        azure_enabled = _get_azure_service() is not None
        try:
            from backend.services.tts_audio_cache_service import (
                compute_cache_key,
                get_cached_tts_audio,
                store_tts_audio,
            )
        except ImportError:
            try:
                from services.tts_audio_cache_service import (
                    compute_cache_key,
                    get_cached_tts_audio,
                    store_tts_audio,
                )
            except ImportError:
                compute_cache_key = None
                get_cached_tts_audio = None
                store_tts_audio = None

        cache_key = None
        if compute_cache_key is not None:
            if azure_enabled:
                # Azure serves everyone identically; premium/dialogue opt-ins
                # are bypassed, so they must not fragment the key.
                chain = "azure"
                key_premium = False
                key_dialogue = None
            else:
                # Legacy chain outcomes differ by audience (adult -> Gemini,
                # teen -> Edge, under-13 -> 503) and by the (adult-only)
                # ElevenLabs opt-in flags.
                audience = (
                    "u13" if is_under_13 else ("teen" if is_under_18 else "adult")
                )
                chain = f"legacy-{audience}"
                key_premium = premium_voice and not is_under_18
                key_dialogue = (
                    character_voice_id if (wants_dialogue and not is_under_18) else None
                )
            cache_key = compute_cache_key(
                text=text,
                voice_id=voice_id,
                speed=speed,
                chain=chain,
                premium_voice=key_premium,
                character_voice_id=key_dialogue,
            )
            cached = get_cached_tts_audio(cache_key)
            if cached is not None and cached.get("audio_base64"):
                return jsonify(
                    {
                        "audio_base64": cached["audio_base64"],
                        "format": cached.get("format") or "mp3",
                        "voice_id": voice_id,
                        "provider": cached.get("provider"),
                        "word_timestamps": cached.get("word_timestamps") or [],
                        "cached": True,
                    }
                )

        # ── Cache miss: quota gate + full provider chain ─────────────────
        if user_id:
            allowed, tts_count, tts_limit = check_tts_quota(user_id, user_tier)
            if not allowed:
                audit_log(
                    "tts_quota_exceeded",
                    user_id=user_id,
                    data={"tier": user_tier, "count": tts_count, "limit": tts_limit},
                )
                return (
                    jsonify(
                        {
                            "error": "Daily narration limit reached",
                            "code": "TTS_QUOTA_EXCEEDED",
                            "daily_limit": tts_limit,
                            "syntheses_used": tts_count,
                        }
                    ),
                    429,
                )

        # ElevenLabs is an OPT-IN premium voice rather than the paid default
        # (F-01: it costs ~3.3x Gemini Flash TTS). It is initialised and
        # attempted only when the client explicitly opts in below; the
        # default paid path is Gemini Flash TTS, then the free Edge tier.
        service = None
        elevenlabs_ok = False

        # Opt-in gate for the premium ElevenLabs voice. Dialogue-differentiated
        # narration (character_voice_id) also requires ElevenLabs, since it is
        # the only provider that supports multi-voice synthesis. Without an
        # explicit opt-in the request is served by the default Gemini -> Edge
        # chain below.
        if (premium_voice or wants_dialogue) and is_under_18:
            # Opted into a premium/dialogue ElevenLabs voice, but the user is a
            # minor — ElevenLabs' ToS bar ALL under-18s, not just under-13s
            # (MT-365; the is_under_18 flag already gates the legacy Gemini
            # chain below for the same reason). Refuse ElevenLabs and let the
            # default fallback serve the narration: Gemini is also under-18-
            # barred, so teens land on Edge while under-13s 503 to on-device.
            audit_log(
                "tts_elevenlabs_minor_blocked",
                user_id=user_id,
                data={"premium_voice": premium_voice, "wants_dialogue": wants_dialogue},
            )
        elif premium_voice or wants_dialogue:
            service = _get_tts_service()
            elevenlabs_ok = service is not None

        # Monthly ElevenLabs character-budget check (per-user + global). When
        # the premium budget is depleted we don't fail the request — we fall
        # through to the free Edge TTS voice so narration still sounds natural.
        if user_id and elevenlabs_ok:
            chars_req = raw_text_len
            ok, cap_reason, used, limit = check_tts_chars_quota(
                user_id, user_tier, chars_req
            )
            if not ok:
                audit_log(
                    "tts_chars_cap_exceeded",
                    user_id=user_id,
                    data={
                        "tier": user_tier,
                        "reason": cap_reason,
                        "used": used,
                        "limit": limit,
                        "requested": chars_req,
                    },
                )
                elevenlabs_ok = False

        audio_bytes = None
        word_timestamps = []
        provider = None

        # Azure AI Speech — the licensed primary provider (MT-248). When
        # configured it serves FIRST and the prohibited/unlicensed providers
        # (ElevenLabs, Gemini Flash TTS, Edge) are bypassed entirely; an Azure
        # failure falls straight through to the client's on-device voice.
        # (azure_enabled was resolved above, as part of the cache key.)
        if azure_enabled:
            elevenlabs_ok = False  # never use the prohibited premium path
            azure_result = _azure_synthesize(text, voice_id, speed)
            if azure_result is not None and azure_result[0]:
                audio_bytes, word_timestamps = azure_result
                provider = "azure"

        if elevenlabs_ok:
            try:
                if character_voice_id:
                    # Dialogue-differentiated synthesis: narrator + character voices.
                    # Timestamps not supported across multi-voice segments.
                    logger.info(
                        "Dialogue synthesis (%d chars) — narrator=%s character=%s",
                        len(text),
                        voice_id,
                        character_voice_id,
                    )
                    audio_bytes = service.generate_speech_with_dialogue(
                        text=text,
                        narrator_voice_id=voice_id,
                        character_voice_id=character_voice_id,
                    )
                elif len(text) > 5000:
                    # Long story — chunked synthesis to avoid ElevenLabs truncation.
                    # Timestamps not supported for chunked mode.
                    logger.info(
                        "Long story (%d chars) — using chunked synthesis", len(text)
                    )
                    audio_bytes = service.generate_speech_chunked(
                        text=text, voice_id=voice_id
                    )
                else:
                    # Short story — use with-timestamps endpoint for accurate word highlighting.
                    audio_bytes, word_timestamps = (
                        service.generate_speech_with_timestamps(
                            text=text, voice_id=voice_id, speed=speed
                        )
                    )
                provider = "elevenlabs"
            except Exception as e:
                # Any ElevenLabs failure (exhausted credits, network, API
                # error) falls through to the free Edge TTS voice rather than
                # failing the request.
                logger.error(
                    "ElevenLabs TTS synthesis error — using Edge fallback: %s", e
                )
                elevenlabs_ok = False
                audio_bytes = None

        # Legacy chain — used ONLY when Azure is not configured. Gemini Flash TTS
        # (default paid) then free Edge TTS. Gemini is under-18-barred (its API
        # ToS forbid child-directed apps, MT-137/MT-248) and both are bypassed
        # the moment Azure goes live; kept as the pre-Azure fallback so
        # dev/preview narration still works before the Azure key is set.
        #
        # Defense in depth: if Azure (the licensed provider) is unavailable —
        # e.g. an unset/expired key — minors (under 18, not just under 13) must
        # NOT silently fall through to Gemini, which is contractually barred
        # for child-directed use. Refuse Gemini for them; Edge TTS keeps its
        # original (unchanged) under-13 gate below.
        if not audio_bytes and not azure_enabled and is_under_18:
            audit_log(
                "tts_legacy_chain_gemini_blocked_minor",
                user_id=user_id,
                data={"reason": "azure_unavailable"},
            )

        if not audio_bytes and not azure_enabled and not is_under_18:
            gemini_result = _gemini_synthesize(text, voice_id, speed)
            if gemini_result is not None and gemini_result[0]:
                audio_bytes, word_timestamps = gemini_result
                provider = "gemini"

        if not audio_bytes and not azure_enabled and not is_under_13:
            edge_result = _edge_synthesize(text, voice_id, speed)
            if edge_result is not None and edge_result[0]:
                audio_bytes, word_timestamps = edge_result
                provider = "edge"

        if not audio_bytes:
            # No online TTS available (Azure failed, or the legacy chain is
            # exhausted) — the client falls back to its on-device voice.
            return (
                jsonify(
                    {
                        "error": "TTS service unavailable",
                        "message": "Narration is unavailable right now.",
                    }
                ),
                503,
            )

        if user_id:
            increment_tts_quota(user_id, user_tier)
            # Character budget and cost tracking apply only to paid ElevenLabs use.
            if provider == "elevenlabs":
                increment_tts_chars(user_id, user_tier, len(text))
                try:
                    from backend.services.cost_tracker import (
                        elevenlabs_tts_cost,
                        log_api_cost,
                    )

                    log_api_cost(
                        provider="elevenlabs",
                        feature="tts",
                        cost_usd=elevenlabs_tts_cost(len(text)),
                        user_id=user_id,
                        units=len(text),
                        unit_kind="chars",
                        success=True,
                        extra={"voice_id": voice_id, "tier": user_tier},
                    )
                except Exception:
                    logger.debug("cost_tracker logging failed", exc_info=True)
            elif provider == "gemini":
                # Don't increment the ElevenLabs char budget — Gemini is the
                # overflow tier that exists *because* that budget is exhausted.
                try:
                    from backend.services.cost_tracker import (
                        gemini_tts_cost,
                        log_api_cost,
                    )

                    log_api_cost(
                        provider="gemini",
                        feature="tts",
                        cost_usd=gemini_tts_cost(len(text)),
                        user_id=user_id,
                        units=len(text),
                        unit_kind="chars",
                        success=True,
                        extra={
                            "voice_id": voice_id,
                            "tier": user_tier,
                            "model": "gemini-3.1-flash-tts-preview",
                        },
                    )
                except Exception:
                    logger.debug("cost_tracker logging failed", exc_info=True)

        audio_b64 = base64.b64encode(audio_bytes).decode("utf-8")

        # Persist the freshly synthesized audio so the next identical request
        # (a re-read, a replay, or another child hearing the same page) is a
        # cache hit. Best-effort — a store failure never breaks the response.
        if cache_key and store_tts_audio is not None:
            store_tts_audio(
                cache_key,
                audio_b64,
                audio_format="mp3",
                provider=provider,
                word_timestamps=word_timestamps,
                user_id=user_id,
                text_chars=len(text),
            )

        return jsonify(
            {
                "audio_base64": audio_b64,
                "format": "mp3",
                "voice_id": voice_id,
                "provider": provider,  # 'azure', 'gemini', 'elevenlabs' (opt-in), or 'edge'
                "word_timestamps": word_timestamps,  # [] when not available (dialogue/chunked)
                "cached": False,
            }
        )

    return tts_bp
