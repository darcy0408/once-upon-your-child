# Grok - Week 3 Tasks (Progressive Features & Analytics)

**Assigned to**: Grok
**Priority**: MEDIUM-HIGH - Progressive unlock system + data analysis
**Timeline**: Week 3 (Nov 26 - Dec 2)

---

## Current Status Summary

### ✅ Completed (Weeks 1-2)
- GR1: Railway deployment monitoring ✅
- GR2: Structured JSON logging ✅
- GR3: Rate limiting verification ✅
- GR4: Enhanced health checks + uptime monitoring ✅
- GR5: Database backup system ✅
- GR6: Flask-Caching + performance optimization ✅

### 📋 Week 3 Focus
Progressive feature unlocks + analytics dashboards + backend polish

---

## Task GR3.1: Progressive Feature Unlock System (Priority: HIGH)

**User Pain Point**: "15+ screens overwhelm new users. Too many features upfront."

**Objective**: Implement backend + frontend for progressive feature unlocking.

### System Design:

**Unlock Thresholds**:
- After **1st story**: Character creation unlocks
- After **2nd story**: Interactive stories unlock
- After **3rd story**: Coloring pages unlock
- After **5th story**: Advanced settings unlock (BYOK, therapeutic customization)

### Implementation Steps:

1. **Create Feature Unlock Service (Frontend)**
   - File: `lib/services/feature_unlock_service.dart` (NEW)
   - Track stories created count
   - Check if feature is unlocked
   - Return unlock status for all features
   - Handle manual unlocks for premium users

2. **Backend Unlock Tracking**
   - File: `backend/app.py` (add unlock endpoints)
   - Endpoint: `GET /users/{user_id}/feature-unlocks`
   - Endpoint: `POST /users/{user_id}/story-created` (increment counter)
   - Store unlock state in database

3. **Database Schema Update**
```sql
-- Add to users table or create feature_unlocks table
ALTER TABLE users ADD COLUMN stories_created_count INTEGER DEFAULT 0;

CREATE TABLE feature_unlocks (
  user_id TEXT PRIMARY KEY,
  stories_created INTEGER DEFAULT 0,
  character_creation_unlocked BOOLEAN DEFAULT FALSE,
  interactive_stories_unlocked BOOLEAN DEFAULT FALSE,
  coloring_pages_unlocked BOOLEAN DEFAULT FALSE,
  advanced_settings_unlocked BOOLEAN DEFAULT FALSE,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

4. **Frontend UI Updates**
   - File: `lib/widgets/feature_unlock_tooltip.dart` (NEW)
   - Show "🎉 New Feature Unlocked!" celebratory dialog
   - Display locked features with unlock requirements
   - Update bottom navigation to show lock icons

### Feature Unlock Flow:
```
User Creates Story
  ↓
Increment stories_created counter (backend)
  ↓
Check unlock thresholds (frontend)
  ↓
If threshold reached:
  - Show celebration dialog
  - Update UI to reveal feature
  - Track unlock event in analytics
```

### Testing:
- [ ] Counter increments after each story
- [ ] Features unlock at correct thresholds
- [ ] Locked features show clear requirements
- [ ] Unlock celebration displays correctly
- [ ] Premium users bypass unlock system
- [ ] Unlock state persists across sessions

### Success Metrics:
- New user overwhelm: -40%
- Feature discovery rate: +50%
- Session length: +25%

---

## Task GR3.2: Analytics Dashboard (Priority: MEDIUM)

**Objective**: Create internal analytics dashboard for monitoring app health and usage.

### Implementation Steps:

1. **Backend Analytics Endpoints**
   - File: `backend/analytics_routes.py` (NEW)
   - Endpoint: `GET /admin/analytics/overview`
   - Endpoint: `GET /admin/analytics/story-stats`
   - Endpoint: `GET /admin/analytics/user-activity`
   - Endpoint: `GET /admin/analytics/feature-usage`

2. **Analytics Queries**
```python
# backend/analytics_routes.py
from flask import Blueprint, jsonify
from datetime import datetime, timedelta

analytics_bp = Blueprint('analytics', __name__)

@analytics_bp.route('/admin/analytics/overview')
def get_overview():
    """Daily/weekly/monthly overview stats"""
    return jsonify({
        'today': {
            'stories_created': get_stories_created_count(days=1),
            'active_users': get_active_users_count(days=1),
            'api_errors': get_error_count(days=1),
        },
        'this_week': {
            'stories_created': get_stories_created_count(days=7),
            'active_users': get_active_users_count(days=7),
            'avg_story_time': get_avg_story_generation_time(days=7),
        },
        'this_month': {
            'stories_created': get_stories_created_count(days=30),
            'new_users': get_new_users_count(days=30),
            'premium_conversions': get_premium_conversion_count(days=30),
        }
    })

@analytics_bp.route('/admin/analytics/story-stats')
def get_story_stats():
    """Story generation statistics"""
    return jsonify({
        'by_theme': get_story_count_by_theme(),
        'by_character_type': get_story_count_by_character(),
        'avg_generation_time': get_avg_story_generation_time(),
        'failure_rate': get_story_failure_rate(),
        'interactive_vs_standard': get_story_type_breakdown(),
    })

