# Claude Commands

This directory contains custom slash commands for the Story Weaver App project.

## Available Commands

### `/close-session-gemini` ⭐ RECOMMENDED
**The Closing Agent (Gemini-Powered)** - Saves Claude tokens by using Gemini for documentation!

**What it does:**
1. Creates a comprehensive summary of the session
2. Updates `docs/context/sessions/SESSION_HISTORY.md`
3. Updates AI context files (Claude, Gemini, Agent contexts)
4. Checks if core project files need updates
5. Creates a meaningful git commit with detailed message

**Why use this version:**
- Saves your Claude tokens for actual coding
- Gemini is excellent at documentation and summarization
- Just as thorough as the Claude version
- Faster for routine session closing

**How to use:**
```
/close-session-gemini
```

### `/close-session`
**The Closing Agent (Claude-Powered)** - Same as above, but uses Claude.

Use this version if:
- Gemini is not available
- You want Claude's analysis specifically
- You have plenty of Claude tokens available

**How to use:**
```
/close-session
```

**What you'll get:**
- ✅ Complete session documentation
- ✅ Updated context files for all AIs
- ✅ Meaningful git commit with "why" not just "what"
- ✅ Clear record for future reference

## Creating New Commands

To create a new slash command:

1. Create a new `.md` file in this directory
2. Name it with the command you want (e.g., `my-command.md` → `/my-command`)
3. Write the instructions for what Claude should do when the command runs
4. The file content becomes the prompt that Claude follows

## Example

If you create `review-code.md`:
```markdown
# Code Review Agent

Review the code changes in the current branch and provide:
- Potential bugs or issues
- Best practice recommendations
- Performance concerns
- Security vulnerabilities

Be thorough but concise.
```

Then you can run `/review-code` to execute it!

## Tips

- Keep commands focused on a single task
- Write clear, specific instructions
- Include examples if helpful
- Document the command in this README

## Learn More

See the [Claude Code documentation](https://docs.claude.com/en/docs/claude-code) for more information about slash commands.
