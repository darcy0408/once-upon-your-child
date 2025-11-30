# Supervisor Quick Start Guide

## How to Use This Multi-Agent System

### Your Role (Claude Supervisor)
- **Plan** daily work and break it into agent-specific tasks
- **Monitor** TEAM_COORDINATION.md for blockers and questions
- **Unblock** agents when they get stuck
- **Integrate** agent work when needed
- **Fix** critical issues that require judgment/expertise

### Daily Workflow

#### 1. Morning Planning (5 min)
```
1. Read TEAM_COORDINATION.md
2. Identify today's priorities from DEPLOYMENT_PLAN_3_WEEK.md
3. Break work into agent tasks (use templates below)
4. Start agents in order of dependencies
```

#### 2. During Day (monitoring)
```
1. Check TEAM_COORDINATION.md periodically
2. Answer agent questions quickly
3. Unblock any blockers
4. Test integration points when agents complete
```

#### 3. End of Day (15 min)
```
1. Review all agent completions
2. Run integration tests
3. Fix any integration issues
4. Plan tomorrow's work
5. Update TEAM_COORDINATION.md with supervisor notes
```

---

## Ready-to-Use Agent Tasks (Week 1 - Critical Fixes)

### Task Set 1: Avatar Fix (Quick Win)
**Duration:** ~30 minutes
**Agents Needed:** 1

**Agent 3 (Widgets):**
```
TODAY'S TASK:
Fix avatar display to show custom avatars instead of generic icons.

FILES TO MODIFY:
- lib/avatar_models.dart (line 67)

SUCCESS CRITERIA:
- [ ] Change avataaars.io to api.dicebear.com/7.x/avataaars/svg
- [ ] Test: Create character with custom hair/clothes
- [ ] Verify avatar shows customizations in preview
- [ ] Verify avatar shows in character selection

CONTEXT:
Currently avatars show generic icons due to CORS issue with avataaars.io.
DiceBear is a drop-in replacement that supports CORS.

EXACT CHANGE:
Line 67: return Uri.https('avataaars.io', '/', query).toString();
Change to: return Uri.https('api.dicebear.com', '/7.x/avataaars/svg', query).toString();
```

---

### Task Set 2: Interactive Stories Fix (Critical)
**Duration:** 2-3 hours
**Agents Needed:** 2 (sequential)

**Agent 1 (Backend) - Part 1:**
```
TODAY'S TASK:
Debug and fix interactive story generation - currently showing code instead of choices.

FILES TO MODIFY:
- backend/services/story_service.py
- backend/routes/interactive_story.py (if exists)

SUCCESS CRITERIA:
- [ ] Add logging to see exact Gemini API response
- [ ] Test generating interactive story with prompt "A dragon makes a friend"
- [ ] Identify why code blocks are appearing in response
- [ ] Update prompt to prevent code in responses
- [ ] Add instruction: "Never include code snippets, only narrative and choices"
- [ ] Test: Generate 3 interactive stories, verify choices appear correctly

CONTEXT:
Interactive stories are returning code/markup instead of natural language choices.
Need to debug the Gemini API response and fix prompt engineering.

DEBUGGING STEPS:
1. Add print() or logger.info() to capture raw Gemini response
2. Generate test story and examine response format
3. Check if response parsing is breaking on code blocks
4. Update prompt to be more explicit about format needed
```

**Agent 2 (Frontend Core) - Part 2 (after Agent 1 completes):**
```
TODAY'S TASK:
Update story result screen to properly display interactive story choices.

FILES TO MODIFY:
- lib/story_result_screen.dart

SUCCESS CRITERIA:
- [ ] Read Agent 1's completion notes for new response format
- [ ] Update UI to display choices as buttons (not code)
- [ ] Test: Generate interactive story, verify choices appear as buttons
- [ ] Test: Click choice, verify story continues correctly

CONTEXT:
After Agent 1 fixes backend, frontend needs to display choices properly.
Choices should appear as tappable buttons, not raw text/code.

WAIT FOR:
Agent 1 to complete backend fix first.
```

