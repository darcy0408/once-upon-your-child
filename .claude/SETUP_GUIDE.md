# Closing Agent Setup Guide

This guide helps you set up automatic reminders and optimize the closing agent system.

## Quick Start

### How to Run the Closing Agent

**Option 1: Claude-Powered (More Thorough)**
```
/close-session
```

**Option 2: Gemini-Powered (Saves Claude Tokens!) ⭐ RECOMMENDED**
```
/close-session-gemini
```

## Automatic Reminders (Optional Setup)

Unfortunately, Claude Code doesn't have built-in "context limit approaching" hooks yet. However, you can:

### Manual Reminder
Just remember to run `/close-session-gemini` when you:
- Finish a feature
- Fix a bug
- End your work session
- Notice context getting long

### Future Enhancement Ideas
When Claude Code adds more hooks, we could implement:
- Auto-trigger at 80% context usage
- Periodic check-ins every N messages
- Time-based reminders

## Startup Flow

### What Happens When You Open This Project

1. **Claude reads the context files automatically** (they're in the project)
2. You can check recent work by reading `docs/context/sessions/SESSION_HISTORY.md`
3. Start working!

### Optional: Add a Startup Reminder

You can add this to your shell profile (`.bashrc`, `.zshrc`, etc.):

```bash
# Add to ~/.bashrc or ~/.zshrc
cd_with_reminder() {
    cd "$@"
    if [ -f ".claude/commands/close-session.md" ]; then
        echo "📚 Tip: Check docs/context/sessions/SESSION_HISTORY.md for recent work"
        echo "✅ Remember to run /close-session-gemini when done!"
    fi
}
alias cd='cd_with_reminder'
```

## Using This System in Other Projects

### Copy to Another Project

1. **Copy the entire structure:**
```bash
# From your story-weaver-app directory
cp -r .claude/commands /path/to/other/project/.claude/
cp -r docs/context /path/to/other/project/docs/
```

2. **Update the context files** for the new project:
   - Edit `docs/context/ai-profiles/CLAUDE_CONTEXT.md`
   - Edit `docs/context/ai-profiles/GEMINI_CONTEXT.md`
   - Edit `docs/context/ai-profiles/AGENT_CONTEXT.md`
   - Clear `docs/context/sessions/SESSION_HISTORY.md` (start fresh)

3. **Start using it!**
   - Run `/close-session-gemini` at the end of sessions

### Create a Template (Advanced)

Create a reusable template directory:

```bash
# Create template directory
mkdir -p ~/templates/claude-closing-agent

# Copy the structure
cp -r .claude/commands ~/templates/claude-closing-agent/
cp -r docs/context ~/templates/claude-closing-agent/

# For new projects, copy from template
cp -r ~/templates/claude-closing-agent/.claude/commands /path/to/new/project/.claude/
cp -r ~/templates/claude-closing-agent/docs/context /path/to/new/project/docs/
```

## Best Practices

### 1. Use Gemini Version Most of the Time ⭐
- Saves Claude tokens for complex coding tasks
- Gemini is great at summarization and documentation
- Use Claude version only if Gemini isn't available

### 2. Run It Regularly
- After completing features
- After bug fixes
- Before taking breaks
- End of work sessions

### 3. Review Before Committing
- Check the generated session summary
- Verify the git commit message
- Make sure all changes are documented

### 4. Keep Context Files Current
- Let the agent update them automatically
- Manually review periodically for accuracy
- Remove outdated information

## Token Usage Optimization

### Why Use Gemini for Closing?

**Claude (expensive):** Best for complex code, architecture, debugging
**Gemini (cheaper):** Great for documentation, summarization, routine tasks

**Typical Session:**
- Use Claude for coding: ✅ Worth it
- Use Gemini for closing: ✅ Smart move
- Result: More Claude budget for actual development!

### Monitor Your Usage

You can check context usage during a session:
- Claude Code shows token count
- Switch to `/close-session-gemini` if getting high
- Save Claude tokens for the next coding session

## Troubleshooting

### "Command not found"
- Make sure you're in the project directory with `.claude/commands/`
- Check that the `.md` files exist
- Restart Claude Code if needed

### "No changes to commit"
- Normal! Not every session has code changes
- The agent will still update documentation
- No empty commit will be created

### "Context files not updating"
- Check file permissions
- Make sure paths are correct
- Verify the agent completed all steps

### "Git commit failed"
- Check if you have unstaged changes
- Verify git is configured
- Review error message from git

## Advanced Features

### Custom Commands

Create your own commands in `.claude/commands/`:

**Example: `/quick-commit.md`**
```markdown
Create a quick git commit with the current changes.
Keep the message brief but meaningful.
```

**Example: `/review-session.md`**
```markdown
Review the SESSION_HISTORY.md file and summarize the last 5 sessions.
Highlight major accomplishments and patterns.
```

### Multi-Project Workflow

If you work on multiple projects:

1. Use the same closing agent structure in all projects
2. Each project maintains its own session history
3. Context files stay project-specific
4. Git history tracks everything separately

**Benefit:** Consistent documentation across all your projects!

## Getting Help

- Check `docs/context/README.md` for system overview
- Read `.claude/commands/README.md` for command basics
- Review `SESSION_HISTORY.md` to see examples of good documentation

## Summary

✅ **To run:** `/close-session-gemini` (saves Claude tokens!)
✅ **When:** End of sessions, after features/fixes
✅ **Portable:** Copy `.claude/commands` and `docs/context` to other projects
✅ **Smart:** Uses Gemini for documentation, saves Claude for coding
✅ **Automatic:** Not yet, but manual use is easy

**The power of treating your ideas like code!** 🚀

---

*Last Updated: 2025-11-09*
