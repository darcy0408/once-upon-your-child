@echo off
REM Story Weaver App Setup and Testing Script

cd /d C:\dev\story-weaver-app

echo.
echo ===== STEP 1: Checking Flask Backend =====
echo.

REM Check if backend is running
powershell -Command "Invoke-WebRequest -Uri 'http://localhost:5000/health' -TimeoutSec 3 -ErrorAction SilentlyContinue" >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo Flask backend is NOT running. Starting it...
    start "" /B python backend\app.py > backend_startup.log 2>&1
    echo Waiting 10 seconds for backend to start...
    timeout /t 10 /nobreak
    echo Checking health again...
    powershell -Command "Invoke-WebRequest -Uri 'http://localhost:5000/health' -TimeoutSec 3 -ErrorAction SilentlyContinue" >nul 2>&1
    if %ERRORLEVEL% NEQ 0 (
        echo Flask backend health check failed
    ) else (
        echo Flask backend is now running!
    )
) else (
    echo Flask backend is already running!
)

echo.
echo ===== STEP 2: Checking Flutter Web Build =====
echo.

if exist "build\web\index.html" (
    echo Flutter web build found!
) else (
    echo Flutter web build NOT found. Building now...
    call flutter build web --release
)

echo.
echo ===== STEP 3: Starting Flutter Web Server =====
echo.

REM Check if port 8080 is in use
netstat -ano | findstr ":8080" >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo Starting web server on port 8080...
    start "" /B python -m http.server 8080 --directory build\web > web_server.log 2>&1
    echo Web server started
) else (
    echo Port 8080 is already in use
)

echo.
echo ===== STEP 4: Verifying Both Servers =====
echo.

timeout /t 5 /nobreak

echo Checking Flask backend (port 5000)...
powershell -Command "Invoke-WebRequest -Uri 'http://localhost:5000/health' -TimeoutSec 3 -ErrorAction SilentlyContinue" >nul 2>&1
if %ERRORLEVEL% EQU 0 (
    echo [OK] Flask backend is running
) else (
    echo [FAIL] Flask backend health check failed
)

echo Checking Flutter web server (port 8080)...
powershell -Command "Invoke-WebRequest -Uri 'http://localhost:8080' -TimeoutSec 3 -ErrorAction SilentlyContinue" >nul 2>&1
if %ERRORLEVEL% EQU 0 (
    echo [OK] Flutter web server is running
) else (
    echo [FAIL] Flutter web server check failed
)

echo.
echo ===== STEP 5: Running Comprehensive Quality Check =====
echo.

set MOCK_TESTING_MODE=false
echo Starting quality check (this may take 5-10 minutes)...
call python run_comprehensive_quality_check.py

echo.
echo ===== STEP 6: Running Cross-Browser Tests =====
echo.

echo Starting cross-browser tests...
call python test_cross_browser.py

echo.
echo ===== ALL STEPS COMPLETED =====
echo.
pause