@analytics_bp.route('/admin/analytics/feature-usage')
def get_feature_usage():
    """Feature adoption rates"""
    return jsonify({
        'illustrations_generated': get_illustration_count(),
        'coloring_pages_created': get_coloring_page_count(),
        'byok_active_users': get_byok_user_count(),
        'grace_period_users': get_grace_period_user_count(),
        'premium_users': get_premium_user_count(),
    })
```

3. **Frontend Dashboard (Optional)**
   - File: `lib/screens/admin_analytics_screen.dart` (NEW)
   - Display key metrics in card layout
   - Charts for trends (optional - use fl_chart package)
   - Refresh button to update data

### Metrics to Track:
- **Usage**: Stories/day, active users, session duration
- **Performance**: Avg generation time, error rates, slow requests
- **Features**: Illustration usage, interactive story adoption, BYOK usage
- **Monetization**: Grace period status, premium conversions, Stripe events

### Testing:
- [ ] Analytics endpoints return correct data
- [ ] Date ranges work correctly (daily/weekly/monthly)
- [ ] Queries are optimized (no N+1 problems)
- [ ] Dashboard displays data clearly
- [ ] Refresh updates data

---

## Task GR3.3: Story Quality Indicators (Priority: LOW)

**User Pain Point**: "Can't tell if story will be good quality before generating."

**Objective**: Add quality scoring system for stories.

### Implementation Steps:

1. **Backend Quality Scoring**
   - File: `backend/quality_service.py` (NEW)
   - Score stories based on:
     - Length (word count)
     - Therapeutic content (keyword analysis)
     - Age-appropriateness
     - Grammar/readability
   - Return quality score (0-100)

2. **Quality Metrics**
```python
# backend/quality_service.py
def calculate_story_quality(story_text: str, age: int) -> dict:
    """Calculate quality score for a story"""

    # Length score (age-appropriate word count)
    word_count = len(story_text.split())
    target_words = age * 50  # e.g., 6yo = 300 words
    length_score = min(100, (word_count / target_words) * 100)

    # Therapeutic content score (keyword presence)
    therapeutic_keywords = ['feel', 'learn', 'grow', 'friend', 'help', ...]
    keyword_score = calculate_keyword_presence(story_text, therapeutic_keywords)

    # Readability score (Flesch-Kincaid)
    readability_score = calculate_readability(story_text, age)

    # Overall score (weighted average)
    overall_score = (
        length_score * 0.3 +
        keyword_score * 0.4 +
        readability_score * 0.3
    )

    return {
        'overall_score': round(overall_score),
        'length_score': round(length_score),
        'therapeutic_score': round(keyword_score),
        'readability_score': round(readability_score),
        'word_count': word_count,
        'grade_level': calculate_grade_level(story_text),
    }
```

3. **Frontend Display**
   - File: `lib/story_result_screen.dart`
   - Show quality indicator badge (Great/Good/Fair)
   - Display detailed scores in info dialog (optional)
   - Track quality scores in analytics

### Testing:
- [ ] Quality scoring algorithm works
- [ ] Scores correlate with user satisfaction
- [ ] Badge displays correctly
- [ ] No performance impact on story generation

---

## Task GR3.4: Backend Monitoring Enhancements (Priority: LOW)

**Objective**: Enhance monitoring from GR4 with alerting and dashboards.

### Implementation Steps:

1. **Configure Railway Alerts**
   - Set up email alerts for:
     - Backend downtime (>5 minutes)
     - High error rates (>5% of requests)
     - Slow response times (>10s average)
     - Memory usage >80%

2. **Enhance Uptime Monitor**
   - File: `monitoring/uptime_monitor.py`
   - Add Slack/Discord webhook notifications
   - Monitor detailed health endpoint metrics
   - Alert on database connection issues
   - Track API quota usage (Gemini)

3. **Create Weekly Report**
   - File: `monitoring/weekly_report.py` (NEW)
   - Generate automated weekly reports:
     - Uptime percentage
     - Average response times
     - Top errors
     - Story generation metrics
     - Resource usage

### Testing:
- [ ] Alerts fire correctly
- [ ] Notifications received (email/Slack)
- [ ] Reports generate successfully
- [ ] Metrics are accurate

---

## Priority Order

1. **GR3.1**: Progressive Feature Unlocks (HIGH - core UX improvement)
2. **GR3.2**: Analytics Dashboard (MEDIUM - monitoring/insights)
3. **GR3.3**: Story Quality Indicators (LOW - nice-to-have)
4. **GR3.4**: Monitoring Enhancements (LOW - polish)

---

## Deliverables

- [ ] Feature unlock service (frontend + backend)
- [ ] Database schema updates for unlock tracking
- [ ] Unlock celebration UI
- [ ] Analytics dashboard endpoints
- [ ] Story quality scoring system (if time permits)
- [ ] Enhanced monitoring and alerts
- [ ] Update DEPLOYMENT_STATUS.md with new systems
- [ ] Update TEAM_COORDINATION.md with completion status

---

## Notes

- **Feature unlocks**: Don't make it feel like a paywall - emphasize discovery
- **Analytics**: Focus on actionable metrics, not vanity metrics
- **Quality scoring**: Keep it simple, don't over-engineer
- **Monitoring**: Ensure alerts are actionable, not noise

---

## Success Criteria

- [ ] Feature unlock system working smoothly
- [ ] New users report less overwhelm
- [ ] Analytics dashboard provides useful insights
- [ ] Quality scoring correlates with user satisfaction
- [ ] Monitoring catches issues before users report them
- [ ] No regressions in backend performance
