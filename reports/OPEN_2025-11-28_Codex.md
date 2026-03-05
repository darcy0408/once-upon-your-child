# Agent Session Start Template

**Instructions:** Each agent must read and complete this file at the START of each work session.

---

## Session Information

**Date:** 2025-11-28
**Agent:** Codex (Backend focus)
**Day:** Day 1
**Week:** Week 1: Make It Work

---

## Pre-Work Checklist

### 1. Read Today's Tasks
■ I have read my tasks for today in `AGENT_TASKS_DAY_BY_DAY.md`
■ I understand what I need to accomplish
■ I know what deliverables are expected

### 2. Check Dependencies
■ I have reviewed what other agents are working on today
■ I have checked if I need to wait for any other agent to finish first
■ I have noted any blockers or dependencies

### 3. Environment Check
■ My development environment is set up
■ I can access all necessary files and tools
■ I have latest code from repository (git pull)

### 4. Review Yesterday (if applicable)
■ I have reviewed yesterday's CLOSE.md report
■ I understand any carryover tasks
■ I have noted any bugs or issues from yesterday

---

## Today's Focus

**Primary Goal:**
Fix interactive story prompt so no code appears and diagnose/improve DALL-E image generation reliability.

**Success Criteria:**
- Interactive story prompt includes explicit no-code instruction and responses in testing show only narrative text and choices.
- Image generation path logs prompts/responses and API call functions with valid key; Railway env checked for `OPENAI_API_KEY`.
- OPEN and CLOSE reports created for 2025-11-28.

**Estimated Time:**
3-4 hours

---

## Potential Blockers

[List anything that might prevent you from completing today's work]
- [ ] Railway CLI/network access may be restricted in sandbox.
- [ ] DALL-E access or credits could be missing.

---

## Questions Before Starting

[Any clarifications needed before beginning work]
1. Should tests be run locally or against Railway environment?
2. Any preference on log verbosity for image generation?

---

**Ready to Start:** [X] Yes / [ ] No

If "No", explain why: ________________

---

**Start Time:** 09:00

---

## Notes to Self

[Any reminders or important points to keep in mind while working]
- Follow AGENTS.md formatting and code style; keep prompt change minimal.
- Capture evidence of Railway env check; log without exposing secrets.

---

**Once this file is complete, begin working on today's tasks.**
**Remember to document everything as you go!**
