# 📋 Quick Instructions: Running Two Agents in Parallel

**Date:** 2025-12-10
**Goal:** Test wizard + fix network errors simultaneously
**Time Saved:** ~1 hour by running in parallel

---

## 🎯 AGENT 1: Wizard Testing (Codex or Gemini)

### What to say to Agent 1:

```
Follow the instructions in AGENT_1_WIZARD_TESTING_TASK.md exactly.

Your task:
- Test the new magical wizard UI flow
- Complete all 67 test items
- Document any issues found
- Commit test report when done

Branch: feature/gui-redesign
Time: 1-2 hours

Start immediately!
```

---

## 🎯 AGENT 2: Network Error Fix (Grok or Codex)

### What to say to Agent 2:

```
Follow the instructions in AGENT_2_NETWORK_ERROR_FIX_TASK.md exactly.

Your task:
- Improve network error handling
- Add user-friendly error messages
- Test the changes
- Commit when done

Branch: fix/network-error-handling (you will create this)
Time: 30-45 minutes

Start immediately!
```

---

## ✅ Why These Tasks Don't Conflict

| Aspect | Agent 1 | Agent 2 |
|--------|---------|---------|
| **Branch** | feature/gui-redesign | fix/network-error-handling (new) |
| **Files Modified** | Testing only (no code changes) | lib/services/api_service_manager.dart |
| **Type of Work** | Manual testing + reporting | Code fix + testing |
| **Git Conflicts** | None - different branches | None - different branches |

**They work on DIFFERENT BRANCHES = NO CONFLICTS!**

---

## 📊 Expected Timeline

```
Start (0:00)
├─ Agent 1 starts testing wizard
├─ Agent 2 starts fixing network errors
│
+0:45 - Agent 2 finishes, commits to fix/network-error-handling
│
+1:30 - Agent 1 finishes, commits test report to feature/gui-redesign
│
End
```

**Total time saved: ~30-45 minutes vs sequential**

---

## 🔄 Which Git Sync File to Use in Future?

### Use: **AGENT_GIT_SYNC_PROMPT.txt**

**Why:**
- ✅ Simple and clear
- ✅ Works with any branch (just updated!)
- ✅ Covers the essential git workflow
- ✅ Flexible for main, feature branches, fix branches

**When to use it:**
Give this prompt to any agent at the END of their task:
```
Now execute the git sync procedure from AGENT_GIT_SYNC_PROMPT.txt
Replace <CURRENT_BRANCH> with the branch you're working on.
```

**GIT_SYNC_QUICK_COMMAND.md doesn't exist** - it was deleted in the cleanup. AGENT_GIT_SYNC_PROMPT.txt is your go-to file.

---

## 🆘 What to Do After Agents Finish

### After Agent 1 (Wizard Testing):

1. **Read their test report**
2. **Check if PASS/PARTIAL/FAIL**
3. **If PASS:** Proceed to deployment
4. **If FAIL:** Review critical issues, assign fixes

### After Agent 2 (Network Error Fix):

1. **Review their changes** in lib/services/api_service_manager.dart
2. **If tests pass:** Merge fix/network-error-handling into feature/gui-redesign
   ```bash
   git checkout feature/gui-redesign
   git merge fix/network-error-handling
   git push origin feature/gui-redesign
   ```
3. **If tests fail:** Review issues, have agent fix

---

## 📝 Commands for You (After Both Agents Done)

### Merge Network Fix into Wizard Branch:

```bash
# Merge Agent 2's work into Agent 1's branch
git checkout feature/gui-redesign
git pull origin feature/gui-redesign
git merge fix/network-error-handling --no-ff -m "Merge network error handling improvements"
git push origin feature/gui-redesign
```

### Check Status:

```bash
# See what both agents committed
git log --oneline --graph --all -10

# See current state
git status
```

---

## ✅ Success Criteria

You'll know it worked when:
- ✅ Agent 1 pushed test report to feature/gui-redesign
- ✅ Agent 2 pushed code fix to fix/network-error-handling
- ✅ No conflicts when merging
- ✅ All tests documented
- ✅ Code improvements committed

---

## 🎉 Next Steps After Both Agents Complete

1. **Review test results** from Agent 1
2. **Merge fix** from Agent 2
3. **Test merged code** (quick sanity check)
4. **Proceed to deployment** (if tests passed)

See COMPREHENSIVE_DEPLOYMENT_CHECKLIST.md for what comes next.

---

**Remember:** You can monitor both agents' progress simultaneously. If one finishes early, you can review their work while the other continues!
