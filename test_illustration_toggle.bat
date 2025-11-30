@echo off
echo ========================================
echo Testing Illustration Toggle
echo ========================================
echo.

echo Test 1: WITHOUT includeIllustrations flag
echo.
curl -X POST https://story-weaver-app-production.up.railway.app/generate-story -H "Content-Type: application/json" -d "{\"character\": \"Luna\", \"theme\": \"Adventure\", \"character_age\": 7, \"include_illustrations\": false, \"subscription_tier\": \"free\"}"
echo.
echo.

echo Test 2: WITH includeIllustrations flag (should generate images for premium)
echo.
curl -X POST https://story-weaver-app-production.up.railway.app/generate-story -H "Content-Type: application/json" -d "{\"character\": \"Luna\", \"theme\": \"Adventure\", \"character_age\": 7, \"include_illustrations\": true, \"subscription_tier\": \"premium\"}"
echo.
echo.

echo ========================================
echo Tests complete!
echo ========================================
echo.
echo What to look for:
echo   Test 1: Should have NO "illustrations" field
echo   Test 2: Should have "illustrations": [...] with image URLs
echo.
pause
