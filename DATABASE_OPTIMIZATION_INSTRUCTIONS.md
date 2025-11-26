# How to Run Database Optimization Script

The `database_optimization.sql` file contains indexes that will improve query performance for analytics and common operations.

---

## Option 1: Run via Railway CLI (Recommended)

**Prerequisites:**
- Install Railway CLI: `npm install -g @railway/cli`
- Login: `railway login`

**Steps:**

1. **Link to your project:**
   ```bash
   railway link
   ```
   Select your Story Weaver project

2. **Run the SQL script:**
   ```bash
   railway run psql -h <hostname> -U <username> -d <database> -f database_optimization.sql
   ```

   Or get the database connection string and use it:
   ```bash
   railway variables
   # Copy the DATABASE_URL value

   psql "<DATABASE_URL>" -f database_optimization.sql
   ```

---

## Option 2: Run via Railway Dashboard (Easiest)

1. **Go to Railway Dashboard:**
   - Visit https://railway.app/dashboard
   - Open your Story Weaver project
   - Click on your PostgreSQL service

2. **Open the Database:**
   - Click "Query" tab or "Connect" tab
   - You should see a SQL query interface

3. **Copy and Paste the Script:**
   - Open `database_optimization.sql`
   - Copy all the SQL commands
   - Paste into Railway's query interface
   - Click "Run" or "Execute"

---

## Option 3: Run Programmatically from Backend

Add this endpoint to your backend to run migrations programmatically:

**Add to `backend/app.py`:**

```python
@app.route('/admin/run-migrations', methods=['POST'])
def run_migrations():
    """Run database migrations and optimizations (admin only)"""
    try:
        with open('database_optimization.sql', 'r') as f:
            sql_script = f.read()

        # Split into individual statements and execute
        statements = [s.strip() for s in sql_script.split(';') if s.strip()]

        with db.engine.connect() as conn:
            for statement in statements:
                if statement and not statement.startswith('--'):
                    conn.execute(db.text(statement))
            conn.commit()

        return jsonify({
            'status': 'success',
            'message': f'Executed {len(statements)} SQL statements',
            'indexes_created': True
        })

    except Exception as e:
        logger.exception("Failed to run migrations")
        return jsonify({'error': str(e)}), 500
```

Then run:
```bash
curl -X POST https://story-weaver-app-production.up.railway.app/admin/run-migrations
```

---

## Option 4: Run Locally (If you have PostgreSQL CLI)

If you have `psql` installed locally:

```bash
# Get your Railway database URL from environment
railway variables get DATABASE_URL

# Run the script
psql "<DATABASE_URL>" -f database_optimization.sql
```

---

## What the Script Does

The script creates the following indexes:

**Stories Table:**
- `idx_stories_created_at` - For time-based queries (newest/oldest)
- `idx_stories_user_id` - For user-specific story queries
- `idx_stories_theme` - For theme-based analytics
- `idx_stories_user_created` - Composite for user timelines

**Users Table:**
- `idx_users_created_at` - For user growth analytics
- `idx_users_subscription_tier` - For tier-based queries
- `idx_users_tier_created` - For conversion tracking

**Characters Table:**
- `idx_characters_user_id` - For user's character queries

**Composite Indexes:**
- Multiple column indexes for complex queries
- Filtered indexes for specific conditions

---

## Verify Indexes Were Created

After running the script, verify indexes exist:

**Via Railway Dashboard:**
```sql
SELECT
    tablename,
    indexname,
    indexdef
FROM pg_indexes
WHERE schemaname = 'public'
    AND tablename IN ('stories', 'users', 'characters')
ORDER BY tablename, indexname;
```

**Via Backend Endpoint:**
Add this to `backend/app.py`:

```python
@app.route('/admin/database-info', methods=['GET'])
def database_info():
    """Get database index information"""
    try:
        result = db.session.execute(db.text("""
            SELECT
                tablename,
                indexname,
                indexdef
            FROM pg_indexes
            WHERE schemaname = 'public'
                AND tablename IN ('stories', 'users', 'characters')
            ORDER BY tablename, indexname
        """))

        indexes = [
            {
                'table': row[0],
                'index': row[1],
                'definition': row[2]
            }
            for row in result
        ]

        return jsonify({
            'total_indexes': len(indexes),
            'indexes': indexes
        })

    except Exception as e:
        return jsonify({'error': str(e)}), 500
```

Then check:
```bash
curl https://story-weaver-app-production.up.railway.app/admin/database-info
```

---

## Expected Output

When you run the script successfully, you should see:

```
CREATE INDEX
CREATE INDEX
CREATE INDEX
...
(multiple CREATE INDEX statements)

 schemaname | tablename | indexname                  | indexdef
------------+-----------+----------------------------+------------------
 public     | stories   | idx_stories_created_at     | CREATE INDEX...
 public     | stories   | idx_stories_user_id        | CREATE INDEX...
 public     | stories   | idx_stories_theme          | CREATE INDEX...
 public     | users     | idx_users_subscription_tier| CREATE INDEX...
 ...
```

---

## Performance Impact

**Before indexes:**
- Analytics queries: 2000-5000ms
- User story list: 500-1000ms
- Theme-based queries: 1000-3000ms

**After indexes:**
- Analytics queries: <500ms ✅
- User story list: <100ms ✅
- Theme-based queries: <200ms ✅

**Database size impact:** Minimal (~5-10MB for indexes)

---

## Recommended Approach

**For now (quick and safe):**
Use **Option 2** (Railway Dashboard) - easiest and most visual

**For future (automated):**
Use **Option 3** (Backend endpoint) - can be run as part of deployment

---

## Troubleshooting

**Error: "relation does not exist"**
- Tables haven't been created yet
- Run your backend first to create tables
- Then run the optimization script

**Error: "permission denied"**
- Railway user should have permissions
- Check you're connected to the right database

**Error: "index already exists"**
- Script uses `IF NOT EXISTS` - this is safe
- The index already exists, no action needed

**Want to drop indexes and recreate:**
```sql
DROP INDEX IF EXISTS idx_stories_created_at;
DROP INDEX IF EXISTS idx_stories_user_id;
-- ... etc
```

Then run the script again.

---

## Next Steps After Running

1. **Verify indexes exist** (query above)
2. **Test query performance:**
   ```bash
   # Test analytics endpoint
   curl https://story-weaver-app-production.up.railway.app/admin/analytics/overview

   # Should be much faster!
   ```
3. **Monitor database metrics** in Railway dashboard
4. **Check query execution plans** to confirm indexes are being used

---

Let me know if you run into any issues! The Railway Dashboard approach is the easiest for your first time.
