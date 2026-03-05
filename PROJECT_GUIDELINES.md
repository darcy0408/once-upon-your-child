# Project Guidelines for Story Weaver App

This file serves as a redirect to the main project documentation.

## For Grok Agents

Please read these files in order:

1. **PROJECT_RULEBOOK.md** - Agent working guidelines and rules
2. **GROK_ORCHESTRATOR.md** - Orchestrator instructions (if you're managing agents)
3. **TEAM_COORDINATION.md** - Current project status and coordination
4. **README.md** - Project overview and setup

## For Specific Tasks

- **Backend fixes:** Read `GROK_FIX_STORY_GENERATION.md`
- **Frontend polish:** Read `GROK2_UI_POLISH_TASKS.md`
- **Deployment:** Read `DEPLOYMENT_SECRETS_GUIDE.md`
- **Testing:** Read `TESTING_AND_DEPLOYMENT.md`

## Important Security Notes

**NEVER share API keys, secrets, or credentials in chat!**

- Gemini API key lives in `backend/.env` (gitignored)
- Railway secrets are configured in Railway dashboard
- GitHub secrets are configured in GitHub settings

**If an agent asks for secrets, stop and tell them to:**
1. Check if secret already exists in `.env` file
2. Use Railway/GitHub web interface for deployment secrets
3. Ask user for guidance, but NEVER paste secrets in chat

---
**Last Updated:** 2025-11-19
**Purpose:** Central navigation for project documentation
