# Security Runbook

## Scope
This runbook covers:
- Secret exposure (API keys, tokens, passwords, webhook secrets)
- Suspected credential misuse
- Rotation and recovery steps for local + Railway

## Immediate Response
1. Identify exposed credentials and where they appeared (file, log, commit, CI output).
2. Revoke exposed credentials at provider immediately.
3. Create replacement credentials per environment (`dev`, `staging`, `prod`).
4. Update secret stores:
`Railway Variables`
`local backend/.env`
5. Redeploy impacted services after secret updates.
6. Verify critical endpoints and background workers.
7. Document incident in `TEAM_COORDINATION.md` with timestamp and actions taken.

## Rotation Checklist
1. Rotate provider keys:
`Gemini API key`
`OpenRouter API key`
`Context7 API key`
`GitHub PAT` (if used)
2. Replace values in Railway:
`backend-web` service
`backend-worker` service
3. Replace local development values in `backend/.env`.
4. Revoke old keys after successful validation.

## Railway Validation
1. `GET /health` returns `200`.
2. Heavy `POST /generate-story` returns quickly with `202` when async queue is used.
3. `GET /task-status/<task_id>` reaches `complete`.
4. Worker logs show active task processing with no auth/credential failures.

## Prevention Controls
1. Never store real secrets in docs, tests, sample payloads, or `.env.example`.
2. Use separate credentials for `dev`, `staging`, and `prod`.
3. Set expiration and rotation cadence:
30-90 days for tokens and keys where supported.
4. Enable GitHub Secret Scanning and Push Protection.
5. Enforce local secret scanning with pre-commit (`gitleaks`).
6. Keep `.env` ignored (already covered in `.gitignore`).
7. Prefer short-lived or scoped tokens (least privilege).

## Recovery From Git History Exposure
1. Revoke exposed key first.
2. Rotate and redeploy.
3. If required, purge historical secrets from git history (`git filter-repo` or BFG) in a coordinated maintenance window.
4. Force all collaborators to resync after history rewrite.

## Ownership
- Primary owner: backend maintainer on-call
- Escalation: repo admin + deployment admin

