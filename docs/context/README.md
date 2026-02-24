# Context Management System

This directory contains files that help maintain project context across work sessions and different AI assistants.

## Purpose

The context system solves several problems:
1. **Memory across sessions** - Keep track of what was done and why
2. **AI handoffs** - Different AIs (Claude, Gemini) can understand project state
3. **Historical tracking** - Know why decisions were made
4. **Documentation** - Automatic documentation through git commits

## Directory Structure

```
context/
├── README.md                    # This file
├── sessions/
│   └── SESSION_HISTORY.md      # Chronological log of all work sessions
└── ai-profiles/
    ├── CLAUDE_CONTEXT.md       # Context for Claude
    ├── GEMINI_CONTEXT.md       # Context for Gemini
    └── AGENT_CONTEXT.md        # Context for specialized agents
```

## How It Works

### At the End of Each Session

Run the closing agent command:
```bash
/close-session
```

This will automatically:
1. ✅ Summarize everything discussed and done
2. ✅ Update SESSION_HISTORY.md with new entry
3. ✅ Update AI context files with new information
4. ✅ Check if core project files need updates
5. ✅ Create a meaningful git commit

### Session History (`sessions/SESSION_HISTORY.md`)

Contains chronological entries for each work session:
- Date and title
- Summary of what was done
- Key changes made
- Important decisions
- Issues encountered
- Impact and next steps

### AI Context Files (`ai-profiles/`)

Each AI has its own context file that contains:
- Project overview and architecture
- Tech stack and tools
- Coding conventions and preferences
- Current focus areas
- Known issues and solutions
- How to collaborate effectively

**When to update:**
- Automatically via `/close-session`
- Manually when project structure changes
- When new patterns or conventions are established
- After major architectural decisions

## Benefits

### For You
- 📝 Automatic documentation of your work
- 🕒 Historical record with git commits
- 🔍 Easy to find "why did I do that?"
- 📊 Track project progress over time

### For AI Assistants
- 🧠 Understand project context quickly
- 🤝 Seamless handoffs between AIs
- 🎯 Make better suggestions
- 📚 Learn project patterns and preferences

### For Your Future Self
- 💡 Remember the reasoning behind decisions
- 🐛 Debug issues by checking history
- 🔄 Rollback changes with confidence
- 📈 See how the project evolved

## Best Practices

1. **Use `/close-session` regularly**
   - End of every significant work session
   - After adding features
   - After fixing bugs
   - Before switching contexts

2. **Keep context files updated**
   - Add new patterns as they emerge
   - Document decisions and rationale
   - Update known issues
   - Reflect current project state

3. **Write meaningful summaries**
   - Focus on "why" not just "what"
   - Include context and motivation
   - Note important decisions
   - List next steps

4. **Maintain git commit quality**
   - Clear, descriptive messages
   - Explain impact and reasoning
   - Reference related issues/tasks
   - Make commits findable later

## Example Workflow

```
1. Start work session
   → Check SESSION_HISTORY.md to see what was done recently
   → Read relevant AI context files

2. Do work (build features, fix bugs, etc.)
   → AI assistants reference context files
   → Make changes to codebase

3. End session
   → Run /close-session
   → Review generated summary
   → Verify git commit message
   → Everything is documented automatically!
```

## Tips

- **Before starting:** Always check SESSION_HISTORY.md
- **During work:** Focus on the task, not documentation
- **After work:** Let `/close-session` handle documentation
- **Periodically:** Review and clean up context files

## Why This Matters

> "I'm really bad at documentation. I'm really bad at keeping track of things, but now I have this help me keep track of things."

This system treats your ideas and projects like code:
- Version controlled with git
- Documented automatically
- History is preserved
- Changes are trackable
- Mistakes are reversible

**The power of using GitHub with all your ideas!** 🚀

---

**Questions?** Check the context files or run `/close-session` to see it in action.
