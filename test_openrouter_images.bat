@echo off
REM Test OpenRouter Image Generation
echo ========================================
echo Testing OpenRouter Image Generation
echo ========================================
echo.

echo 1. Testing /generate-illustrations endpoint...
echo.

curl -X POST https://story-weaver-app-production.up.railway.app/generate-illustrations ^
  -H "Content-Type: application/json" ^
  -d "{\"scene_description\": \"A brave 7-year-old named Luna befriends a tiny dragon in a magical forest\", \"character_name\": \"Luna\", \"style\": \"vibrant watercolor children's book illustration\", \"num_images\": 1, \"age\": 7}"

echo.
echo.
echo ========================================
echo Test complete!
echo ========================================
echo.
echo What to look for:
echo   - "illustrations": [...] in the response
echo   - "image_url": "https://..." with actual image URLs
echo   - "used_user_key": false (using server's OpenRouter key)
echo.
pause
