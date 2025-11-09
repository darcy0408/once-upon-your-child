# Codex Task: Add Personality Trait Sliders to Character Creation

## 🎯 Goal
Add personality trait sliders to character creation so stories accurately reflect the child's actual personality, not generic traits. When Darcy created a character and generated a story, the AI described the character as "very organized" - but Darcy is actually messy! We need the stories to reflect who the child really is.

---

## 📍 Working Location
```bash
Directory: /mnt/c/dev/story-weaver-app (or C:\dev\story-weaver-app on Windows)
Branch: codex-dev
Setup:
  git checkout codex-dev
  git pull origin codex-dev
  git merge main -m "Merge main: Story generation fixes"
```

**IMPORTANT:** Work on `codex-dev` branch. Do NOT work directly on main.

---

## 🎨 What to Build

### Add 8 Personality Trait Sliders

Each slider represents a spectrum of personality traits (0-100 scale):

1. **Organization**: Messy (0) ↔️ Organized (100)
2. **Assertiveness**: Gentle/Agreeable (0) ↔️ Assertive/Bold (100)
3. **Social Energy**: Shy/Introverted (0) ↔️ Outgoing/Extroverted (100)
4. **Adventurousness**: Cautious/Careful (0) ↔️ Adventurous/Daring (100)
5. **Kindness**: Self-focused (0) ↔️ Kind/Caring (100)
6. **Energy Level**: Quiet/Calm (0) ↔️ Loud/Energetic (100)
7. **Perfectionism**: Go-with-flow/Flexible (0) ↔️ Perfectionist/Detail-oriented (100)
8. **Learning Style**: Hands-on/Active (0) ↔️ Studious/Reflective (100)

**Default value**: 50 (middle of scale) for all traits

---

[Rest of the detailed task document remains the same as before...]

**Estimated Time:** 3-4 hours
**Priority:** P1 (High - improves therapeutic value significantly)
**Owner:** Codex
**Reviewer:** Claude / Darcy
**Target:** This week

**Success = Stories that feel REAL and PERSONAL! 🎯**
