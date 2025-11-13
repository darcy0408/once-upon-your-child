# Production Deployment Script
# Run this when Railway access is available

# 1. Login to Railway
railway login

# 2. Link to project (if not already linked)
railway link

# 3. Set production environment variables
railway variables set NEW_RELIC_LICENSE_KEY="your_license_key"
railway variables set GEMINI_API_KEY="your_production_key"
railway variables set SECRET_KEY="your_secret_key"

# 4. Deploy backend
railway up

# 5. Get backend URL
railway domain

# 6. Run database migration
railway run python migrate_sqlite_to_postgres.py
