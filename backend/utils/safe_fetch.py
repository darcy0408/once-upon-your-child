"""Outbound fetch guard for URLs the server did not choose itself.

Image providers hand back URLs to download, and some request fields may carry
an image URL. Either way the address is not ours, so before fetching it we
require https and a host that resolves only to public internet addresses —
never loopback, private, link-local, or otherwise internal ranges. Redirects
are followed by hand so every hop gets the same check.
"""

from __future__ import annotations

import ipaddress
import socket
from urllib.parse import urljoin, urlsplit

import requests

MAX_REDIRECTS = 3
DEFAULT_MAX_BYTES = 5 * 1024 * 1024


class UnsafeURLError(ValueError):
    """The URL is not one the server is willing to fetch."""


def _resolve(host: str) -> list[str]:
    return [info[4][0] for info in socket.getaddrinfo(host, None)]


def assert_public_url(url: str, resolve=None) -> None:
    """Raise UnsafeURLError unless *url* is https to a public internet host."""
    if not isinstance(url, str):
        raise UnsafeURLError("URL must be a string")
    parts = urlsplit(url.strip())
    if parts.scheme != "https":
        raise UnsafeURLError("only https URLs may be fetched")
    host = parts.hostname
    if not host or parts.username or parts.password:
        raise UnsafeURLError("URL has no usable host")
    try:
        addresses = (resolve or _resolve)(host)
    except OSError as exc:
        raise UnsafeURLError("host did not resolve") from exc
    if not addresses:
        raise UnsafeURLError("host did not resolve")
    for address in addresses:
        ip = ipaddress.ip_address(address.split("%", 1)[0])
        if isinstance(ip, ipaddress.IPv6Address) and ip.ipv4_mapped:
            ip = ip.ipv4_mapped
        if not ip.is_global or ip.is_multicast:
            raise UnsafeURLError("host is not a public internet address")


def safe_get(url: str, *, timeout: float = 30, stream: bool = False, resolve=None):
    """``requests.get`` for untrusted URLs: every hop is checked first."""
    current = url
    for _ in range(MAX_REDIRECTS + 1):
        assert_public_url(current, resolve=resolve)
        response = requests.get(
            current, timeout=timeout, stream=stream, allow_redirects=False
        )
        if not response.is_redirect:
            return response
        location = response.headers.get("Location", "")
        response.close()
        current = urljoin(current, location)
    raise UnsafeURLError("too many redirects")


def safe_get_bytes(
    url: str, *, timeout: float = 30, max_bytes: int = DEFAULT_MAX_BYTES
) -> bytes:
    """Fetch *url* with the checks above and a hard size cap."""
    response = safe_get(url, timeout=timeout, stream=True)
    try:
        response.raise_for_status()
        declared = response.headers.get("Content-Length")
        if declared and declared.isdigit() and int(declared) > max_bytes:
            raise ValueError(f"download too large: {declared} bytes")
        body = bytearray()
        for chunk in response.iter_content(chunk_size=8192):
            body.extend(chunk)
            if len(body) > max_bytes:
                raise ValueError("download exceeded size limit")
        return bytes(body)
    finally:
        response.close()
