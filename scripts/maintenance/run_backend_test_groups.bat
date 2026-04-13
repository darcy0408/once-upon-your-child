@echo off
setlocal

pushd "%~dp0backend" >nul 2>&1
if %errorlevel% neq 0 (
    echo ERROR: Could not change directory to backend
    exit /b 1
)

echo Running backend unit tests...
python -m pytest tests/unit -v
if %errorlevel% neq 0 (
    popd >nul
    exit /b %errorlevel%
)

echo.
echo Running backend api_contract tests...
python -m pytest tests -m api_contract -v
if %errorlevel% neq 0 (
    popd >nul
    exit /b %errorlevel%
)

popd >nul
echo.
echo All backend test groups passed: unit, api_contract
exit /b 0
