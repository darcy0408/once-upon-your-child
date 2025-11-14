import sys
print(sys.path)

import pytest
from backend.app import create_app

def test_app_creation():
    app = create_app('dev')
    assert app is not None