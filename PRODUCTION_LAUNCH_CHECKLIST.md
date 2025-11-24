# Story Weaver Production Launch Checklist

## Pre-Launch (Complete Before Go-Live)

### Stripe Configuration
- [ ] **Decision:** Test mode vs Live mode?
  - Current: TEST MODE (safe for testing)
  - Live mode requires: Account verification complete

- [ ] If going LIVE:
  - [ ] Complete Stripe account verification
  - [ ] Switch to Live mode in Stripe dashboard
  - [ ] Update Railway backend environment variables:
    - [ ] STRIPE_API_KEY → Live key (starts with sk_live_)
    - [ ] STRIPE_WEBHOOK_SECRET → Live webhook secret
    - [ ] STRIPE_PRICE_ID_PREMIUM → Live premium price ID
    - [ ] STRIPE_PRICE_ID_FAMILY → Live family price ID
  - [ ] Update webhook URL to use live mode endpoint
  - [ ] Test with real card (refund immediately to verify)
  - [ ] Verify webhook events deliver successfully

- [ ] If staying in TEST MODE (recommended for soft launch):
  - [ ] Add banner to app: "Beta Testing - No Real Charges"
  - [ ] Set up analytics to track test users
  - [ ] Plan migration date to Live mode

### API Keys & Secrets
- [ ] Rotate Gemini API key (current key recently leaked)
  - [ ] Generate fresh key at https://aistudio.google.com/app/apikey
  - [ ] Update GEMINI_API_KEY in Railway backend
  - [ ] Test story generation after rotation
  - [ ] Verify interactive stories work

- [ ] Document all environment variables in secure location
  - [ ] Backend Railway variables (with last 4 chars only)
  - [ ] Frontend Railway variables
  - [ ] Recovery procedures if keys compromised

### Monitoring & Alerts
- [ ] Set up Railway log monitoring
  - [ ] Configure log retention (default: 7 days)
  - [ ] Set up error alerts (if available on your plan)

- [ ] Create monitoring dashboard spreadsheet
  - [ ] Track daily active users
  - [ ] Track story generation count
  - [ ] Track Stripe conversions
  - [ ] Track error rates
  - [ ] Track response times

- [ ] Set up basic uptime monitoring
  - [ ] Use free service (UptimeRobot, Pingdom free tier)
  - [ ] Monitor: https://story-weaver-app-production.up.railway.app/health
  - [ ] Alert email if down > 2 minutes
  - [ ] Check every 5 minutes

### Backup & Disaster Recovery
- [ ] Document Railway PostgreSQL backup procedure
- [ ] Test database backup restore (if possible)
- [ ] Document rollback procedures (already in TEAM_COORDINATION.md)
- [ ] Create emergency contact list (Railway support, Stripe support)

### Legal & Compliance
- [ ] Privacy Policy page created
  - [ ] Data collection disclosure
  - [ ] Cookie usage (if applicable)
  - [ ] Third-party services (Gemini, Stripe)
  - [ ] COPPA compliance (app targets children)
  - [ ] Parent/guardian consent mechanism

- [ ] Terms of Service page created
  - [ ] Subscription terms
  - [ ] Refund policy
  - [ ] Content usage rights
  - [ ] Age requirements
  - [ ] Parent/guardian consent mechanism

- [ ] Add links to Privacy Policy & Terms in app footer
- [ ] Add to Stripe checkout flow (required)

### Content Safety
- [ ] Review story generation for inappropriate content
  - [ ] Test edge cases (unusual character names, themes)
  - [ ] Verify age-appropriate content filters working
  - [ ] Test therapeutic prompts for safety

- [ ] Set up content moderation plan
  - [ ] How to handle user reports
  - [ ] Response time for safety concerns
  - [ ] Contact email for parents/guardians

## Launch Day Checklist

### Hour -24 (Day Before)
- [ ] Announce launch on social media (if applicable)
- [ ] Send email to beta testers (if applicable)
- [ ] Final test of all critical paths:
  - [ ] Story generation
  - [ ] Interactive stories
  - [ ] Stripe checkout (both tiers)
  - [ ] Mobile responsive
  - [ ] Error handling

### Hour -4 (Morning of Launch)
- [ ] Check Railway service health
- [ ] Verify Gemini API quota not near limit
- [ ] Check Stripe dashboard for any issues
- [ ] Verify all environment variables set correctly
- [ ] Test health endpoint returns all green

### Hour 0 (Launch!)
- [ ] Post announcement (website, social media, email)
- [ ] Monitor Railway logs in real-time (first 30 minutes)
- [ ] Watch for error spikes
- [ ] Be ready to rollback if critical issues

### Hour +1
- [ ] Check first user signups/trials
- [ ] Verify Stripe webhooks delivering
- [ ] Review error logs
- [ ] Monitor response times

### Hour +4
- [ ] Generate first usage report
- [ ] Respond to any user feedback/issues
- [ ] Document any bugs found

### Hour +24 (Next Day)
- [ ] Full system health check
- [ ] Review 24-hour metrics
- [ ] Celebrate successful launch! 🎉

## Post-Launch Monitoring (First Week)

### Daily (First 7 Days)
- [ ] Review Railway backend logs for errors
- [ ] Check Stripe dashboard for successful payments
- [ ] Verify webhook deliveries successful
- [ ] Test one complete user flow daily
- [ ] Document any issues found
- [ ] Respond to user feedback within 24 hours

### Weekly Review (After 7 Days)
- [ ] Performance analysis (response times)
- [ ] Error rate calculation
- [ ] User feedback summary
- [ ] Resource usage trends (Railway metrics)
- [ ] Cost analysis (Railway + Stripe fees + Gemini API)
- [ ] Plan improvements for week 2

## Success Metrics

### Week 1 Goals
- [ ] Zero critical bugs
- [ ] < 1% error rate
- [ ] Story generation < 20s average
- [ ] At least 1 successful Stripe subscription (if live mode)
- [ ] Mobile responsive confirmed by real users
- [ ] 95%+ uptime