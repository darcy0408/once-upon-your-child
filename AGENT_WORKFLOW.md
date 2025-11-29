# Agent Daily Workflow

**Every agent must follow this workflow at the start and end of each work session.**

---

## Daily Workflow Steps

### 1. START OF DAY: Read OPEN.md Template
```
Location: .agent_templates/OPEN.md

Instructions:
1. Copy OPEN.md to a new file: OPEN_[DATE]_Agent[N].md
   Example: OPEN_2025-11-28_Agent1.md
2. Fill out all sections
3. Answer all checklist items
4. Identify your goals and blockers
5. Confirm you're ready to start
```

### 2. WORK: Complete Today's Tasks
```
Instructions:
1. Open AGENT_TASKS_DAY_BY_DAY.md
2. Find your section for today (Week X, Day Y, Agent N)
3. Work through task list systematically
4. Check off tasks as you complete them
5. Document everything as you go
6. Take notes of any issues or discoveries
```

### 3. END OF DAY: Complete CLOSE.md Template
```
Location: .agent_templates/CLOSE.md

Instructions:
1. Copy CLOSE.md to a new file: CLOSE_[DATE]_Agent[N].md
   Example: CLOSE_2025-11-28_Agent1.md
2. Fill out ALL sections thoroughly:
   - ✅ What you accomplished
   - 🚧 What's in progress
   - ❌ What you couldn't finish
   - 📝 Additional work discovered
   - 🐛 Bugs found
   - ✓ Tests you ran
   - 👤 Tests for user to run
   - 🧪 Tests for Agent 3 to verify
   - 🚀 Deployment status
   - 🤝 Handoffs to other agents
   - 📅 Tomorrow's plan
3. Be honest and thorough
4. Include all details (file paths, line numbers, etc.)
```

---

## File Naming Convention

### Daily Reports
```
reports/
  ├── OPEN_2025-11-28_Agent1.md
  ├── CLOSE_2025-11-28_Agent1.md
  ├── OPEN_2025-11-28_Agent2.md
  ├── CLOSE_2025-11-28_Agent2.md
  ├── OPEN_2025-11-28_Agent3.md
  ├── CLOSE_2025-11-28_Agent3.md
  ├── OPEN_2025-11-29_Agent1.md
  └── CLOSE_2025-11-29_Agent1.md
```

---

## Critical Requirements

### For ALL Agents:

1. **MUST complete OPEN.md before starting work**
   - No exceptions
   - Helps you focus and identify blockers early

2. **MUST complete CLOSE.md at end of session**
   - No exceptions
   - Critical for coordination and continuity

3. **MUST be honest in reports**
   - If you didn't finish something, say so
   - If you found a bug, report it
   - If you're blocked, communicate it

4. **MUST specify tests**
   - What tests did you run?
   - What tests should user run?
   - What tests should Agent 3 verify?

---

## Agent-Specific Notes

### Agent 1 (Backend)
**Additional Reporting Requirements:**
- Always include database changes (migrations, schema updates)
- Always include API changes (new endpoints, changed responses)
- Always include performance impacts (slow queries, etc.)
- Always note security considerations

### Agent 2 (Frontend)
**Additional Reporting Requirements:**
- Always include UI changes (screenshots if possible)
- Always include user-facing text changes
- Always include navigation/flow changes
- Always note accessibility impacts

### Agent 3 (QA/Integration)
**Additional Reporting Requirements:**
- Always include test coverage summary
- Always include bug severity assessments
- Always include regression test results
- Always document verification of Agent 1 & 2's work

---

## Communication Channels

### Between Agents (Async)
```
Use these files for agent-to-agent communication:

- BUG_REPORT.md - Report bugs found
- BLOCKERS.md - Report blockers preventing work
- HANDOFFS.md - Pass work to another agent
- QUESTIONS.md - Ask clarifying questions
```

### To User
```
Use CLOSE.md section "Tests for User to Run" to communicate:
- What features to test
- How to test them
- What to verify
```

---

## Example Daily Flow

### Morning (Start of Session):
```
1. Agent opens .agent_templates/OPEN.md
2. Agent copies to reports/OPEN_2025-11-28_Agent1.md
3. Agent fills out:
   - Today's focus: "Fix interactive stories showing code"
   - Success criteria: "Interactive stories show choices, not code"
   - Blockers: "None currently"
4. Agent confirms ready to start
5. Agent begins work on tasks from AGENT_TASKS_DAY_BY_DAY.md
```

### During Work:
```
1. Agent works through task checklist
2. Agent documents findings as they go
3. Agent tracks time spent
4. Agent notes any issues or discoveries
5. Agent runs tests on completed work
```

### Evening (End of Session):
```
1. Agent opens .agent_templates/CLOSE.md
2. Agent copies to reports/CLOSE_2025-11-28_Agent1.md
3. Agent fills out all sections:
   - Accomplishments: ✅ Fixed interactive story parsing
   - Deliverables: Updated backend/services/story_parser.py
   - Tests completed: Generated 5 interactive stories, all show choices
   - Tests for user: "Generate interactive story, verify choices appear"
   - Tomorrow: "Start image generation diagnosis"
4. Agent commits code
5. Agent commits CLOSE report
6. Session ends
```

---

## Quality Checklist

Before submitting your CLOSE.md report, verify:

- [ ] All completed tasks listed
- [ ] All in-progress tasks documented with status
- [ ] All blockers clearly explained
- [ ] All bugs reported with repro steps
- [ ] All tests documented (yours + user's + Agent 3's)
- [ ] All file changes listed with paths
- [ ] All handoffs communicated
- [ ] Tomorrow's plan is clear
- [ ] Deployment status noted
- [ ] Code committed to git
- [ ] Report is honest and accurate

---

## Benefits of This Workflow

1. **Clarity:** Everyone knows what everyone else is doing
2. **Continuity:** Easy to pick up where you left off
3. **Accountability:** Clear record of what got done
4. **Coordination:** Prevents conflicts and duplication
5. **Testing:** Clear handoff of testing responsibilities
6. **Documentation:** Automatic project documentation
7. **Debugging:** Easy to trace when/why changes were made

---

## This Workflow is Mandatory

**No exceptions. Every agent, every day.**

**Benefits to User:**
- You can review each agent's work daily
- You know exactly what tests to run
- You can see progress clearly
- You can spot blockers early
- You have complete project history

**Benefits to Agents:**
- Clear expectations
- No guesswork about what to do
- Easy to coordinate with other agents
- Complete context for next session
- Credit for all work done

---

**Follow this workflow and the 3-week plan WILL succeed.**
