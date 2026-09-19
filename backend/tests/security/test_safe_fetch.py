"""The server only downloads https URLs on the public internet."""

from unittest.mock import MagicMock, patch

import pytest

from backend.utils.safe_fetch import (
    UnsafeURLError,
    assert_public_url,
    safe_get,
    safe_get_bytes,
)

PUBLIC = "93.184.216.34"


def _resolver(*addresses):
    return lambda host: list(addresses)


@pytest.mark.parametrize(
    "address",
    [
        "127.0.0.1",
        "10.0.0.5",
        "172.16.3.4",
        "192.168.1.1",
        "169.254.169.254",
        "100.64.0.1",
        "0.0.0.0",
        "::1",
        "fd12:3456::1",
        "fe80::1",
        "::ffff:10.0.0.5",
    ],
)
def test_internal_addresses_are_refused(address):
    with pytest.raises(UnsafeURLError):
        assert_public_url("https://images.example/x.png", resolve=_resolver(address))


def test_one_internal_address_among_public_ones_is_refused():
    with pytest.raises(UnsafeURLError):
        assert_public_url(
            "https://images.example/x.png", resolve=_resolver(PUBLIC, "10.0.0.5")
        )


@pytest.mark.parametrize(
    "url",
    [
        "http://images.example/x.png",
        "file:///etc/passwd",
        "ftp://images.example/x.png",
        "https://user:pw@images.example/x.png",
        "https:///x.png",
        None,
    ],
)
def test_non_https_or_malformed_urls_are_refused(url):
    with pytest.raises(UnsafeURLError):
        assert_public_url(url, resolve=_resolver(PUBLIC))


def test_unresolvable_host_is_refused():
    def boom(host):
        raise OSError("no such host")

    with pytest.raises(UnsafeURLError):
        assert_public_url("https://images.example/x.png", resolve=boom)


def test_public_https_url_is_allowed():
    assert_public_url("https://images.example/x.png", resolve=_resolver(PUBLIC))


def _response(is_redirect=False, location=None, chunks=(b"img",), length=None):
    response = MagicMock()
    response.is_redirect = is_redirect
    response.headers = {}
    if location:
        response.headers["Location"] = location
    if length is not None:
        response.headers["Content-Length"] = str(length)
    response.iter_content.return_value = list(chunks)
    return response


def test_redirect_to_internal_host_is_refused_before_it_is_fetched():
    hosts = {"images.example": [PUBLIC], "internal.example": ["10.0.0.5"]}
    with patch("backend.utils.safe_fetch.requests.get") as mock_get:
        mock_get.return_value = _response(
            is_redirect=True, location="https://internal.example/secret"
        )
        with pytest.raises(UnsafeURLError):
            safe_get("https://images.example/x.png", resolve=lambda h: hosts[h])
        assert mock_get.call_count == 1
        assert mock_get.call_args.kwargs["allow_redirects"] is False


def test_redirect_loop_is_bounded():
    with patch("backend.utils.safe_fetch.requests.get") as mock_get:
        mock_get.return_value = _response(
            is_redirect=True, location="https://images.example/again"
        )
        with pytest.raises(UnsafeURLError):
            safe_get("https://images.example/x.png", resolve=_resolver(PUBLIC))


def test_size_cap_is_enforced_while_streaming():
    with patch("backend.utils.safe_fetch._resolve", _resolver(PUBLIC)), patch(
        "backend.utils.safe_fetch.requests.get"
    ) as mock_get:
        mock_get.return_value = _response(chunks=[b"x" * 60, b"x" * 60])
        with pytest.raises(ValueError, match="size limit"):
            safe_get_bytes("https://images.example/x.png", max_bytes=100)
        mock_get.return_value = _response(chunks=[b"x" * 60])
        assert safe_get_bytes("https://images.example/x.png", max_bytes=100) == (
            b"x" * 60
        )


def test_openrouter_generator_refuses_an_internal_avatar_url():
    from backend.openrouter_image_generator import OpenRouterImageGenerator

    generator = OpenRouterImageGenerator(api_key="test-key")
    with patch("backend.utils.safe_fetch._resolve", _resolver("10.0.0.5")), patch(
        "backend.utils.safe_fetch.requests.get"
    ) as mock_get:
        assert (
            generator._normalize_image_to_base64("https://internal.example/x") is None
        )
        mock_get.assert_not_called()

    with patch("backend.utils.safe_fetch._resolve", _resolver(PUBLIC)), patch(
        "backend.utils.safe_fetch.requests.get"
    ) as mock_get:
        mock_get.return_value = _response(chunks=[b"img"])
        assert generator._normalize_image_to_base64("https://cdn.example/x") == "aW1n"