---

### Task Set 3: Image Generation Fix (High Priority)
**Duration:** 2-3 hours
**Agents Needed:** 1

**Agent 1 (Backend):**
```
TODAY'S TASK:
Get DALL-E image generation working OR implement OpenRouter image endpoint (cheaper alternative).

**IMPORTANT:** User requested OpenRouter integration to save money.

OPTION A - Fix DALL-E:
FILES TO MODIFY:
- backend/services/image_service.py

SUCCESS CRITERIA:
- [ ] Check Railway env: railway variables --service story-weaver-app-backend
- [ ] Verify OPENAI_API_KEY is set and has credits
- [ ] Test API key with curl (see command below)
- [ ] Add detailed logging to image_service.py
- [ ] Test image generation endpoint
- [ ] Deploy and verify images appear

TEST COMMAND:
curl https://api.openai.com/v1/images/generations \
  -H "Authorization: Bearer $OPENAI_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"model":"dall-e-3","prompt":"cute dragon","n":1,"size":"1024x1024"}'

OPTION B - Implement OpenRouter (PREFERRED for cost savings):
FILES TO MODIFY:
- backend/services/image_service.py
- backend/app.py (if adding new config)

SUCCESS CRITERIA:
- [ ] Add OpenRouter API integration
- [ ] Use flux-schnell or other cheap image model
- [ ] Add OPENROUTER_API_KEY to Railway environment
- [ ] Update image generation to use OpenRouter endpoint
- [ ] Test: Generate 3 images, verify they appear in stories
- [ ] Document cost savings in completion notes

OPENROUTER ENDPOINTS:
- API: https://openrouter.ai/api/v1/images/generations
- Models: flux-schnell (cheapest), stable-diffusion, etc.
- Pricing: ~$0.003 per image vs DALL-E ~$0.04 (13x cheaper)

CONTEXT:
User wants to reduce costs. OpenRouter is significantly cheaper than DALL-E.
Codex is already working on this integration.

COORDINATION:
Check TEAM_COORDINATION.md to see if Codex has started this.
If yes, coordinate with their work. If no, proceed with OpenRouter integration.
```

---

### Task Set 4: Testing & Documentation (Ongoing)
**Duration:** 1-2 hours
**Agents Needed:** 1

**Agent 4 (Testing):**
```
TODAY'S TASK:
Document all current bugs with reproduction steps and create test plan.

FILES TO CREATE:
- BUG_REPORT.md (if doesn't exist)

SUCCESS CRITERIA:
- [ ] Test interactive stories - document exact behavior (showing code)
- [ ] Test avatars - document behavior (generic icons)
- [ ] Test image generation - document failure mode
- [ ] Test age gate - document Stack Overflow (note: currently bypassed)
- [ ] Create reproduction steps for each bug
- [ ] Assign bugs to appropriate agents in TEAM_COORDINATION.md

TESTING CHECKLIST:
1. Interactive Story:
   - Generate interactive story
   - Screenshot what appears (code vs choices)
   - Document steps to reproduce

2. Avatars:
   - Create character with custom hair/clothes
   - Screenshot avatar display
   - Check if customizations appear

3. Images:
   - Generate story with image checkbox
   - Document what happens (error, timeout, nothing?)
   - Check browser console for errors

4. Age Gate:
   - Note: Currently bypassed with || true
   - Document what happened before bypass
   - Note in report: "Temporarily bypassed, needs fix later"

REPORT FORMAT:
For each bug, document:
- Summary
- Steps to reproduce
- Expected behavior
- Actual behavior
- Screenshots (if possible)
- Priority (Critical/High/Medium/Low)
- Assigned to: Agent [N]
```

---

## How to Start an Agent

### Method 1: Using Claude Code with Another Session
1. Open new Claude Code terminal/session
2. Copy prompt from `.agent_templates/AGENT_[N]_*_PROMPT.md`
3. Fill in TODAY'S TASK section
4. Paste entire prompt
5. Let agent work
6. Review TEAM_COORDINATION.md for completion

