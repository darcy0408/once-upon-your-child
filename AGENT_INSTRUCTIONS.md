# Agent Instructions - Week 4 Tasks

**Date**: November 25, 2025
**Status**: Week 4 - Production Readiness Phase

---

## 📋 For CODEX 1

**Your Task File**: `CODEX1_WEEK4_TASKS.md`

**What to do**:
1. Read your task file: `CODEX1_WEEK4_TASKS.md`
2. Work through tasks in priority order:
   - **C4.1**: Story Library Enhancements (HIGH)
   - **C4.2**: Onboarding Improvements (MEDIUM)
   - **C4.4**: Accessibility Improvements (MEDIUM)
   - **C4.3**: Settings Screen Polish (LOW)
   - **C4.5**: Performance Optimization (LOW)

3. For each task:
   - Follow the implementation steps provided
   - Complete the testing checklist
   - Mark deliverables as done
   - Update `TEAM_COORDINATION.md` with progress

**Key Focus**: UX polish and production-ready frontend features. Your Week 3 work (character templates, feature tour, pull-to-refresh) was excellent - now we're adding the final polish layer.

**Success Criteria**:
- Story library feels rich and useful with filtering/sorting
- Onboarding completion rate >70% (up from 30%)
- Accessibility score >90% on Lighthouse
- No regressions from previous weeks

---

## 📋 For CODEX 2

**Your Task File**: `CODEX2_WEEK4_TASKS.md`

**What to do**:
1. Read your task file: `CODEX2_WEEK4_TASKS.md`
2. Work through tasks in priority order:
   - **C2-4.1**: Privacy Policy & Terms of Service (CRITICAL ⚠️)
   - **C2-4.2**: Parental Consent Flow (CRITICAL ⚠️)
   - **C2-4.4**: Production Deployment Checklist (HIGH)
   - **C2-4.3**: Content Safety Review (HIGH)

3. For each task:
   - Follow the implementation steps provided
   - Complete the testing checklist
   - Mark deliverables as done
   - Update `TEAM_COORDINATION.md` with progress

**Key Focus**: Legal compliance and production blockers. You're taking over from Gemini (who hit session limit). These tasks are **CRITICAL** - we cannot launch without them.

**⚠️ CRITICAL NOTES**:
- Tasks C2-4.1 and C2-4.2 are **HARD BLOCKERS** for production
- Cannot submit to app stores without Privacy Policy/Terms
- COPPA compliance (parental consent) is legally required
- Do NOT skip the parental consent flow

**Success Criteria**:
- COPPA compliant (age gate + parental consent working)
- Privacy policy and terms accessible from multiple locations
- Content safety measures active
- Ready for production launch with zero legal blockers

---

## 📋 For GROK

**Your Task File**: `GROK_WEEK4_TASKS.md`

**What to do**:
1. Read your task file: `GROK_WEEK4_TASKS.md`
2. Work through tasks in priority order:
   - **GR4.1**: API Rate Limiting Enhancement (HIGH)
   - **GR4.2**: Database Optimization & Indexing (HIGH)
   - **GR4.4**: Cost Monitoring & Alerts (MEDIUM)
   - **GR4.3**: Automated Deployment Pipeline (MEDIUM)
   - **GR4.5**: Production Monitoring Dashboard (LOW)

3. For each task:
   - Follow the implementation steps provided
   - Complete the testing checklist
   - Mark deliverables as done
   - Update `TEAM_COORDINATION.md` with progress

**Key Focus**: Backend hardening and production infrastructure. Your Week 2-3 work (analytics, progressive unlocks, monitoring) laid the foundation - now we're adding production-scale protections.

**Success Criteria**:
- Rate limiting protects against abuse (tier-based limits working)
- Database queries <500ms (with proper indexing)
- Deployments fully automated with safety checks
- Cost tracking prevents surprise API bills
- Production metrics visible and accurate

---

## 🔄 General Instructions (All Agents)

### Before You Start:
1. **Pull latest changes**: `git pull origin main`
2. **Read your task file completely**
3. **Check `TEAM_COORDINATION.md`** for any updates from other agents

### While Working:
1. **Update `TEAM_COORDINATION.md`** when you start/complete tasks
2. **Test thoroughly** - use the testing checklists provided
3. **Commit frequently** with descriptive messages
4. **Ask questions** if requirements are unclear

### When Done:
1. **Run all tests**: Backend tests + Flutter tests
2. **Update documentation**: Mark tasks complete in your task file
3. **Final commit and push**: All changes to main branch
4. **Report completion**: Add summary to `TEAM_COORDINATION.md`

### Communication Protocol:
- Use `TEAM_COORDINATION.md` for status updates
- Format: `YYYY-MM-DD HH:MM UTC · [Agent Name] → [Audience]: [Message]`
- Example: `2025-11-25 18:00 UTC · Codex 1 → Team: ✅ C4.1 Complete - Story library filtering working`

---

## ⚠️ Critical Reminders

**For CODEX 2 specifically**:
- Your tasks are **PRODUCTION BLOCKERS**
- Privacy policy and parental consent are legally required
- Cannot skip or defer these tasks
- Test the parental consent flow thoroughly with different age groups

**For GROK specifically**:
- Rate limiting is critical to prevent API cost overruns
- Database indexes are essential for analytics performance
- Cost monitoring will protect against surprise bills

**For CODEX 1 specifically**:
- Accessibility is not optional - real users depend on it
- Onboarding improvements directly affect conversion rates
- Test with real devices, not just emulators

---

## 📊 Week 4 Timeline

**Target Completion**: December 3, 2025
**Days Available**: 7 days
**Estimated Work**: 2-3 days per agent (tasks are smaller than Week 3)

**Milestones**:
- Day 1-2: High priority tasks (CRITICAL and HIGH)
- Day 3-4: Medium priority tasks
- Day 5: Low priority tasks + testing
- Day 6: Integration testing + bug fixes
- Day 7: Final polish + documentation

---

## 🎯 Success = Production Ready

When Week 4 is complete, Story Weaver will be:
- ✅ Legally compliant (privacy, terms, COPPA)
- ✅ Production-hardened backend (rate limits, monitoring, optimized)
- ✅ Polished UX (accessible, engaging, performant)
- ✅ Ready for app store submission
- ✅ Ready for public launch

**Let's ship this! 🚀**
