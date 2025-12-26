@echo off
REM Run Backend Tests for Pick-A-Path Adventures UX Improvements
REM This script runs all tests that don't require a browser

echo ================================================================================
echo  RUNNING BACKEND TESTS - PICK-A-PATH ADVENTURES
echo ================================================================================
echo.

REM Check if Python is available
python --version >nul 2>&1
if %errorlevel% neq 0 (
    echo ERROR: Python not found. Please install Python 3.8+ and add to PATH.
    exit /b 1
)

echo Python version:
python --version
echo.

REM Check if GEMINI_API_KEY is set
if "%GEMINI_API_KEY%"=="" (
    echo WARNING: GEMINI_API_KEY not set
    echo Story generation tests will be skipped
    echo.
    echo To enable all tests, set your API key:
    echo   set GEMINI_API_KEY=your-key-here
    echo.
    pause
)

echo ================================================================================
echo  TEST 1: Backend Comprehensive Tests
echo ================================================================================
echo.

REM Try with pytest first (better output)
pytest --version >nul 2>&1
if %errorlevel% equ 0 (
    echo Running with pytest...
    python -m pytest tests/test_backend_comprehensive.py -v --tb=short
) else (
    echo pytest not found, running with unittest...
    python tests/test_backend_comprehensive.py
)

if %errorlevel% neq 0 (
    echo.
    echo ================================================================================
    echo  TESTS FAILED
    echo ================================================================================
    pause
    exit /b 1
)

echo.
echo ================================================================================
echo  ALL BACKEND TESTS PASSED!
echo ================================================================================
echo.

pause
