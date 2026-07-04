"""Shared helper for resolving a class/attribute across import-path variants.

Several call sites across the backend need to import the same class via
either its ``backend.``-qualified path (when the app is imported as the
``backend`` package) or its bare path (when ``backend/`` itself is on
``sys.path``, e.g. scripts invoked directly from inside the backend
directory). That produced the same boilerplate over and over::

    try:
        from backend.some_module import SomeClass
    except ImportError:
        try:
            from some_module import SomeClass
        except ImportError:
            SomeClass = None

``load_first_available`` collapses that into one call: it tries each
``(module_path, attr_name)`` candidate IN ORDER and returns the first one
that resolves, or ``None`` if every candidate fails. This is a pure
import-resolution helper — it does not instantiate anything, log, or
change which provider a caller ends up using; callers keep their own
instantiation/logging/fallback-order logic exactly as before.
"""

import importlib
from typing import Any, Iterable, Optional, Tuple


def load_first_available(candidates: Iterable[Tuple[str, str]]) -> Optional[Any]:
    """Return the first ``attr_name`` importable from ``module_path``.

    Args:
        candidates: ``(module_path, attr_name)`` pairs, tried in order.
            The first candidate that imports successfully wins.

    Returns:
        The resolved attribute (typically a class), or ``None`` if every
        candidate failed to import.
    """
    for module_path, attr_name in candidates:
        try:
            module = importlib.import_module(module_path)
            return getattr(module, attr_name)
        except ImportError:
            continue
    return None
