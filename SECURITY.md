# Security Policy

Thank you for taking the time to look. Once Upon YOUR Child is a small independent project, and responsible reports are genuinely appreciated.

## Reporting a vulnerability

**Please do not open a public issue for security problems.**

Report privately using either of these:

- **GitHub Security Advisories** — [open a private report](https://github.com/darcy0408/once-upon-your-child/security/advisories/new). This is preferred; the report stays private until a fix ships, and it keeps everything threaded in one place.
- **Email** — darcy@onceuponyourchild.app

Please include enough detail to reproduce the issue: affected endpoint or component, the steps you took, and what you observed. Proof-of-concept code is welcome.

## What to expect

This project is maintained by one person, so response times are best-effort rather than contractual:

- **Acknowledgement** — within 7 days
- **Initial assessment** — within 14 days
- **Fix or mitigation plan** — communicated once assessed

If you have not heard back within 14 days, please send a follow-up; it means the message was missed, not ignored.

## Scope

In scope:

- The web application at https://onceuponyourchild.app
- The backend API serving it
- This repository's source code and CI configuration

Out of scope:

- Denial-of-service and volumetric testing. Please do not run load or stress tests against production.
- Automated scanner output submitted without a demonstrated, exploitable impact
- Findings that require physical access to a user's unlocked device
- Social engineering of the maintainer or any third-party provider
- Missing hardening headers or similar best-practice gaps with no demonstrated impact

Firebase client configuration values in this repository (`android/app/google-services.json`, `ios/Runner/GoogleService-Info.plist`) are **intentionally public**. They are identifiers, not secrets, and access is governed by Firebase security rules. Reports that these are "exposed keys" will be closed. If you can demonstrate that the security rules themselves permit unauthorized access, that is very much in scope and worth reporting.

## Please be careful with children's data

This application is used by families, and stories may reference real children's names and ages. If your testing surfaces any real user data, **stop, do not save or share it, and say so in your report.** Use accounts and data you created yourself. Reports demonstrating access to other users' data are treated as the highest priority.

## Recognition

There is no paid bounty program. Valid reports will be credited in the release notes for the fix, if you would like to be named.
