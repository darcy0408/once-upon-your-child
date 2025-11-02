"""Wrapper to run app.py with proper UTF-8 encoding"""
import sys
import os

# Set UTF-8 encoding for stdout and stderr
sys.stdout.reconfigure(encoding='utf-8')
sys.stderr.reconfigure(encoding='utf-8')

# Change to the backend directory
os.chdir(os.path.dirname(os.path.abspath(__file__)))

# Import and run the app
import app
