# iOS TestFlight CI Setup

How to get a signed build onto TestFlight **from Windows, with no Mac**, using
`.github/workflows/ios-testflight.yml`.

The repo also has `.github/workflows/ios-build.yml` for unsigned build
validation.

> **Cost warning — read before dispatching anything.** Both iOS workflows run on
> `macos-latest`, which bills at **10x** the Linux rate on this repo. A single
> unattended misconfiguration once consumed **$75 of an ~$80 monthly
> allowance**, which blocked CI account-wide. First attempts commonly fail on
> signing. Get every step below right *before* you dispatch, and expect to pay
> for each attempt.

---

## 0) What you need, and where each piece comes from

| Artifact | Made where | Needs a Mac? |
|---|---|---|
| App ID | developer.apple.com → Identifiers | No |
| App record | App Store Connect | No |
| Private key + CSR | **Your Windows machine** (below) | No |
| Distribution certificate (`.cer`) | developer.apple.com, from your CSR | No |
| `.p12` (key + certificate) | **Your Windows machine** (below) | No |
| Provisioning profile (`.mobileprovision`) | developer.apple.com | No |
| App Store Connect API key (`.p8`) | App Store Connect → Users and Access | No |

Nothing here requires a Mac. The usual "you need Keychain Access" advice exists
because Keychain is how Mac users generate the CSR — OpenSSL does the same job.

---

## 1) GitHub secrets required (7)

`GitHub repo → Settings → Secrets and variables → Actions`

1. `IOS_CERTIFICATE_P12_BASE64`
2. `IOS_CERTIFICATE_PASSWORD`
3. `IOS_KEYCHAIN_PASSWORD` — any strong string you invent; it only unlocks the
   throwaway keychain the runner creates
4. `IOS_PROVISIONING_PROFILE_BASE64`
5. `APP_STORE_CONNECT_API_KEY_ID`
6. `APP_STORE_CONNECT_ISSUER_ID`
7. `APP_STORE_CONNECT_API_KEY_BASE64`

> `IOS_DEVELOPMENT_TEAM` used to be listed here and is **no longer used**. It
> was passed to the build as `--dart-define`, which only defines a Dart
> compile-time constant and never reached the Xcode `DEVELOPMENT_TEAM` build
> setting — so signing was never actually configured by it. The team ID now
> lives in `ios/Runner.xcodeproj/project.pbxproj` on all three Runner
> configurations. Don't re-add the secret.

---

## 2) Apple portal: App ID and app record

Values must match **character for character**:

- Bundle ID: `com.storyweaver.storyWeaverApp`
- Team: `JPU8WX66BX` (Once Upon YOUR Child LLC)
- App name: **Once Upon YOUR Child**

Steps:

1. developer.apple.com → Certificates, Identifiers & Profiles → **Identifiers**
   → **+** → App IDs → App → description "Once Upon YOUR Child", Bundle ID
   **explicit** = `com.storyweaver.storyWeaverApp`. Enable only capabilities the
   app actually uses. Register.
2. appstoreconnect.apple.com → **Apps** → **+** → New App. Platform iOS, the
   name above, primary language, the Bundle ID from step 1, and an SKU (any
   internal string, e.g. `once-upon-your-child-ios`).

Neither step requires the Paid Apps agreement. That agreement gates *selling*,
not TestFlight.

---

## 3) Windows: private key and CSR

Run in **Git Bash** from a working folder **outside the repo** (these files must
never be committed):

```bash
mkdir -p ~/ios-signing && cd ~/ios-signing

# Private key. Keep this file — the certificate is worthless without it.
openssl genrsa -out ios_distribution.key 2048

# Certificate Signing Request. MSYS_NO_PATHCONV=1 is REQUIRED: Git Bash
# rewrites any argument starting with "/" into a Windows path, which silently
# corrupts -subj and makes this command fail.
MSYS_NO_PATHCONV=1 openssl req -new -key ios_distribution.key \
  -out ios_distribution.certSigningRequest \
  -subj "/emailAddress=darcy@onceuponyourchild.app/CN=Once Upon YOUR Child LLC/C=US"

# Confirm it read back correctly before uploading.
MSYS_NO_PATHCONV=1 openssl req -in ios_distribution.certSigningRequest -noout -subject
```

