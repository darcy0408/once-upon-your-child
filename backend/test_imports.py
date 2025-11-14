#!/usr/bin/env python3
"""Test script to verify modular imports work"""
try:
    from models.character import Character
    print("✅ Character model import successful")
except ImportError as e:
    print(f"❌ Character model import failed: {e}")
try:
    from config import Config, config_by_name
    print("✅ Config import successful")
except ImportError as e:
    print(f"❌ Config import failed: {e}")
try:
    # Test that we can still import from the main app
    from backend.app import create_app
    print("✅ Main app import still works")
except ImportError as e:
    print(f"❌ Main app import failed: {e}")
