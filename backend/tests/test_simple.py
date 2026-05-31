import sys

print(sys.path)

import os

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from backend.app import create_app


def test_app_creation():
    app = create_app("testing")
    assert app is not None