### Method 2: Using OpenRouter/Other LLM
1. Open your OpenRouter interface (or other LLM)
2. Copy agent prompt template
3. Fill in task details
4. Specify: "Report completion in TEAM_COORDINATION.md, then summarize and exit"
5. Monitor TEAM_COORDINATION.md for updates

---

## Monitoring Agents

### Check TEAM_COORDINATION.md for:
- 🔒 File locks (indicates agent is working)
- ⚠️ Blockers (need immediate attention)
- ❓ Questions (answer in Supervisor Notes section)
- ✅ Completions (review and test integration)

### When Agent Reports Blocker:
1. Read blocker description
2. Provide guidance in Supervisor Notes section
3. Update agent's task if needed
4. Post: "🚦 Unblocked: [description]"

### When Agent Completes:
1. Read completion notes
2. Review files they modified
3. Test their changes
4. If good: Post "✅ Approved: [agent N work]"
5. If issues: Post feedback and request fix
6. Assign next task or dismiss agent

---

## Example First Day

### Morning (You do this)
```markdown
## Supervisor Notes | 2025-11-29

### Today's Plan
Goal: Fix 2 critical bugs (avatars + interactive stories)

Agent 3: Fix avatars (quick win, 30 min)
Agent 1: Fix interactive stories backend (2 hours)
Agent 2: (waiting) Fix interactive stories frontend
Agent 4: Document all bugs while others work

### Agents Started
- 09:00 - Started Agent 3 (avatars)
- 09:00 - Started Agent 4 (bug documentation)
- 09:15 - Started Agent 1 (interactive stories backend)
```

### Midday Check
```markdown
### Progress Check - 11:00
- Agent 3: ✅ Completed avatar fix, tested, deployed
- Agent 4: 🚧 In progress, documented 3 of 5 bugs
- Agent 1: 🚧 In progress, identified issue with prompt parsing

### Actions Taken
- Reviewed Agent 3's work - avatars now displaying correctly! 🎉
- Started Agent 2 (interactive stories frontend) since Agent 1 fixed backend
```

### Afternoon
```markdown
### Progress Check - 14:00
- Agent 1: ✅ Completed backend fix, interactive stories working
- Agent 2: ✅ Integrated frontend, choices displaying as buttons
- Agent 4: ✅ Completed bug documentation

### Testing Results
- Tested avatar display: ✅ Working perfectly
- Tested interactive stories: ✅ Choices appearing correctly
- Integration test: ✅ Full flow working

### End of Day Status
✅ Avatars fixed (Agent 3)
✅ Interactive stories fixed (Agent 1 + Agent 2)
✅ Bugs documented (Agent 4)
❌ Image generation - scheduled for tomorrow
```

---

## Tips for Success

1. **Start Small:** Begin with Agent 3's avatar fix (quick win)
2. **One at a Time:** Until you're comfortable, start 1 agent at a time
3. **Monitor Closely:** Check TEAM_COORDINATION.md every 30 min
4. **Test Everything:** Don't assume agent's work is perfect
5. **Clear Tasks:** Be very specific in task descriptions
6. **Dependencies:** Make sure Agent A completes before starting dependent Agent B

---

## Next Steps

**Ready to start?** Here's your first action:

1. **Decide:** Which bug to fix first? (Recommend: avatars - quick win)
2. **Copy:** `.agent_templates/AGENT_3_WIDGETS_PROMPT.md`
3. **Fill in:** Avatar fix task details (already written above in Task Set 1)
4. **Start:** Agent 3 in new session
5. **Monitor:** Check TEAM_COORDINATION.md in 15 minutes

OR

Ask me to:
- "Start Agent 3 with avatar fix"
- "Start Agent 1 with interactive stories fix"
- "Start Agent 4 with bug documentation"
- "Start Agent 1 with OpenRouter image integration"

I'll prepare the exact prompt for you to copy and paste!
