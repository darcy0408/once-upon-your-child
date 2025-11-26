-- Database Optimization: Add indexes for improved query performance
-- Run this script to add indexes for analytics and common queries

-- Stories table indexes
CREATE INDEX IF NOT EXISTS idx_stories_created_at ON stories(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_stories_user_id ON stories(user_id);
CREATE INDEX IF NOT EXISTS idx_stories_theme ON stories(theme);
CREATE INDEX IF NOT EXISTS idx_stories_user_created ON stories(user_id, created_at DESC);

-- Users table indexes
CREATE INDEX IF NOT EXISTS idx_users_created_at ON users(created_at);
CREATE INDEX IF NOT EXISTS idx_users_subscription_tier ON users(subscription_tier);
CREATE INDEX IF NOT EXISTS idx_users_tier_created ON users(subscription_tier, created_at);

-- Characters table indexes (if exists)
CREATE INDEX IF NOT EXISTS idx_characters_user_id ON characters(user_id) WHERE user_id IS NOT NULL;

-- Composite indexes for complex queries
CREATE INDEX IF NOT EXISTS idx_stories_user_theme ON stories(user_id, theme);
CREATE INDEX IF NOT EXISTS idx_users_tier_active ON users(subscription_tier, created_at) WHERE subscription_tier IN ('premium', 'family');

-- Index for analytics queries
CREATE INDEX IF NOT EXISTS idx_stories_created_month ON stories(EXTRACT(YEAR FROM created_at), EXTRACT(MONTH FROM created_at));

-- Performance check: Show index creation
SELECT
    schemaname,
    tablename,
    indexname,
    indexdef
FROM pg_indexes
WHERE schemaname = 'public'
    AND tablename IN ('stories', 'users', 'characters')
ORDER BY tablename, indexname;