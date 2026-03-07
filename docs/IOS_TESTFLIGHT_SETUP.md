# iOS TestFlight CI Setup

This repo now includes:

- `.github/workflows/ios-build.yml` for unsigned iOS build validation
- `.github/workflows/ios-testflight.yml` for signed manual TestFlight upload

## 1) GitHub Secrets Required

Add these in: `GitHub Repo -> Settings -> Secrets and variables -> Actions`

1. `IOS_CERTIFICATE_P12_BASE64`
2. `IOS_CERTIFICATE_PASSWORD`
3. `IOS_KEYCHAIN_PASSWORD`
4. `IOS_PROVISIONING_PROFILE_BASE64`
5. `IOS_DEVELOPMENT_TEAM`
6. `APP_STORE_CONNECT_API_KEY_ID`
7. `APP_STORE_CONNECT_ISSUER_ID`
8. `APP_STORE_CONNECT_API_KEY_BASE64`

## 2) Generate Base64 Values

macOS examples:

```bash
base64 -i ios_distribution_certificate.p12 | pbcopy
base64 -i app_store.mobileprovision | pbcopy
base64 -i AuthKey_ABC123XYZ.p8 | pbcopy
```

PowerShell examples:

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("ios_distribution_certificate.p12"))
[Convert]::ToBase64String([IO.File]::ReadAllBytes("app_store.mobileprovision"))
[Convert]::ToBase64String([IO.File]::ReadAllBytes("AuthKey_ABC123XYZ.p8"))
```

## 3) Apple-Side One-Time Checks

1. Bundle ID in Apple Developer/App Store Connect matches:
   - `com.storyweaver.storyWeaverApp`
2. App Store provisioning profile is for that Bundle ID.
3. Distribution certificate matches provisioning profile.
4. App exists in App Store Connect for this Bundle ID.

## 4) Run the Workflow

1. Open `Actions` tab in GitHub.
2. Choose `iOS TestFlight Release`.
3. Click `Run workflow`.

If it fails in signing/export, inspect the uploaded logs/artifacts and verify certificate/profile/team alignment.
