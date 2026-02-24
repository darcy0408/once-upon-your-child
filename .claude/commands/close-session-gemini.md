# Close Session Agent (Gemini-Powered)

**This version uses Gemini to save Claude usage!**

You are the **Closing Agent** running on Gemini - your role is to properly document and close out this work session without using expensive Claude tokens.

## Your Tasks (in order):

### 1. Comprehensive Session Summary
Analyze the ENTIRE conversation history and create a detailed summary covering:
- What was discussed and why
- What was built/modified/fixed
- Key decisions made and their rationale
- Any blockers or issues encountered
- Next steps or follow-up items needed

### 2. Update Session History
Update `docs/context/sessions/SESSION_HISTORY.md`:
- Add a new entry with today's date (2025-11-09)
- Include a concise but complete summary of this session
- List key files modified
- Note any important decisions or breakthroughs
- Follow the template format in the file

### 3. Check and Update Core Project Files
Review and update if needed:
- `README.md` - Does it reflect new features or changes?
- `docs/PROJECT_STATUS.md` - Update current state, known issues, progress
- Any architectural documentation that changed

### 4. Update AI Context Files
Update the following context files in `docs/context/ai-profiles/`:
- `CLAUDE_CONTEXT.md` - What Claude should know about this project
- `GEMINI_CONTEXT.md` - What you (Gemini) should know
- `AGENT_CONTEXT.md` - What specialized agents should know

Include:
- Project structure updates
- Key patterns and conventions
- Recent changes and their impact
- Known issues and solutions
- Coding standards

### 5. Git Commit
Create a meaningful git commit using this format:

```
[Category] Brief description

Detailed explanation of what was done and why it matters.

Key changes:
- Change 1 with context
- Change 2 with context
- Change 3 with context

Impact: How this affects the project
Next steps: What should be done next (if applicable)

🤖 Generated with Claude Code (Gemini)
```

**Categories:** Feature, Fix, Refactor, Docs, Chore, Deploy, Test

### 6. Report Back
Provide a brief summary to the user:
- What was documented
- Files updated
- Commit message created
- Any issues or notes

## Important Guidelines:
- Be thorough but concise
- Focus on "why" not just "what"
- Make commits meaningful for future reference
- Don't commit sensitive information (.env, credentials, etc.)
- If no changes were made, note that in session history but don't create empty commits
- Read existing files before updating to maintain consistency

**Execute all these tasks now using Gemini to conserve Claude usage!**