The subject line should echo your email, CN and country. If it shows a
`C:/Program Files/...` path instead, `MSYS_NO_PATHCONV=1` was missed.

---

## 4) Apple portal: distribution certificate

1. Certificates, Identifiers & Profiles → **Certificates** → **+**
2. Choose **Apple Distribution** (not Development)
3. Upload `ios_distribution.certSigningRequest`
4. Download the resulting `.cer` into `~/ios-signing/`

---

## 5) Windows: build the `.p12`

```bash
cd ~/ios-signing

# Apple hands back DER; OpenSSL wants PEM to bundle it.
# Apple names the download itself (often distribution.cer or ios_distribution.cer)
# — use the actual filename you downloaded, not this one verbatim.
openssl x509 -inform DER -in distribution.cer -out ios_distribution.pem

# Bundle private key + certificate. -legacy is MANDATORY, see note below.
openssl pkcs12 -export -legacy \
  -inkey ios_distribution.key \
  -in ios_distribution.pem \
  -out ios_distribution.p12

# Verify it opens with the password you just set, BEFORE spending a CI run.
openssl pkcs12 -in ios_distribution.p12 -nokeys -legacy | openssl x509 -noout -subject
```

> **`-legacy` is not optional.** OpenSSL 3 defaults to AES-256 PBES2 encryption,
> which macOS `security import` cannot read — and `security import` is exactly
> what the workflow runs. Without `-legacy` the build fails at the import step
> after you have already paid for the macOS minutes. This whole sequence was
> executed and round-trip verified on this machine, including that flag.

The export password you choose becomes `IOS_CERTIFICATE_PASSWORD`.

---

## 6) Apple portal: provisioning profile and API key

1. Profiles → **+** → **App Store** distribution → select the App ID from step 2
   → select the certificate from step 4 → download the `.mobileprovision`
2. App Store Connect → **Users and Access** → **Integrations** → App Store
   Connect API → **+** → role **App Manager** → download the `.p8`
   - The `.p8` downloads **once** and can never be retrieved again. Back it up.
   - Note the **Key ID** and the **Issuer ID** shown on that page.

---

## 7) Convert to base64 and paste into GitHub

PowerShell (single line each, no wrapping):

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("$HOME\ios-signing\ios_distribution.p12"))
[Convert]::ToBase64String([IO.File]::ReadAllBytes("$HOME\ios-signing\profile.mobileprovision"))
[Convert]::ToBase64String([IO.File]::ReadAllBytes("$HOME\ios-signing\AuthKey_XXXXXXXX.p8"))
```

Paste each into its matching secret from section 1. Paste the value only — no
quotes, no trailing newline.

**Back up `~/ios-signing/` somewhere off this machine.** Losing the private key
means revoking and regenerating the certificate.

---

## 8) Dispatch

Actions → **iOS TestFlight Release** → Run workflow.

Watch it. If it fails, cancel promptly rather than letting a stuck job run —
macOS minutes accrue the whole time.

## Troubleshooting

| Symptom | Cause |
|---|---|
| `security import` fails / "MAC verification failed" | `.p12` built without `-legacy`, or wrong `IOS_CERTIFICATE_PASSWORD` |
| CSR command fails, subject shows a Windows path | `MSYS_NO_PATHCONV=1` missing |
| "No signing certificate found" | Certificate is Development, not **Apple Distribution** |
| Profile/certificate mismatch | Profile was created before the certificate, or against a different one — regenerate the profile |
| Bundle ID mismatch | Must be `com.storyweaver.storyWeaverApp` everywhere |
| Build succeeds, upload rejected | App record missing in App Store Connect (section 2) |
